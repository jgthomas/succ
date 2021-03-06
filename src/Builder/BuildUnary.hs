-- |
-- Module       : BuildUnary
-- Description  : Build assembly for unary ops
--
-- Builds output assembly code for unary operators.
module Builder.BuildUnary
  ( unary,
  )
where

import Builder.BuildVariables (storeVariable)
import Builder.Instruction
  ( Set (..),
    comp,
    dec,
    inc,
    invertBits,
    literal,
    makeNegative,
    move,
    setBitIf,
  )
import Builder.Register (Register (..), reg, scratch)
import Types.Operator
  ( PostOpUnary (..),
    PreOpUnary (..),
    Unary (..),
    UnaryOp (..),
  )
import Types.Variables (VarType (..))

-- | Output asm for unary operators
unary :: UnaryOp -> VarType -> String
unary (PreOpUnary op) var = unaryPreOp op var
unary (PostOpUnary op) var = unaryPostOp op var
unary (Unary op) _ = unaryOp op

unaryPreOp :: PreOpUnary -> VarType -> String
unaryPreOp PreIncrement var@LocalVar {} = inc (reg RAX) <> storeVariable var
unaryPreOp PreDecrement var@LocalVar {} = dec (reg RAX) <> storeVariable var
unaryPreOp _ ParamVar {} = undefined
unaryPreOp PreIncrement var@GlobalVar {} = inc (reg RAX) <> storeVariable var
unaryPreOp PreDecrement var@GlobalVar {} = dec (reg RAX) <> storeVariable var

unaryPostOp :: PostOpUnary -> VarType -> String
unaryPostOp PostIncrement var@LocalVar {} = updateStoredVar var inc
unaryPostOp PostDecrement var@LocalVar {} = updateStoredVar var dec
unaryPostOp _ ParamVar {} = undefined
unaryPostOp PostIncrement var@GlobalVar {} = updateStoredVar var inc
unaryPostOp PostDecrement var@GlobalVar {} = updateStoredVar var dec

updateStoredVar :: VarType -> (String -> String) -> String
updateStoredVar var f =
  move (reg RAX) scratch
    <> f (reg RAX)
    <> storeVariable var
    <> move scratch (reg RAX)

unaryOp :: Unary -> String
unaryOp unOp =
  case unOp of
    Negate -> makeNegative (reg RAX)
    Positive -> mempty
    BitwiseComp -> invertBits (reg RAX)
    LogicalNeg -> logNeg

logNeg :: String
logNeg =
  comp (literal 0) (reg RAX)
    <> move (literal 0) (reg RAX)
    <> setBitIf Equ
