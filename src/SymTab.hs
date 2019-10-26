
module SymTab (currentScope,
               labelNum,
               newSymTab,
               module GlobalScope,
               module FuncState) where


import qualified Data.Map as M

import Evaluator   (Evaluator(Ev))
import Types       (SymTab(Tab, label))
import FrameStack  (newStack, currentScope)
import GlobalScope hiding (globalType, declaredFuncType)
import FuncState   hiding (allTypes, variableType, parameterType)


newSymTab :: SymTab
newSymTab = Tab
            firstLabel
            newStack
            newGlobalScope
            M.empty


labelNum :: Evaluator Int
labelNum = Ev $ \symTab ->
        (label symTab, symTab { label = succ . label $ symTab })


firstLabel :: Int
firstLabel = 1