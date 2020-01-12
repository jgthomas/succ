
module Checker (check) where


import           AST      (Tree)
import           Error    (CompilerError)
import           GenState (GenState, runGenState)
import qualified GenState (startState)


check :: Tree -> Either CompilerError Tree
check ast = runGenState checkAST ast GenState.startState


checkAST :: Tree -> GenState Tree
checkAST ast = pure ast