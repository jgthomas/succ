{-|
Module       : ComputeExpression
Description  : Computes expression values

Computes the values of expression schemas
-}
module Compute.ComputeExpression where


import Types.Operator


-- | Matches binary operator to Haskell function
binaryFunction :: Integral a => BinaryOp -> (a -> a -> a)
binaryFunction Plus     = (+)
binaryFunction Minus    = (-)
binaryFunction Multiply = (*)
binaryFunction Divide   = quot
binaryFunction Modulo   = mod
binaryFunction _        = undefined