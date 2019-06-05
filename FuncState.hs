module FuncState (initScope,
                  closeScope,
                  initFunction,
                  closeFunction,
                  functionDefined,
                  getBreak,
                  setBreak,
                  getContinue,
                  setContinue,
                  checkVariable,
                  variableOffset,
                  addParameter,
                  parameterPosition,
                  parameterDeclared,
                  memOffsetSize,
                  addVariable,
                  stackPointerValue) where

import qualified Data.Map as M

import Evaluator            (Evaluator(Ev))
import Types                (SymTab(scopesData, funcStates, offset), FuncState(..))
import qualified FrameStack (currentFunction, popFunctionName, pushFunctionName)


type LocalScope = M.Map String Int
type FunctionScope = M.Map Int LocalScope
type ProgramScope = M.Map String FunctionScope


{- API -}

initFunction :: String -> Evaluator ()
initFunction name = do
        FrameStack.pushFunctionName name
        progScope <- updateProgramScope name M.empty
        funcScope <- getFunctionScope name progScope
        funcScope' <- updateFunctionScope baseScope M.empty funcScope
        updateProgramScope name funcScope'
        newFuncState name


closeFunction :: Evaluator ()
closeFunction = do
        FrameStack.popFunctionName


initScope :: Evaluator ()
initScope = do
        currFuncName <- FrameStack.currentFunction
        newScopeLevel <- incrementScope
        progScope <- getProgramScope
        funcScope <- getFunctionScope currFuncName progScope
        funcScope' <- updateFunctionScope newScopeLevel M.empty funcScope
        updateProgramScope currFuncName funcScope'
        addNestedScope currFuncName newScopeLevel -- FS


closeScope :: Evaluator Int
closeScope = do
        decrementScope


functionDefined :: String -> Evaluator Bool
functionDefined funcName = do
        progScope <- getProgramScope
        case M.lookup funcName progScope of
             Just fScope -> return True
             Nothing     -> return False


getBreak :: Evaluator (Maybe Int)
getBreak = do
        getOffset "@Break"


getContinue :: Evaluator (Maybe Int)
getContinue = do
        getOffset "@Continue"


setBreak :: Int -> Evaluator ()
setBreak labelNo = do
        store "@Break" labelNo
        storeFS "@Break" labelNo


setContinue :: Int -> Evaluator ()
setContinue labelNo = do
        store "@Continue" labelNo
        storeFS "@Continue" labelNo


checkVariable :: String -> Evaluator Bool
checkVariable varName = do
        currFuncName <- FrameStack.currentFunction
        scopeLevel <- findScope currFuncName
        progScope <- getProgramScope
        funcScope <- getFunctionScope currFuncName progScope
        locScope <- getLocalScope scopeLevel funcScope
        case getVar varName locScope of
             Just v  -> return True
             Nothing -> return False


variableOffset :: String -> Evaluator (Maybe Int)
variableOffset name = do
        getOffset name


addVariable :: String -> Evaluator Int
addVariable varName = do
        currOff <- currentOffset
        store varName currOff
        storeFS varName currOff -- FS
        incrementOffset
        return currOff


stackPointerValue :: Evaluator Int
stackPointerValue = do
        currOff <- currentOffset
        return $ negate currOff


-- PARAMETERS DECLARED

addParameter :: String -> Evaluator ()
addParameter paramName = do
        currFuncName <- FrameStack.currentFunction
        funcState    <- getFunctionState currFuncName
        let funcState' = addParam paramName funcState
        setFunctionState currFuncName funcState'


parameterPosition :: String -> Evaluator (Maybe Int)
parameterPosition paramName = do
        currFuncName <- FrameStack.currentFunction
        funcState    <- getFunctionState currFuncName
        case M.lookup paramName $ parameters funcState of
             Just pos -> return (Just pos)
             Nothing  -> return Nothing


parameterDeclared :: String -> Evaluator Bool
parameterDeclared paramName = do
        pos <- parameterPosition paramName
        case pos of
             Just pos -> return True
             Nothing  -> return False


{- Internal -}

newFuncState :: String -> Evaluator ()
newFuncState name = Ev $ \symTab ->
        ((), symTab { funcStates = M.insert name makeFs $ funcStates symTab })


makeFs :: FuncState
makeFs = Fs 0 0 M.empty (M.singleton 0 M.empty)


addNestedScope :: String -> Int -> Evaluator ()
addNestedScope name level = do
        fs <- getFunctionState name
        let fs' = fs { scopes = M.insert level M.empty $ scopes fs }
        setFunctionState name fs'


getOffset :: String -> Evaluator (Maybe Int)
getOffset name = do
        currFuncName <- FrameStack.currentFunction
        scopeLevel <- findScope currFuncName
        findOffset currFuncName scopeLevel name


findOffset :: String -> Int -> String -> Evaluator (Maybe Int)
findOffset func scope name =
        if scope == scopeLimit
           then return Nothing
           else do
                   offset <- lookUp func scope name
                   case offset of
                        Nothing  -> findOffset func (pred scope) name
                        Just off -> return (Just off)


lookUp :: String -> Int -> String -> Evaluator (Maybe Int)
lookUp func scope name = do
        progScope <- getProgramScope
        funcScope <- getFunctionScope func progScope
        locScope <- getLocalScope scope funcScope
        return $ getVar name locScope


store :: String -> Int -> Evaluator ()
store name value = do
        currFuncName <- FrameStack.currentFunction
        scopeLevel <- findScope currFuncName
        progScope <- getProgramScope
        funcScope <- getFunctionScope currFuncName progScope
        locScope <- getLocalScope scopeLevel funcScope
        locScope' <- storeVariable name value locScope
        funcScope' <- updateFunctionScope scopeLevel locScope' funcScope
        updateProgramScope currFuncName funcScope'
        return ()



{- ### -}

storeFS :: String -> Int -> Evaluator ()
storeFS name value = do
        currFuncName <- FrameStack.currentFunction
        funcState    <- getFunctionState currFuncName
        let level      = currentScope funcState
            scope      = getScope level funcState
            scope'     = M.insert name value scope
            funcState' = funcState { scopes = M.insert level scope' $ scopes funcState }
        setFunctionState currFuncName funcState'


getScope :: Int -> FuncState -> LocalScope
getScope scope fs =
        case M.lookup scope $ scopes fs of
             Just s  -> s
             Nothing -> error "scope not defined"


{- ### -}


getLocalScope :: Int -> FunctionScope -> Evaluator LocalScope
getLocalScope scopeLevel funcScope = Ev $ \symTab ->
        case M.lookup scopeLevel funcScope of
             Just locScope -> (locScope, symTab)
             Nothing       -> error "No scope defined for function"


getFunctionScope :: String -> ProgramScope -> Evaluator FunctionScope
getFunctionScope funcName progScope = Ev $ \symTab ->
        case M.lookup funcName progScope of
             Just funcScope -> (funcScope, symTab)
             Nothing        -> error "No function scopes defined"


getProgramScope :: Evaluator ProgramScope
getProgramScope = Ev $ \symTab ->
        let scopes = scopesData symTab
            in
        (scopes, symTab)


storeVariable :: String -> Int -> LocalScope -> Evaluator LocalScope
storeVariable varName value locScope =
        let locScope' = M.insert varName value locScope
            in
        return locScope'


updateFunctionScope :: Int -> LocalScope -> FunctionScope -> Evaluator FunctionScope
updateFunctionScope scopeLevel locScope funcScope =
        let funcScope' = M.insert scopeLevel locScope funcScope
            in
        return funcScope'


updateProgramScope :: String -> FunctionScope -> Evaluator ProgramScope
updateProgramScope funcName funcScope = Ev $ \symTab ->
        let scopes = scopesData symTab
            symTab' = symTab { scopesData = M.insert funcName funcScope scopes }
            scopes' = scopesData symTab'
            in
        (scopes', symTab')


getVar :: String -> LocalScope -> Maybe Int
getVar varName varMap =
        case M.lookup varName varMap of
             Just v  -> Just v
             Nothing -> Nothing

-- SCOPE

incrementScope :: Evaluator Int
incrementScope = do
        stepScope succ


decrementScope :: Evaluator Int
decrementScope = do
        stepScope pred


findScope :: String -> Evaluator Int
findScope name = do
        funcState <- getFunctionState name
        return $ currentScope funcState


stepScope :: (Int -> Int) -> Evaluator Int
stepScope f = do
        currFuncName <- FrameStack.currentFunction
        funcState    <- getFunctionState currFuncName
        let newLevel   = f $ currentScope funcState
            funcState' = funcState { currentScope = newLevel }
        setFunctionState currFuncName funcState'
        return newLevel


scopeLimit :: Int
scopeLimit = -1


baseScope :: Int
baseScope = 0


-- FuncState

getFunctionState :: String -> Evaluator FuncState
getFunctionState n = Ev $ \symTab ->
        case M.lookup n $ funcStates symTab of
             Just st -> (st, symTab)
             Nothing -> error $ "No state defined for: " ++ n


setFunctionState :: String -> FuncState -> Evaluator ()
setFunctionState n st = Ev $ \symTab ->
        ((), symTab { funcStates = M.insert n st $ funcStates symTab })


addParam :: String -> FuncState -> FuncState
addParam n st =
        let pos = paramCount st
            st' = st { paramCount = succ pos }
            in
        st' { parameters = M.insert n pos $ parameters st' }


-- OFFSET

currentOffset :: Evaluator Int
currentOffset = Ev $ \symTab -> (offset symTab, symTab)


incrementOffset :: Evaluator ()
incrementOffset = Ev $ \symTab ->
        ((), symTab { offset = (offset symTab) + memOffsetSize })


memOffsetSize :: Int
memOffsetSize = (-8)
