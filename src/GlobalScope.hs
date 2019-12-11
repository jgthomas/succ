
module GlobalScope (declareFunction,
                    defineFunction,
                    declareGlobal,
                    decParamCount,
                    decSeqNumber,
                    currentSeqNumber,
                    globalLabel,
                    globalType,
                    declaredFuncType,
                    checkVarDefined,
                    checkFuncDefined,
                    getUndefined,
                    storeForInit,
                    getAllForInit,
                    defineGlobal) where


import qualified Data.Map as M
import qualified Data.Set as S

import Types                (SymTab(globalScope),
                             GlobalScope(..),
                             GlobalVar(..),
                             Type)
import SuccState            (GenState,
                             getState,
                             putState)
import qualified Types      (mkGloVar)
import qualified FrameStack (currentFunction)


decParamCount :: String -> GenState (Maybe Int)
decParamCount name = lookUp name funcParams


decSeqNumber :: String -> GenState (Maybe Int)
decSeqNumber name = lookUp name funcDecSeq


globalLabel :: String -> GenState (Maybe String)
globalLabel name = extract globLabel <$> lookUp name declaredVars


globalType :: String -> GenState (Maybe Type)
globalType name = extract globType <$> lookUp name declaredVars


declaredFuncType :: String -> GenState (Maybe Type)
declaredFuncType name = lookUp name funcTypes


currentSeqNumber :: GenState (Maybe Int)
currentSeqNumber = do
        currFunc <- FrameStack.currentFunction
        decSeqNumber currFunc


checkVarDefined :: String -> GenState Bool
checkVarDefined name = S.member name . definedVars <$> getGlobalScope


checkFuncDefined :: String -> GenState Bool
checkFuncDefined name = S.member name . definedFuncs <$> getGlobalScope


declareFunction :: Type -> String -> Int -> GenState ()
declareFunction typ funcName paramCount = do
        gscope <- getGlobalScope
        let gscope'   = addSymbol funcName gscope
            gscope''  = addParams funcName paramCount gscope'
            gscope''' = addType funcName typ gscope''
        updateGlobalScope gscope'''


defineFunction :: String -> GenState ()
defineFunction name = do
        gscope <- getGlobalScope
        updateGlobalScope $ funcAsDefined name gscope


declareGlobal :: String -> Type -> String -> GenState ()
declareGlobal name typ label = do
        gscope <- getGlobalScope
        let globVar = Types.mkGloVar label typ
        updateGlobalScope $ addGlobal name globVar gscope


defineGlobal :: String -> GenState ()
defineGlobal name = do
        gscope <- getGlobalScope
        updateGlobalScope $ varAsDefined name gscope


getUndefined :: GenState [String]
getUndefined = do
        gscope <- getGlobalScope
        let definedSet   = definedVars gscope
            declaredSet  = M.keysSet $ declaredVars gscope
            undefinedSet = S.difference declaredSet definedSet
        map globLabel
            . M.elems
            . M.filterWithKey (\k _ -> k `elem` undefinedSet)
            . declaredVars
            <$> getGlobalScope


storeForInit :: String -> GenState ()
storeForInit code = do
        gscope <- getGlobalScope
        let gscope' = gscope { varsToinit = code : varsToinit gscope }
        updateGlobalScope gscope'


getAllForInit :: GenState [String]
getAllForInit = varsToinit <$> getGlobalScope


{- Internal -}

getGlobalScope :: GenState GlobalScope
getGlobalScope = do
        state <- getState
        return . globalScope $ state


updateGlobalScope :: GlobalScope -> GenState ()
updateGlobalScope gs = do
        state  <- getState
        putState $ state { globalScope = gs }


lookUp :: (Ord k) => k -> (GlobalScope -> M.Map k a) -> GenState (Maybe a)
lookUp n f = M.lookup n . f <$> getGlobalScope


extract :: (GlobalVar -> a) -> Maybe GlobalVar -> Maybe a
extract f (Just gv) = Just . f $ gv
extract _ Nothing   = Nothing


addGlobal :: String -> GlobalVar -> GlobalScope -> GlobalScope
addGlobal n g s = s { declaredVars = M.insert n g $ declaredVars s }


addParams :: String -> Int -> GlobalScope -> GlobalScope
addParams n p s = s { funcParams = M.insert n p $ funcParams s }


addType :: String -> Type -> GlobalScope -> GlobalScope
addType n t s = s { funcTypes = M.insert n t $ funcTypes s }


varAsDefined :: String -> GlobalScope -> GlobalScope
varAsDefined n s = s { definedVars = S.insert n $ definedVars s }


funcAsDefined :: String -> GlobalScope -> GlobalScope
funcAsDefined n s = s { definedFuncs = S.insert n $ definedFuncs s }


addSymbol :: String -> GlobalScope -> GlobalScope
addSymbol name gs =
        let i   = seqNum gs
            gs' = gs { seqNum = i + 1 }
            in
        gs' { funcDecSeq = M.insert name i $ funcDecSeq gs' }
