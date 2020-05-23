{-|
Module       : PrintError
Description  : Output error messages

Create and format error messages with associated code sections
-}
module PrintError.PrintError (handleError) where


import Control.Monad                 (unless)
import Data.Map                      as M (Map, fromList, lookup)
import Data.Maybe                    (fromMaybe, isNothing)
import System.Exit                   (exitFailure)

import Debug.Debug                   (setDebugLevel)
import PrintError.MessageFatalError  (fatalErrorMsg)
import PrintError.MessageOtherError  (impossibleErrorMsg, stateErrorMsg)
import PrintError.MessageScopeError  (scopeErrorMsg)
import PrintError.MessageStageError  (checkerErrorMsg, lexerErrorMsg,
                                      parserErrorMsg)
import PrintError.MessageSyntaxError (syntaxErrorMsg)
import PrintError.MessageTypeError   (typeErrorMsg)
import PrintError.PrintErrorTokens   (PrintRange (..))
import Types.Error                   (CompilerError (..))
import Types.SuccTokens              (Debug (..))


-- | Print any errors and exit compilation process
handleError :: Maybe String -> String -> Either CompilerError a -> IO a
handleError _ _ (Right out) = pure out
handleError debugSet input (Left err)  = do
        printError (setDebugLevel debugSet) input err
        exitFailure


printError :: Debug -> String -> CompilerError -> IO ()
printError DebugOn input err  = printDebugError input err
printError DebugOff input err = printUserError input err


printUserError :: String -> CompilerError -> IO ()
printUserError input err = do
        formatSourcePrint range input
        putStrLn errMsg
        where (errMsg, range) = errorMsg err


printDebugError :: String -> CompilerError -> IO ()
printDebugError input err = do
        formatSourcePrint All input
        print err


formatSourcePrint :: PrintRange -> String -> IO ()
formatSourcePrint range input = do
        putStr "\n"
        printSource range input
        putStr "\n"


printSource :: PrintRange -> String -> IO ()
printSource All input         = printSourceLineRange input 1 (lineCount input)
printSource (Range n m) input = printSourceLineRange input n m
printSource (Exact n) input   = printSourceLine (toLineMap input) n
printSource (From n) input    = printSourceLineRange input n (lineCount input)
printSource (Until n) input   = printSourceLineRange input 1 n
printSource None _            = pure ()


printSourceLineRange :: String -> Int -> Int -> IO ()
printSourceLineRange input n m =
        foldr (>>) (pure ()) $ printSourceLine (toLineMap input) <$> [n..m]


printSourceLine :: M.Map Int String -> Int -> IO ()
printSourceLine lineMap n =
        unless (isNothing sourceLine) $
            putStrLn $ show n ++ "  |  " ++ fromMaybe "" sourceLine
        where sourceLine = M.lookup n lineMap


errorMsg :: CompilerError -> (String, PrintRange)
errorMsg (LexerError err)   = lexerErrorMsg err
errorMsg (ParserError err)  = parserErrorMsg err
errorMsg (StateError err)   = stateErrorMsg err
errorMsg (CheckerError err) = checkerErrorMsg err
errorMsg (SyntaxError err)  = syntaxErrorMsg err
errorMsg (ScopeError err)   = scopeErrorMsg err
errorMsg (TypeError err)    = typeErrorMsg err
errorMsg (FatalError err)   = fatalErrorMsg err
errorMsg ImpossibleError    = impossibleErrorMsg


toLineMap :: String -> M.Map Int String
toLineMap input = M.fromList $ zip [1..] $ lines input


lineCount :: String -> Int
lineCount input = length $ filter (== '\n') input
