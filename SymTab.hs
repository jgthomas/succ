
module SymTab (addVariable,
               closeFunction,
               currentScope,
               initFunction,
               labelNum,
               newSymTab,
               stackPointerValue,
               module Declarations,
               module FunctionState,
               module Scope) where


import qualified Data.Map as M

import Declarations
import FunctionState
import Scope
import Evaluator     (Evaluator(Ev))
import Types         (SymTab(Tab, labelNo, offset))
import SimpleStack   (newStack,
                      currentFunction,
                      currentScope,
                      popFunctionName,
                      pushFunctionName)


{- API -}

newSymTab :: SymTab
newSymTab = Tab
            firstLabel
            memOffsetSize
            newStack
            newDecTable
            M.empty
            M.empty
            M.empty


initFunction :: String -> Evaluator ()
initFunction name = do
        pushFunctionName name
        newScopeRecord name
        newFuncScopesData name
        newFuncState name
        return ()


closeFunction :: Evaluator Bool
closeFunction = do
        popFunctionName


stackPointerValue :: Evaluator Int
stackPointerValue = do
        currOff <- currentOffset
        return $ negate currOff


addVariable :: String -> Evaluator Int
addVariable varName = do
        currOff <- currentOffset
        storeVar varName currOff
        incrementOffset currOff


labelNum :: Evaluator Int
labelNum = do
        nextLabel


{- Internal -}

currentOffset :: Evaluator Int
currentOffset = Ev $ \symTab ->
        let currOff = offset symTab
            in
        (currOff, symTab)


incrementOffset :: Int -> Evaluator Int
incrementOffset currOff = Ev $ \symTab ->
        let symTab' = symTab { offset = currOff + memOffsetSize }
            in
        (currOff, symTab')


nextLabel :: Evaluator Int
nextLabel = Ev $ \symTab ->
        let num = labelNo symTab
            symTab' = symTab { labelNo = succ num }
            in
        (num, symTab')


memOffsetSize :: Int
memOffsetSize = (-8)


firstLabel :: Int
firstLabel = 1
