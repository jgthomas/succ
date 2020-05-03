
module Error.MessageSyntaxError (syntaxErrorMsg) where


import Error.Error            (SyntaxError (..))
import Error.PrintErrorTokens (PrintRange (..), buildLineMsg, buildTokMsg)
import Lexer.LexTab           (LexDat (..))


syntaxErrorMsg :: SyntaxError -> (String, PrintRange)

syntaxErrorMsg (MissingToken t d) = (msg, mkRange d)
        where msg = unexpectedLexDatMsg d
                    ++ ", Expected "
                    ++ buildTokMsg t

syntaxErrorMsg (BadType d) = (msg, mkRange d)
        where msg = buildLineMsg (line d)
                    ++ "Invalid type "
                    ++ buildTokMsg (tok d)

syntaxErrorMsg (UnexpectedLexDat d) = (msg, mkRange d)
        where msg = unexpectedLexDatMsg d

syntaxErrorMsg (NonValidIdentifier d) = (msg, mkRange d)
        where msg = buildLineMsg (line d)
                    ++ "Invalid identifier "
                    ++ buildTokMsg (tok d)

syntaxErrorMsg (MissingKeyword kwd d) = (msg, mkRange d)
        where msg = buildLineMsg (line d)
                    ++ "Expected keyword " ++ show kwd

syntaxErrorMsg err = (show err, All)


mkRange :: LexDat -> PrintRange
mkRange d = Range (pred . line $ d) (succ . line $ d)


unexpectedLexDatMsg :: LexDat -> String
unexpectedLexDatMsg d =
        buildLineMsg (line d)
        ++ "Unexpected token "
        ++ buildTokMsg (tok d)
