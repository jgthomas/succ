{-# LANGUAGE DeriveDataTypeable #-}

module Types.Type
  ( Type (..),
    typeSize,
  )
where

import Data.Data (Data)

data Type
  = IntVar
  | IntPointer
  | IntArray Int
  | Label
  deriving (Eq, Data)

instance Show Type where
  show IntVar = "int"
  show IntPointer = "int *"
  show (IntArray n) = "int [] " ++ show n
  show Label = "@label"

typeSize :: Type -> Int
typeSize IntVar = inBytes Bits32
typeSize IntPointer = inBytes Bits64
typeSize (IntArray n) = n * inBytes Bits32
typeSize Label = inBytes Unsized

data SizeBits
  = Bits16
  | Bits32
  | Bits64
  | Unsized
  deriving (Eq)

byteSize :: Int
byteSize = 8

inBytes :: SizeBits -> Int
inBytes Bits16 = 16 `div` byteSize
inBytes Bits32 = 32 `div` byteSize
inBytes Bits64 = 64 `div` byteSize
inBytes Unsized = 0
