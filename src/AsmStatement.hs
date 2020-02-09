
module AsmStatement
        (while,
         doWhile,
         forLoop,
         ifOnly,
         ifElse
        ) where


import AsmVariables (testResult)
import Assembly     (Jump (..))
import Directive    (emitLabel)
import GenState     (GenState)
import Instruction  (emitJump)


-- | Output asm for while loop
while :: String -> String -> Int -> Int -> GenState String
while test body loopLab testLab = pure $
        emitLabel loopLab
        ++ test
        ++ testResult
        ++ emitJump JE testLab
        ++ body
        ++ emitJump JMP loopLab
        ++ emitLabel testLab


-- | Output asm for do while loop
doWhile :: String -> String -> Int -> Int -> Int -> GenState String
doWhile body test loopLab contLab testLab = pure $
        emitLabel loopLab
        ++ body
        ++ emitLabel contLab
        ++ test
        ++ testResult
        ++ emitJump JE testLab
        ++ emitJump JMP loopLab
        ++ emitLabel testLab


-- | Output asm for a for loop
forLoop :: String
        -> String
        -> String
        -> String
        -> Int
        -> Int
        -> Int
        -> GenState String
forLoop inits test iter body trueLab falseLab contLab = pure $
        inits
        ++ emitLabel trueLab
        ++ test
        ++ testResult
        ++ emitJump JE falseLab
        ++ body
        ++ emitLabel contLab
        ++ iter
        ++ emitJump JMP trueLab
        ++ emitLabel falseLab


-- | Output asm for a simple if statement
ifOnly :: String -> String -> Int -> GenState String
ifOnly test action testLab = pure $
        ifStart test action testLab
        ++ emitLabel testLab


-- | Output asm for an if statement with an else clause
ifElse :: String -> String -> Int -> String -> Int -> GenState String
ifElse test action testLab elseAction nextLab = pure $
        ifStart test action testLab
        ++ emitJump JMP nextLab
        ++ emitLabel testLab
        ++ elseAction
        ++ emitLabel nextLab


ifStart :: String -> String -> Int -> String
ifStart test action testLab =
        test
        ++ testResult
        ++ emitJump JE testLab
        ++ action