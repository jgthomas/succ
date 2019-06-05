
module Types where


import qualified Data.Map as M
import qualified Data.Set as S


data SymTab = Tab { label       :: Int
                  , offset      :: Int
                  , frameStack  :: Stack String
                  , globalScope :: GlobalScope
                  , funcStates  :: M.Map String FuncState }
            deriving (Show)


newtype Stack a = Stack [a] deriving Show


data GlobalScope = Gscope { seqNum       :: Int
                          , declarations :: M.Map String Int
                          , decParams    :: M.Map String Int
                          , globalVars   :: M.Map String String
                          , declaredVars :: S.Set String }
                 deriving (Show)


data FuncState = Fs { paramCount   :: Int
                    , currentScope :: Int
                    , parameters   :: M.Map String Int
                    , scopes       :: M.Map Int (M.Map String Int) }
               deriving (Show)
