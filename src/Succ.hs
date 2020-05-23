{-|
Module       : Succ
Description  : Run compilation process

Controls the output of the compilation process.
-}
module Succ (compile) where


import qualified Checker.Checker       as Checker (check)
import qualified Debug.Debug           as Debug (debug, debugPair)
import qualified Generator.Generator   as Generator (generate)
import qualified Lexer.Lexer           as Lexer (tokenize)
import qualified Parser.Parser         as Parser (parse)
import qualified PrintError.PrintError as PrintError (handleError)
import           Types.SuccTokens      (Stage (..))


-- | Run the compilation process
compile :: String -> Maybe String -> IO String
compile input debugSet = do
        input' <- debugInput . pure $ input
        toks   <- debugLexer . errorHandler . Lexer.tokenize $ input'
        ast    <- debugParser . errorHandler . Parser.parse $ toks
        ast'   <- errorHandler . Checker.check $ ast
        fmap fst . debugOutput . errorHandler . Generator.generate $ ast'
        where
                debugInput   = Debug.debug debugSet Input
                debugLexer   = Debug.debug debugSet Lexer
                debugParser  = Debug.debug debugSet Parser
                debugOutput  = Debug.debugPair debugSet (Output, State)
                errorHandler = PrintError.handleError debugSet input
