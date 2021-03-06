-- |
-- Module       : BuildStatement
-- Description  : Build assembly for statements
--
-- Builds output assembly code for statements.
module Builder.BuildStatement
  ( while,
    doWhile,
    forLoop,
    ifStatement,
    breakStatement,
    continueStatement,
  )
where

import Builder.Directive (emitLabel)
import Builder.Instruction (Jump (..), comp, emitJump, literal, setGotoPoint)
import Builder.Register (Register (..), reg)

-- | Output asm for while loop
while :: String -> String -> Int -> Int -> String
while test body loopLab testLab =
  emitLabel loopLab
    <> test
    <> comp (literal 0) (reg RAX)
    <> emitJump JE testLab
    <> body
    <> emitJump JMP loopLab
    <> emitLabel testLab

-- | Output asm for do while loop
doWhile :: String -> String -> Int -> Int -> Int -> String
doWhile body test loopLab contLab testLab =
  emitLabel loopLab
    <> body
    <> emitLabel contLab
    <> test
    <> comp (literal 0) (reg RAX)
    <> emitJump JE testLab
    <> emitJump JMP loopLab
    <> emitLabel testLab

-- | Output asm for a for loop
forLoop ::
  String ->
  String ->
  String ->
  String ->
  Int ->
  Int ->
  Int ->
  String
forLoop inits test iter body trueLab falseLab contLab =
  inits
    <> emitLabel trueLab
    <> test
    <> comp (literal 0) (reg RAX)
    <> emitJump JE falseLab
    <> body
    <> emitLabel contLab
    <> iter
    <> emitJump JMP trueLab
    <> emitLabel falseLab

-- | Output asm for an if statement
ifStatement ::
  String ->
  String ->
  String ->
  Int ->
  Int ->
  String
ifStatement test body "" n _ = ifOnly test body n
ifStatement test body elseBlock n m = ifElse test body n elseBlock m

-- | Output asm for a break statement
breakStatement :: Int -> String
breakStatement n = setGotoPoint n

-- | Output asm for a continue statement
continueStatement :: Int -> String
continueStatement n = setGotoPoint n

ifOnly :: String -> String -> Int -> String
ifOnly test action testLab =
  ifStart test action testLab
    <> emitLabel testLab

ifElse :: String -> String -> Int -> String -> Int -> String
ifElse test action testLab elseAction nextLab =
  ifStart test action testLab
    <> emitJump JMP nextLab
    <> emitLabel testLab
    <> elseAction
    <> emitLabel nextLab

ifStart :: String -> String -> Int -> String
ifStart test action testLab =
  test
    <> comp (literal 0) (reg RAX)
    <> emitJump JE testLab
    <> action
