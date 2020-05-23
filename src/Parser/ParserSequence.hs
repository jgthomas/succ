{-|
Module       : ParserSequence
Description  : Parses repeating sequences

Parses sequences like function arguments.
-}
module Parser.ParserSequence (parseBracketedSeq) where


import Parser.ParState   (ParserState, throwError)
import Parser.TokConsume (consumeTok)
import Types.AST         (Tree)
import Types.Error       (CompilerError (ParserError, SyntaxError),
                          ParserError (..), SyntaxError (..))
import Types.LexDat      (LexDat (..))
import Types.Tokens


-- | Parse a bracketed sequence of elements
parseBracketedSeq :: [Tree]
                  -> [LexDat]
                  -> ([Tree] -> [LexDat] -> ParserState ([Tree], [LexDat]))
                  -> ParserState ([Tree], [LexDat])
parseBracketedSeq _ [] _ = throwError $ ParserError (LexDataError [])
parseBracketedSeq xs lexData@(LexDat{tok=OpenBracket _}:LexDat{tok=CloseBracket _}:_) _ = do
                                      lexData' <- consumeTok lexData
                                      pure (reverse xs, lexData')
parseBracketedSeq xs lexData@(LexDat{tok=CloseBracket _}:_) _ = pure (reverse xs, lexData)
parseBracketedSeq _ (d@LexDat{tok=Comma}:LexDat{tok=CloseBracket _}:_) _ =
        throwError $ SyntaxError (UnexpectedLexDat d)
parseBracketedSeq xs (LexDat{tok=OpenBracket _}:rest) f = f xs rest
parseBracketedSeq xs (LexDat{tok=Comma}:rest) f         = f xs rest
parseBracketedSeq _ (a:_) _ = throwError $ SyntaxError (UnexpectedLexDat a)