-- |
-- Module       : Converter
-- Description  : Convert syntax tree to assembly schema
--
-- Converts an abstract syntax tree into an assembly schema
module Converter.Converter
  ( convert,
  )
where

import qualified Analyser.Analyser as Analyser (analyse)
import Control.Monad (unless)
import qualified Converter.Checker as Checker (check)
import qualified Converter.Valuer as Valuer
import qualified Data.Map as M
import Data.Maybe (fromMaybe)
import qualified State.FuncState as FuncState
import State.GenState (GenState, throwError)
import qualified State.GenState as GenState
  ( evaluate,
    getState,
    startState,
  )
import qualified State.GlobalState as GlobalState
import State.State (SymTab)
import qualified State.State as State
  ( getScope,
    getVariable,
    getVariableValue,
    labelNum,
    memOffset,
  )
import Types.AST (ArrayNode (..), NodeDat, Tree (..))
import Types.AssemblySchema
import Types.Error
  ( CompilerError (FatalError),
    FatalError (ConverterBug),
  )
import Types.Operator
import Types.Type (Type (..))
import qualified Types.Type as Type (typeSize)
import Types.Variables

-- | Builds an assembly schema
convert :: Tree -> Either CompilerError (AssemblySchema, SymTab)
convert ast = GenState.evaluate convertWithState ast GenState.startState

convertWithState :: Tree -> GenState (AssemblySchema, SymTab)
convertWithState ast = do
  schema <- convertToSchema ast
  symTab <- GenState.getState
  pure (schema, symTab)

convertToSchema :: Tree -> GenState AssemblySchema
convertToSchema (ProgramNode trees) = do
  schemas <- mapM convertToSchema trees
  undefSchemas <- map buildUndefinedSchema <$> GlobalState.getUndefinedVarData
  pure (ProgramSchema $ undefSchemas <> schemas)
convertToSchema funcNode@(FunctionNode _ _ _ Nothing _) = do
  Checker.check funcNode
  declareFunction funcNode
  pure SkipSchema
convertToSchema funcNode@(FunctionNode _ name _ (Just body) _) = do
  Checker.check funcNode
  FuncState.initFunction name
  declareFunction funcNode
  bodySchema <- checkReturn name <$> convertToSchema body
  GlobalState.defineFunction name
  FuncState.closeFunction
  pure (FunctionSchema name bodySchema)
convertToSchema (ParamNode typ (VarNode name _) _) = do
  FuncState.addParameter name typ
  pure SkipSchema
convertToSchema node@(FuncCallNode name argList _) = do
  Checker.check node
  argPosValues <- Valuer.argsToPosValue argList
  argSchemas <- mapM convertToSchema argList
  FuncState.paramValuesFromArgs name argPosValues
  pure (ExpressionSchema $ FunctionCallSchema name argSchemas)
convertToSchema (ArgNode arg _) = convertToSchema arg
convertToSchema (CompoundStmtNode statements _) = do
  FuncState.initScope
  statementsSchema <- mapM analyseAndConvert statements
  FuncState.closeScope
  pure (StatementSchema $ CompoundStatementSchema statementsSchema)
convertToSchema (ForLoopNode ini test iter body _) = do
  FuncState.initScope
  passLabel <- State.labelNum
  failLabel <- State.labelNum
  contLabel <- State.labelNum
  FuncState.setBreak failLabel
  FuncState.setContinue contLabel
  iniSchema <- convertToSchema ini
  testSchema <- convertToSchema test
  iterSchema <- convertToSchema iter
  bodySchema <- convertToSchema body
  FuncState.closeScope
  pure
    ( StatementSchema
        ( ForSchema
            iniSchema
            testSchema
            iterSchema
            bodySchema
            (LocalLabel passLabel)
            (LocalLabel failLabel)
            (LocalLabel contLabel)
        )
    )
convertToSchema (WhileNode test body _) = do
  loopLabel <- State.labelNum
  testLabel <- State.labelNum
  FuncState.setContinue loopLabel
  FuncState.setBreak testLabel
  testSchema <- convertToSchema test
  bodySchema <- convertToSchema body
  pure
    ( StatementSchema
        ( WhileSchema
            testSchema
            bodySchema
            (LocalLabel loopLabel)
            (LocalLabel testLabel)
        )
    )
convertToSchema (DoWhileNode body test _) = do
  loopLabel <- State.labelNum
  contLabel <- State.labelNum
  testLabel <- State.labelNum
  FuncState.setContinue contLabel
  FuncState.setBreak testLabel
  bodySchema <- convertToSchema body
  testSchema <- convertToSchema test
  pure
    ( StatementSchema
        ( DoWhileSchema
            bodySchema
            testSchema
            (LocalLabel loopLabel)
            (LocalLabel contLabel)
            (LocalLabel testLabel)
        )
    )
convertToSchema (IfNode test body possElse _) = do
  ifLabel <- LocalLabel <$> State.labelNum
  elseLabel <- LocalLabel <$> State.labelNum
  testSchema <- convertToSchema test
  bodySchema <- convertToSchema body
  elseSchema <- processPossibleNode possElse
  pure
    ( StatementSchema
        ( IfSchema
            testSchema
            bodySchema
            elseSchema
            ifLabel
            elseLabel
        )
    )
convertToSchema (PointerNode varNode typ value dat) =
  convertToSchema (DeclarationNode varNode typ value dat)
convertToSchema node@DeclarationNode {} = do
  currScope <- State.getScope
  case currScope of
    Global -> declareGlobal node
    Local -> do
      Checker.check node
      declareLocal node
convertToSchema node@AssignmentNode {} = do
  Checker.check node
  buildAssignment node
convertToSchema (AssignDereferenceNode varNode valNode operator dat) =
  convertToSchema (AssignmentNode varNode valNode operator dat)
convertToSchema (ExprStmtNode exprStatement _) = convertToSchema exprStatement
convertToSchema node@ContinueNode {} = do
  Checker.check node
  contineLabel <- LocalLabel . fromMaybe (-1) <$> FuncState.getContinue
  pure (StatementSchema $ ContinueSchema contineLabel)
convertToSchema node@BreakNode {} = do
  Checker.check node
  breakLabel <- LocalLabel . fromMaybe (-1) <$> FuncState.getBreak
  pure (StatementSchema $ BreakSchema breakLabel)
convertToSchema node@(ReturnNode valNode _) = do
  valueSchema <- convertToSchema valNode
  Checker.check node
  pure (StatementSchema $ ReturnSchema valueSchema)
convertToSchema (TernaryNode test true false _) = do
  testSchema <- convertToSchema test
  trueSchema <- convertToSchema true
  falseSchema <- convertToSchema false
  trueLabel <- LocalLabel <$> State.labelNum
  falseLabel <- LocalLabel <$> State.labelNum
  pure
    ( ExpressionSchema
        ( TernarySchema
            testSchema
            trueSchema
            falseSchema
            trueLabel
            falseLabel
        )
    )
convertToSchema (BinaryNode leftNode rightNode operator _) = do
  trueLabel <- LocalLabel <$> State.labelNum
  falseLabel <- LocalLabel <$> State.labelNum
  leftSchema <- binaryLeftSchema leftNode
  rightSchema <- convertToSchema rightNode
  pure
    ( ExpressionSchema
        ( BinarySchema
            leftSchema
            rightSchema
            operator
            trueLabel
            falseLabel
        )
    )
convertToSchema node@(UnaryNode varNode@VarNode {} unOp _) = do
  Checker.check node
  varSchema <- convertToSchema varNode
  pure (ExpressionSchema $ UnarySchema varSchema unOp)
convertToSchema node@(UnaryNode val unOp _) = do
  Checker.check node
  Valuer.checkValueIncDec node
  value <- convertToSchema val
  pure (ExpressionSchema $ UnarySchema value unOp)
convertToSchema node@(VarNode name _) = do
  Checker.check node
  varType <- State.getVariable name
  varValue <- State.getVariableValue name
  case varType of
    NotFound -> throwError $ FatalError (ConverterBug node)
    VarType typ -> pure (ExpressionSchema $ VariableSchema typ varValue)
convertToSchema node@(DereferenceNode name dat) = do
  Checker.check node
  ExpressionSchema . DereferenceSchema <$> convertToSchema (VarNode name dat)
convertToSchema node@(AddressOfNode name dat) = do
  Checker.check node
  ExpressionSchema . AddressOfSchema <$> convertToSchema (VarNode name dat)
convertToSchema NullExprNode {} =
  pure SkipSchema
convertToSchema (ConstantNode n _) =
  pure (ExpressionSchema $ LiteralSchema n)
convertToSchema (ArrayNode arrayNode) =
  convertToSchemaArray arrayNode
convertToSchema node = throwError $ FatalError (ConverterBug node)

convertToSchemaArray :: ArrayNode -> GenState AssemblySchema
convertToSchemaArray (ArrayDeclareNode len var typ Nothing dat) = do
  currScope <- State.getScope
  declareSchema <- convertToSchema (DeclarationNode var typ Nothing dat)
  case currScope of
    Local -> do
      FuncState.incrementOffsetByN (len - 1)
      pure declareSchema
    Global ->
      pure declareSchema
convertToSchemaArray (ArrayDeclareNode _ var@(VarNode name _) typ assign dat) = do
  currScope <- State.getScope
  schema <- convertToSchema (DeclarationNode var typ assign dat)
  case currScope of
    Local ->
      pure schema
    Global -> do
      GlobalState.defineGlobal name
      pure schema
convertToSchemaArray (ArrayItemsNode varNode items _) =
  processArrayItems varNode items
convertToSchemaArray (ArraySingleItemNode item _) =
  convertToSchema item
convertToSchemaArray (ArrayItemAccess pos varNode _) =
  getArrayIndexItem pos varNode
convertToSchemaArray
  node@( ArrayAssignPosNode
           arrayPosVar@( ArrayNode
                           (ArrayItemAssign _ _ iDat)
                         )
           valNode
           op
           dat
         ) = case op of
    Assignment ->
      buildAssignment $
        AssignmentNode
          arrayPosVar
          valNode
          op
          dat
    UnaryOp _ ->
      throwError $ FatalError (ConverterBug $ ArrayNode node)
    BinaryOp binOp ->
      buildAssignment $
        AssignmentNode
          arrayPosVar
          (BinaryNode arrayPosVar valNode binOp iDat)
          Assignment
          dat
convertToSchemaArray (ArrayItemAssign pos varNode _) = getArrayIndexItem pos varNode
convertToSchemaArray node = throwError $ FatalError (ConverterBug $ ArrayNode node)

-- Array

getArrayIndexItem :: Int -> Tree -> GenState AssemblySchema
getArrayIndexItem pos varNode@VarNode {} = do
  schema <- convertToSchema varNode
  setSchemaOffset pos schema
getArrayIndexItem _ node = throwError $ FatalError (ConverterBug node)

processArrayItems :: Tree -> [Tree] -> GenState AssemblySchema
processArrayItems varNode items = do
  arrayItems <- mapM (processArrayItem varNode) (zip items [0 ..])
  adjust <- stackPointerAdjustMent items
  pure
    ( StatementSchema
        ( ArrayItemsSchema
            adjust
            arrayItems
        )
    )

processArrayItem :: Tree -> (Tree, Int) -> GenState AssemblySchema
processArrayItem varNode (item, pos) = do
  currScope <- State.getScope
  varSchema <- getArrayIndexItem pos varNode
  valSchema <- convertToSchema item
  pure
    ( StatementSchema
        ( AssignmentSchema
            varSchema
            valSchema
            currScope
        )
    )

stackPointerAdjustMent :: [Tree] -> GenState Int
stackPointerAdjustMent items = do
  currScope <- State.getScope
  if currScope == Global
    then pure 0
    else do
      FuncState.incrementOffsetByN (length items - 1)
      FuncState.stackPointerValue

setSchemaOffset :: Int -> AssemblySchema -> GenState AssemblySchema
setSchemaOffset n (ExpressionSchema (VariableSchema varType varValue)) = do
  varType' <- adjustVariable (Just n) Nothing varType
  pure $ ExpressionSchema $ VariableSchema varType' varValue
setSchemaOffset _ _ = undefined

-- Function

declareFunction :: Tree -> GenState ()
declareFunction (FunctionNode typ funcName paramList _ _) = do
  declaredBefore <- GlobalState.previouslyDeclaredFunc funcName
  if not declaredBefore
    then do
      GlobalState.declareFunction typ funcName (length paramList)
      processParameters funcName paramList
    else do
      GlobalState.declareFunction typ funcName (length paramList)
      defined <- GlobalState.checkFuncDefined funcName
      unless defined $
        reprocessParameters funcName paramList
declareFunction node = throwError $ FatalError (ConverterBug node)

processParameters :: String -> [Tree] -> GenState ()
processParameters name params = do
  FuncState.initFunction name
  mapM_ convertToSchema params
  FuncState.closeFunction

reprocessParameters :: String -> [Tree] -> GenState ()
reprocessParameters funcName paramList = do
  FuncState.initFunction funcName
  posAndName <- zip [0 ..] <$> mapM paramName paramList
  FuncState.updateParameters posAndName
  GlobalState.incrementDecSeq
  FuncState.closeFunction

paramName :: Tree -> GenState String
paramName (ParamNode _ (VarNode name _) _) = pure name
paramName tree = throwError $ FatalError (ConverterBug tree)

checkReturn :: String -> AssemblySchema -> AssemblySchema
checkReturn "main" (StatementSchema (CompoundStatementSchema [])) =
  StatementSchema (CompoundStatementSchema $ addReturnZero [])
checkReturn "main" schema@(StatementSchema (CompoundStatementSchema bodySchemas)) =
  case last bodySchemas of
    (StatementSchema ReturnSchema {}) -> schema
    _ -> StatementSchema (CompoundStatementSchema $ addReturnZero bodySchemas)
checkReturn _ schema = schema

addReturnZero :: [AssemblySchema] -> [AssemblySchema]
addReturnZero bodySchema =
  bodySchema
    <> [ StatementSchema
           ( ReturnSchema
               ( ExpressionSchema
                   (LiteralSchema 0)
               )
           )
       ]

-- Variables Global

declareGlobal :: Tree -> GenState AssemblySchema
declareGlobal node@(DeclarationNode (VarNode name _) typ Nothing _) = do
  Checker.check node
  currLabel <- GlobalState.getLabel name
  case currLabel of
    Nothing -> do
      globLab <- GlobalState.makeLabel name
      GlobalState.declareGlobal name typ globLab
      pure SkipSchema
    Just _ -> pure SkipSchema
declareGlobal node@(DeclarationNode (VarNode name _) typ _ _) = do
  currLabel <- GlobalState.getLabel name
  case currLabel of
    Just _ -> do
      Checker.check node
      processGlobalAssignment node
    Nothing -> do
      globLab <- GlobalState.makeLabel name
      GlobalState.declareGlobal name typ globLab
      Checker.check node
      processGlobalAssignment node
declareGlobal tree = throwError $ FatalError (ConverterBug tree)

processGlobalAssignment :: Tree -> GenState AssemblySchema
processGlobalAssignment (DeclarationNode varNode typ (Just assignNode) _) = do
  currScope <- State.getScope
  varSchema <- convertToSchema varNode
  assignSchema <- convertToSchema assignNode
  pure (DeclarationSchema varSchema assignSchema currScope typ)
processGlobalAssignment tree = throwError $ FatalError (ConverterBug tree)

defineGlobal :: Tree -> GenState AssemblySchema
defineGlobal (AssignmentNode varNode@(VarNode name _) valNode _ dat) = do
  GlobalState.defineGlobal name
  processAssignment name dat varNode valNode
defineGlobal tree = throwError $ FatalError (ConverterBug tree)

buildUndefinedSchema :: (String, Type) -> AssemblySchema
buildUndefinedSchema (label, typ) =
  DeclarationSchema
    (ExpressionSchema $ VariableSchema (GlobalVar label 0) (setUndefinedValue typ))
    SkipSchema
    Global
    typ

setUndefinedValue :: Type -> VarValue
setUndefinedValue IntVar = SingleValue 0
setUndefinedValue IntPointer = SingleValue 0
setUndefinedValue (IntArray n) = MultiValue $ M.fromList $ zip [0 ..] (replicate n 0)
setUndefinedValue _ = UntrackedValue

-- Variables Local

declareLocal :: Tree -> GenState AssemblySchema
declareLocal (DeclarationNode varNode@(VarNode name _) typ value _) = do
  _ <- FuncState.addVariable name typ
  currScope <- State.getScope
  varSchema <- convertToSchema varNode
  valSchema <- processPossibleNode value
  pure (DeclarationSchema varSchema valSchema currScope typ)
declareLocal tree = throwError $ FatalError (ConverterBug tree)

defineLocal :: Tree -> GenState AssemblySchema
defineLocal (AssignmentNode varNode@(VarNode name _) valNode _ dat) =
  processAssignment name dat varNode valNode
defineLocal (AssignmentNode derefNode@(DereferenceNode name _) valNode _ dat) =
  processAssignment name dat derefNode valNode
defineLocal tree = throwError $ FatalError (ConverterBug tree)

-- Shared

processAssignment :: String -> NodeDat -> Tree -> Tree -> GenState AssemblySchema
processAssignment varName dat varNode valNode = do
  assignmentSchema <- buildAssignmentSchema varNode valNode
  Valuer.storeValue dat varName valNode
  pure assignmentSchema

buildAssignmentSchema :: Tree -> Tree -> GenState AssemblySchema
buildAssignmentSchema varNode valNode = do
  currScope <- State.getScope
  varSchema <- convertToSchema varNode
  valSchema <- convertToSchema valNode
  pure (StatementSchema $ AssignmentSchema varSchema valSchema currScope)

buildAssignment :: Tree -> GenState AssemblySchema
buildAssignment (AssignmentNode varNode valNode (BinaryOp binOp) dat) =
  convertToSchema $
    AssignmentNode
      varNode
      (BinaryNode varNode valNode binOp dat)
      Assignment
      dat
buildAssignment
  ( AssignmentNode
      (ArrayNode (ArrayItemAssign pos varNode _))
      valNode
      _
      _
    ) = processArrayItem varNode (valNode, pos)
buildAssignment node@(AssignmentNode _ _ Assignment _) =
  buildBasicAssignment node
buildAssignment node = throwError $ FatalError (ConverterBug node)

buildBasicAssignment :: Tree -> GenState AssemblySchema
buildBasicAssignment node = do
  currScope <- State.getScope
  case currScope of
    Local -> defineLocal node
    Global -> defineGlobal node

processPossibleNode :: Maybe Tree -> GenState AssemblySchema
processPossibleNode Nothing = pure SkipSchema
processPossibleNode (Just node) = convertToSchema node

analyseAndConvert :: Tree -> GenState AssemblySchema
analyseAndConvert tree = Analyser.analyse tree >>= convertToSchema

adjustVariable :: Maybe Int -> Maybe Int -> VarType -> GenState VarType
adjustVariable (Just multiplier) (Just total) (LocalVar offset _ _) =
  pure $ LocalVar offset (multiplier * State.memOffset) total
adjustVariable (Just multiplier) Nothing (LocalVar offset _ total) =
  pure $ LocalVar offset (multiplier * State.memOffset) (total - (multiplier * State.memOffset))
adjustVariable Nothing (Just total) (LocalVar offset multiplier _) =
  pure $ LocalVar offset multiplier total
adjustVariable (Just offset) _ (ParamVar position _) =
  pure $ ParamVar position offset
adjustVariable (Just offset) _ (GlobalVar label _) = do
  typ <- GlobalState.typeFromLabel label
  pure $ GlobalVar label (offset * Type.typeSize typ)
adjustVariable _ _ varType = pure varType

binaryLeftSchema :: Tree -> GenState AssemblySchema
binaryLeftSchema (ArrayNode (ArrayItemAssign pos varNode _)) = getArrayIndexItem pos varNode
binaryLeftSchema tree = convertToSchema tree
