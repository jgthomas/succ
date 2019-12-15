{-|
Module       : FrameStack
Description  : Tracks current function

Keeps track of the function currently being compiled.
-}
module FrameStack
        (currentFunction,
         getScope,
         popFunctionName,
         pushFunctionName)
        where


import           GenState  (GenState)
import qualified GenState  (getFrameStack, putFrameStack)
import           GenTokens (Scope (..))
import           Types     (Stack (Stack))


-- | Check if in Local or Global scope
getScope :: GenState Scope
getScope = do
        curr <- currentFunction
        if curr == "global"
           then pure Global
           else pure Local


-- | Return name of the current function being compiled
currentFunction :: GenState String
currentFunction = do
        currFuncName <- stackPeek <$> GenState.getFrameStack
        case currFuncName of
             Nothing   -> pure "global"
             Just name -> pure name


-- | Remove function name from top of stack
popFunctionName :: GenState ()
popFunctionName = do
        stack <- GenState.getFrameStack
        GenState.putFrameStack $ stackPop stack


-- | Add function name to top of stack
pushFunctionName :: String -> GenState ()
pushFunctionName name = do
        stack <- GenState.getFrameStack
        GenState.putFrameStack $ stackPush name stack


stackPeek :: Stack a -> Maybe a
stackPeek (Stack []) = Nothing
stackPeek (Stack s)  = Just $ head s


stackPop :: Stack a -> Stack a
stackPop (Stack []) = Stack []
stackPop (Stack s)  = Stack $ tail s


stackPush :: a -> Stack a -> Stack a
stackPush x (Stack s) = Stack (x:s)
