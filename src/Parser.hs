{-|
Module       : Parser
Description  : Produces an abstract syntax tree

Converts a list of tokens into an abstract syntax tree
representing the C program.
-}
module Parser (parse) where

import           Control.Monad (unless)

import           AST           (Tree (..))
import           Error         (CompilerError (..), ParserError (..),
                                SyntaxError (..), TypeError (..))
import qualified NewOps        (tokToBinOp, tokToUnaryOp)
import           SuccState     (SuccStateM, getState, putState, runSuccState,
                                throwError)
import           Tokens        (Keyword (..), Operator (..), Token (..))
import qualified Tokens        (unary)
import           Type          (Type (..))


type ParserState = SuccStateM Tree

startState :: Tree
startState = ProgramNode []


-- | Convert a list of tokens into an AST
parse :: [Token] -> Either CompilerError Tree
parse toks = runSuccState parseTokens toks startState


parseTokens :: [Token] -> ParserState Tree
parseTokens []   = throwError $ ParserError (TokensError [])
parseTokens toks = parseTopLevelItems toks


parseTopLevelItems :: [Token] -> ParserState Tree
parseTopLevelItems [] = do
        ast <- getState
        case ast of
             ProgramNode items -> pure $ ProgramNode (reverse items)
             _                 -> throwError ImpossibleError
parseTopLevelItems toks@(Keyword typ:_)
        | validType typ = do
                ast           <- getState
                items         <- getTreeList ast
                (item, toks') <- parseTopLevelItem toks
                putState $ ProgramNode (item:items)
                parseTopLevelItems toks'
        | otherwise = throwError $ TypeError (InvalidType (Keyword typ))
parseTopLevelItems (a:_) = throwError $ TypeError (InvalidType a)


parseTopLevelItem :: [Token] -> ParserState (Tree, [Token])
parseTopLevelItem []                       = throwError ImpossibleError
parseTopLevelItem toks@(_:_:_:OpenParen:_) = parseFunction toks
parseTopLevelItem toks@(_:_:OpenParen:_)   = parseFunction toks
parseTopLevelItem toks                     = parseDeclaration toks


parseDeclaration :: [Token] -> ParserState (Tree, [Token])
parseDeclaration []  = throwError ImpossibleError
parseDeclaration [a] = throwError $ ParserError (TokensError [a])
parseDeclaration toks@(_:Op Asterisk:_) = parsePointerDec toks
parseDeclaration toks@(_:Ident name:_) = do
        varType        <- parseType toks
        toks'          <- consumeTok toks
        (tree, toks'') <- parseOptAssign toks'
        pure (DeclarationNode name varType tree, toks'')
parseDeclaration (_:b:_) = throwError $ SyntaxError (InvalidIdentifier b)


parseFunction :: [Token] -> ParserState (Tree, [Token])
parseFunction toks = do
        typ             <- parseType toks
        name            <- parseFuncName toks
        (params, toks') <- parseFuncParams toks
        (items, toks'') <- parseFuncBlockItems [] toks'
        pure (FunctionNode typ name params items, toks'')


parseFuncName :: [Token] -> ParserState String
parseFuncName (_:Ident name:_)   = pure name
parseFuncName (_:_:Ident name:_) = pure name
parseFuncName _                  = throwError $ SyntaxError MissingIdentifier


parseFuncParams :: [Token] -> ParserState ([Tree], [Token])
parseFuncParams (_:Op Asterisk:_:rest) = parseParams [] rest
parseFuncParams (_:Ident _:rest)       = parseParams [] rest
parseFuncParams toks = throwError $ ParserError (TokensError toks)


parseParams :: [Tree] -> [Token] -> ParserState ([Tree], [Token])
parseParams prms toks = parsePassIn prms toks parseTheParams


parseTheParams :: [Tree] -> [Token] -> ParserState ([Tree], [Token])
parseTheParams prms toks@(Keyword typ:_)
        | validType typ = do
                (tree, toks') <- parseParam toks
                parseParams (tree:prms) toks'
        | otherwise = throwError $ TypeError (InvalidType (Keyword typ))
parseTheParams _ toks = throwError $ ParserError (TokensError toks)


parseParam :: [Token] -> ParserState (Tree, [Token])
parseParam toks = do
        typ            <- parseType toks
        toks'          <- consumeTok toks
        (tree, toks'') <- parseParamValue toks'
        case tree of
             VarNode _ -> pure (ParamNode typ tree, toks'')
             _         -> throwError $ ParserError (TreeError tree)


parseParamValue :: [Token] -> ParserState (Tree, [Token])
parseParamValue (Op Asterisk:rest) = parseExpression rest
parseParamValue toks@(Ident _:_)   = parseExpression toks
parseParamValue toks = throwError $ ParserError (TokensError toks)


parseFuncBlockItems :: [Tree] -> [Token] -> ParserState (Maybe [Tree], [Token])
parseFuncBlockItems _ (SemiColon:rest) = pure (Nothing, rest)
parseFuncBlockItems stmts (OpenBrace:rest) = do
        (tree, toks') <- parseBlock stmts rest
        toks''        <- verifyAndConsume CloseBrace toks'
        pure (Just tree, toks'')
parseFuncBlockItems _ toks = throwError $ ParserError (TokensError toks)


parseBlock :: [Tree] -> [Token] -> ParserState ([Tree], [Token])
parseBlock stmts toks@(CloseBrace:_) = pure (reverse stmts, toks)
parseBlock stmts toks = do
        (tree, toks') <- parseBlockItem toks
        parseBlock (tree:stmts) toks'


parseBlockItem :: [Token] -> ParserState (Tree, [Token])
parseBlockItem toks@(Keyword kwd:_)
        | validType kwd = parseDeclaration toks
        | otherwise     = parseStatement toks
parseBlockItem toks = parseStatement toks


parseStatement :: [Token] -> ParserState (Tree, [Token])
parseStatement [] = throwError $ ParserError (TokensError [])
parseStatement toks@(first:rest) =
        case first of
             Keyword Return   -> parseReturnStmt rest
             Keyword If       -> parseIfStatement rest
             Keyword While    -> parseWhileStatement rest
             Keyword Do       -> parseDoWhile rest
             Keyword For      -> parseForLoop rest
             Keyword Break    -> parseBreak rest
             Keyword Continue -> parseContinue rest
             OpenBrace        -> parseCompoundStmt rest
             _                -> parseExprStatement toks


{-
- Parses expressions where a semi-colon is required afterwards
-
- null expression:         ;
- expression statements:   2 + 2;
- elements of loops:       (i = 0; i < 10; i++)
- assignments:             a = 10; *p = 10;
- function calls:          dog(8);
-
-}
parseExprStatement :: [Token] -> ParserState (Tree, [Token])
parseExprStatement (SemiColon:rest) = parseNullStatement rest
parseExprStatement toks = do
        (tree, toks') <- parseExpression toks
        toks''        <- verifyAndConsume SemiColon toks'
        pure (ExprStmtNode tree, toks'')


parseBreak :: [Token] -> ParserState (Tree, [Token])
parseBreak (SemiColon:rest) = pure (BreakNode, rest)
parseBreak _ = throwError $ SyntaxError (MissingToken SemiColon)


parseContinue :: [Token] -> ParserState (Tree, [Token])
parseContinue (SemiColon:rest) = pure (ContinueNode, rest)
parseContinue _ = throwError $ SyntaxError (MissingToken SemiColon)


parseCompoundStmt :: [Token] -> ParserState (Tree, [Token])
parseCompoundStmt toks = do
        (items, toks') <- parseBlock [] toks
        toks''         <- verifyAndConsume CloseBrace toks'
        pure (CompoundStmtNode items, toks'')


parseForLoop :: [Token] -> ParserState (Tree, [Token])
parseForLoop toks = do
        toks'               <- verifyAndConsume OpenParen toks
        (ini, toks'')       <- parseBlockItem toks'
        (test, toks''')     <- parseExprStatement toks''
        (change, toks'''')  <- parsePostExp toks'''
        toks'''''           <- verifyAndConsume CloseParen toks''''
        (stmts, toks'''''') <- parseStatement toks'''''
        if test == NullExprNode
           then pure (ForLoopNode ini (ConstantNode 1) change stmts, toks'''''')
           else pure (ForLoopNode ini test change stmts, toks'''''')


parsePostExp :: [Token] -> ParserState (Tree, [Token])
parsePostExp toks = do
        (tree, toks') <- parseForLoopPostExp toks
        nextTokIsNot SemiColon toks'
        pure (tree, toks')


parseForLoopPostExp :: [Token] -> ParserState (Tree, [Token])
parseForLoopPostExp (SemiColon:_) =
        throwError $ SyntaxError (UnexpectedToken SemiColon)
parseForLoopPostExp toks@(CloseParen:_) = nullExpr toks
parseForLoopPostExp toks                = parseExpression toks


parseDoWhile :: [Token] -> ParserState (Tree, [Token])
parseDoWhile toks@(OpenBrace:_) = do
        (stmts, toks') <- parseStatement toks
        case toks' of
             (Keyword While:OpenParen:rest) -> do
                     (test, toks'') <- parseExpression rest
                     toks'''        <- verifyAndConsume CloseParen toks''
                     toks''''       <- verifyAndConsume SemiColon toks'''
                     pure (DoWhileNode stmts test, toks'''')
             (_:OpenParen:_) ->
                     throwError $ SyntaxError (MissingKeyword While)
             (Keyword While:_:_) ->
                     throwError $ SyntaxError (MissingToken OpenParen)
             _ -> throwError $ ParserError (TokensError toks')
parseDoWhile _ = throwError $ SyntaxError (MissingToken OpenBrace)


parseWhileStatement :: [Token] -> ParserState (Tree, [Token])
parseWhileStatement toks = do
        (test, toks')   <- parseConditionalParen toks
        (stmts, toks'') <- parseStatement toks'
        pure (WhileNode test stmts, toks'')


parseIfStatement :: [Token] -> ParserState (Tree, [Token])
parseIfStatement toks = do
        (test, toks')       <- parseConditionalParen toks
        (stmts, toks'')     <- parseStatement toks'
        (possElse, toks''') <- parseOptionalElse toks''
        pure (IfNode test stmts possElse, toks''')



parseConditionalParen :: [Token] -> ParserState (Tree, [Token])
parseConditionalParen toks = do
        toks'             <- verifyAndConsume OpenParen toks
        (test, toks'')    <- parseExpression toks'
        toks'''           <- verifyAndConsume CloseParen toks''
        pure (test, toks''')


parseOptionalElse :: [Token] -> ParserState (Maybe Tree, [Token])
parseOptionalElse (Keyword Else:rest) = do
        (tree, toks') <- parseStatement rest
        pure (Just tree, toks')
parseOptionalElse toks = pure (Nothing, toks)


parseReturnStmt :: [Token] -> ParserState (Tree, [Token])
parseReturnStmt toks = do
        (tree, toks') <- parseExpression toks
        toks''        <- verifyAndConsume SemiColon toks'
        pure (ReturnNode tree, toks'')


parseNullStatement :: [Token] -> ParserState (Tree, [Token])
parseNullStatement toks = pure (NullExprNode, toks)


parsePointerDec :: [Token] -> ParserState (Tree, [Token])
parsePointerDec toks@(_:_:Ident name:_) = do
        typ            <- parseType toks
        toks'          <- consumeNToks 2 toks
        (tree, toks'') <- parseOptAssign toks'
        pure (PointerNode name typ tree, toks'')
parsePointerDec (_:_:c:_) = throwError $ SyntaxError (InvalidIdentifier c)
parsePointerDec toks = throwError $ ParserError (TokensError toks)


parseOptAssign :: [Token] -> ParserState (Maybe Tree, [Token])
parseOptAssign toks = do
        (tree, toks') <- parseOptionalAssign toks
        toks''        <- verifyAndConsume SemiColon toks'
        pure (tree, toks'')


parseOptionalAssign :: [Token] -> ParserState (Maybe Tree, [Token])
parseOptionalAssign toks@(_:Op op:_)
        | op `elem` assign = do
                (tree, toks') <- parseExpression toks
                pure (Just tree, toks')
        | otherwise = throwError $ SyntaxError (UnexpectedToken (Op op))
parseOptionalAssign toks = do
        toks' <- consumeTok toks
        pure (Nothing, toks')


parseExpression :: [Token] -> ParserState (Tree, [Token])
parseExpression toks = do
        (tree, toks') <- parseTernaryExp toks
        case toks' of
             (Op op:_)
                | op `elem` assign -> parseAssignExpression tree toks'
                | otherwise ->
                        throwError $ SyntaxError (UnexpectedToken (Op op))
             _ -> pure (tree, toks')


parseAssignExpression :: Tree -> [Token] -> ParserState (Tree, [Token])
parseAssignExpression tree (Op op:rest) = do
                   (asgn, toks') <- parseExpression rest
                   let binOp = NewOps.tokToBinOp op
                   case tree of
                     (VarNode a) ->
                             pure (AssignmentNode a asgn binOp, toks')
                     (DereferenceNode a) ->
                             pure (AssignDereferenceNode a asgn binOp, toks')
                     _ -> throwError $ ParserError (TreeError tree)
parseAssignExpression _ toks = throwError $ ParserError (TokensError toks)


parseTernaryExp :: [Token] -> ParserState (Tree, [Token])
parseTernaryExp toks = do
        (cond, toks') <- parseLogicalOrExp toks
        case lookAhead toks' of
             QuestMark -> do
                     toks''             <- verifyAndConsume QuestMark toks'
                     (expr1, toks''')   <- parseExpression toks''
                     toks''''           <- verifyAndConsume Colon toks'''
                     (expr2, toks''''') <- parseTernaryExp toks''''
                     pure (TernaryNode cond expr1 expr2, toks''''')
             _ -> pure (cond, toks')


parseLogicalOrExp :: [Token] -> ParserState (Tree, [Token])
parseLogicalOrExp toks = do
        (orTree, toks') <- parseLogicalAndExp toks
        parseBinaryExp orTree toks' parseLogicalAndExp [PipePipe]


parseLogicalAndExp :: [Token] -> ParserState (Tree, [Token])
parseLogicalAndExp toks = do
        (andTree, toks') <- parseEqualityExp toks
        parseBinaryExp andTree toks' parseEqualityExp [LogicalAND]


parseEqualityExp :: [Token] -> ParserState (Tree, [Token])
parseEqualityExp toks = do
        (equTree, toks') <- parseRelationalExp toks
        parseBinaryExp equTree toks' parseRelationalExp [Equal,NotEqual]


parseRelationalExp :: [Token] -> ParserState (Tree, [Token])
parseRelationalExp toks = do
        (relaTree, toks') <- parseAdditiveExp toks
        parseBinaryExp relaTree toks' parseAdditiveExp
             [GreaterThan,LessThan,GreaterThanOrEqual,LessThanOrEqual]


parseAdditiveExp :: [Token] -> ParserState (Tree, [Token])
parseAdditiveExp toks = do
        (termTree, toks') <- parseTerm toks
        parseBinaryExp termTree toks' parseTerm [PlusSign,MinusSign]


parseTerm :: [Token] -> ParserState (Tree, [Token])
parseTerm toks = do
        (facTree, toks') <- parseFactor toks
        parseBinaryExp facTree toks' parseFactor [Asterisk,BackSlash,Percent]


parseFactor :: [Token] -> ParserState (Tree, [Token])
parseFactor [] = throwError $ ParserError (TokensError [])
parseFactor toks@(next:rest) =
        case next of
             SemiColon    -> pure (NullExprNode, rest)
             (ConstInt n) -> pure (ConstantNode n, rest)
             (Ident a)   ->
                     if lookAhead rest == OpenParen
                        then parseFuncCall toks
                        else pure (VarNode a, rest)
             Ampersand -> parseAddressOf rest
             (Op op)
                | op == Asterisk -> parseDereference rest
                | op `elem` Tokens.unary -> do
                        (tree, toks') <- parseFactor rest
                        let unOp = NewOps.tokToUnaryOp op
                        pure (UnaryNode tree unOp, toks')
             OpenParen -> do
                     (tree, toks') <- parseExpression rest
                     toks''        <- verifyAndConsume CloseParen toks'
                     pure (tree, toks'')
             _ -> throwError $ ParserError (ParseError (show toks))


parseAddressOf :: [Token] -> ParserState (Tree, [Token])
parseAddressOf (Ident n:rest) = pure (AddressOfNode n, rest)
parseAddressOf (a:_)          = throwError $ SyntaxError (InvalidIdentifier a)
parseAddressOf toks           = throwError $ ParserError (TokensError toks)


parseDereference :: [Token] -> ParserState (Tree, [Token])
parseDereference (Ident n:rest) = pure (DereferenceNode n, rest)
parseDereference (a:_) = throwError $ SyntaxError (InvalidIdentifier a)
parseDereference toks = throwError $ ParserError (TokensError toks)


parseFuncCall :: [Token] -> ParserState (Tree, [Token])
parseFuncCall toks@(Ident a:OpenParen:_) = do
        toks'          <- consumeTok toks
        (tree, toks'') <- parseArgs [] toks'
        pure (FuncCallNode a tree, toks'')
parseFuncCall (Ident _:_:_) =
        throwError $ SyntaxError (MissingToken OpenParen)
parseFuncCall (a:OpenParen:_) =
        throwError $ SyntaxError (InvalidIdentifier a)
parseFuncCall (a:_:_) =
        throwError $ SyntaxError (UnexpectedToken a)
parseFuncCall toks =
        throwError $ ParserError (TokensError toks)


parseArgs :: [Tree] -> [Token] -> ParserState ([Tree], [Token])
parseArgs args toks = parsePassIn args toks parseTheArgs


parseTheArgs :: [Tree] -> [Token] -> ParserState ([Tree], [Token])
parseTheArgs as toks = do
        (tree, toks') <- parseExpression toks
        parseArgs (tree:as) toks'


parsePassIn :: [Tree]
            -> [Token]
            -> ([Tree] -> [Token] -> ParserState ([Tree], [Token]))
            -> ParserState ([Tree], [Token])
parsePassIn _ [] _ = throwError $ ParserError (TokensError [])
parsePassIn xs (OpenParen:CloseParen:rest) _ = pure (xs, rest)
parsePassIn xs (CloseParen:rest) _           = pure (reverse xs, rest)
parsePassIn _ (Comma:CloseParen:_) _ =
        throwError $ SyntaxError (UnexpectedToken Comma)
parsePassIn xs (OpenParen:rest) f = f xs rest
parsePassIn xs (Comma:rest) f     = f xs rest
parsePassIn _ (a:_) _ = throwError $ SyntaxError (UnexpectedToken a)


parseBinaryExp :: Tree
               -> [Token]
               -> ([Token] -> ParserState (Tree, [Token]))
               -> [Operator]
               -> ParserState (Tree, [Token])
parseBinaryExp _ [] _ _ = throwError $ ParserError (TokensError [])
parseBinaryExp _ _ _ [] = throwError ImpossibleError
parseBinaryExp tree toks@(Op op:rest) f ops
        | op `elem` ops = do
                (ntree, toks'') <- f rest
                let binOp = NewOps.tokToBinOp op
                parseBinaryExp (BinaryNode tree ntree binOp) toks'' f ops
        | otherwise = pure (tree, toks)
parseBinaryExp tree toks _ _ = pure (tree, toks)


getTreeList :: Tree -> ParserState [Tree]
getTreeList (ProgramNode treeList) = pure treeList
getTreeList _                      = throwError ImpossibleError


assign :: [Operator]
assign = [Assign,
          PlusAssign,
          MinusAssign,
          MultiplyAssign,
          DivideAssign,
          ModuloAssign
         ]


verifyAndConsume :: Token -> [Token] -> ParserState [Token]
verifyAndConsume t toks = do
        nextTokIs t toks
        consumeTok toks


nextTokIs :: Token -> [Token] -> ParserState ()
nextTokIs t []    = throwError $ SyntaxError (MissingToken t)
nextTokIs t [a]   = checkIsTok t a
nextTokIs t (a:_) = checkIsTok t a


nextTokIsNot :: Token -> [Token] -> ParserState ()
nextTokIsNot _ []    = throwError $ ParserError (TokensError [])
nextTokIsNot t [a]   = checkIsNotTok t a
nextTokIsNot t (a:_) = checkIsNotTok t a


checkIsTok :: Token -> Token -> ParserState ()
checkIsTok t a = unless (t == a) $ throwError $ SyntaxError (MissingToken t)


checkIsNotTok :: Token -> Token -> ParserState ()
checkIsNotTok t a = unless ( t /= a) $ throwError $ SyntaxError (UnexpectedToken a)


consumeTok :: [Token] -> ParserState [Token]
consumeTok []       = throwError $ ParserError (TokensError [])
consumeTok [_]      = pure []
consumeTok (_:toks) = pure toks


consumeNToks :: Int -> [Token] -> ParserState [Token]
consumeNToks 0 toks = pure toks
consumeNToks n toks = do
        toks' <- consumeTok toks
        consumeNToks (n-1) toks'


parseType :: [Token] -> ParserState Type
parseType (Keyword Int:Op Asterisk:_) = pure IntPointer
parseType (Keyword Int:_)             = pure IntVar
parseType (a:_) = throwError $ TypeError (InvalidType a)
parseType toks = throwError $ ParserError (TokensError toks)


nullExpr :: [Token] -> ParserState (Tree, [Token])
nullExpr toks = pure (NullExprNode, toks)


validType :: Keyword -> Bool
validType kwd = kwd == Int

lookAhead :: [Token] -> Token
lookAhead []    = Wut
lookAhead (c:_) = c
