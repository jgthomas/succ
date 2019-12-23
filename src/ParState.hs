{-|
Module       : ParState
Description  : State for the parser

State holder for the parsing stage of compilation.
-}
module ParState
        (ParserState,
         runParState,
         throwError,
         getState,
         putState,
         startState
        ) where


import           AST       (Tree (ProgramNode))
import           Error     (CompilerError (ImpossibleError))
import           SuccState (SuccStateM, throwError)
import qualified SuccState (getState, putState, runSuccState)


-- | State definition
type ParserState = SuccStateM Tree


-- | State constructor
startState :: Tree
startState = ProgramNode []


-- | Run the state extracting the error or result
runParState :: (t -> SuccStateM s a) -> t -> s -> Either CompilerError a
runParState f t s = SuccState.runSuccState f t s


-- | Get the state
getState :: ParserState [Tree]
getState = do
        ast <- SuccState.getState
        getTreeList ast


-- | Update the state
putState :: s -> SuccStateM s ()
putState s = SuccState.putState s


getTreeList :: Tree -> ParserState [Tree]
getTreeList (ProgramNode treeList) = pure treeList
getTreeList _                      = throwError ImpossibleError
