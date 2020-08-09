{-|
Module       : State
Description  : Shared state querying functions

Functions that query state in local and global scope
-}
module State.State
        (module State.FrameStack,
         SymTab,
         labelNum,
         memOffset,
         getVariable
        ) where


import           State.FrameStack  (currentFunc, getScope)
import qualified State.FuncState   (parameterPosition, variableOffset)
import           State.GenState    (GenState, labelNum)
import qualified State.GlobalState (getLabel)
import           State.SymbolTable (SymTab, memOffset)
import           Types.Variables   (VarLookup (..), VarType (..))


-- | Build variable data type from retrieved data
getVariable :: String -> GenState VarLookup
getVariable name = do
        localVar  <- mkVarLocal <$> State.FuncState.variableOffset name
        paramVar  <- mkVarParam <$> State.FuncState.parameterPosition name
        globalVar <- mkVarGlobal <$> State.GlobalState.getLabel name
        case (localVar, paramVar, globalVar) of
             (var@(VarType LocalVar{}), _, _)  -> pure var
             (_, var@(VarType ParamVar{}), _)  -> pure var
             (_, _, var@(VarType GlobalVar{})) -> pure var
             (_, _, _)                         -> pure NotFound


mkVarLocal :: Maybe Int -> VarLookup
mkVarLocal (Just n) = VarType (LocalVar n 0 (-n))
mkVarLocal Nothing  = NotFound


mkVarParam :: Maybe Int -> VarLookup
mkVarParam (Just n) = VarType (ParamVar n 0)
mkVarParam Nothing  = NotFound


mkVarGlobal :: Maybe String -> VarLookup
mkVarGlobal (Just s) = VarType (GlobalVar s 0)
mkVarGlobal Nothing  = NotFound