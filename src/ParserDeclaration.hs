
module ParserDeclaration (parseValueDec, parsePointerDec) where


import           AST              (Tree (..))
import           Error            (CompilerError (ParserError, SyntaxError),
                                   ParserError (..), SyntaxError (..))
import           LexDat           (LexDat (..))
import           ParserExpression (parseExpression)
import           ParserShared     (consumeNToks, consumeTok, parseType,
                                   verifyAndConsume)
import           ParState         (ParserState, throwError)
import           Tokens           (Token (..))
import qualified Tokens           (isAssign)


parseValueDec :: [LexDat] -> ParserState (Tree, [LexDat])
parseValueDec lexData@(_:LexDat{tok=Ident name}:_) = do
        typ               <- parseType lexData
        lexData'          <- consumeTok lexData
        (tree, lexData'') <- parseOptAssign lexData'
        pure (DeclarationNode name typ tree, lexData'')
parseValueDec (_:c:_:_) = throwError $ SyntaxError (NonValidIdentifier c)
parseValueDec lexData   = throwError $ ParserError (LexDataError lexData)


parsePointerDec :: [LexDat] -> ParserState (Tree, [LexDat])
parsePointerDec lexData@(_:_:LexDat{tok=Ident name}:_) = do
        typ               <- parseType lexData
        lexData'          <- consumeNToks 2 lexData
        (tree, lexData'') <- parseOptAssign lexData'
        pure (PointerNode name typ tree, lexData'')
parsePointerDec (_:_:c:_) = throwError $ SyntaxError (NonValidIdentifier c)
parsePointerDec lexData   = throwError $ ParserError (LexDataError lexData)


parseOptAssign :: [LexDat] -> ParserState (Maybe Tree, [LexDat])
parseOptAssign lexData = do
        (tree, lexData') <- parseOptionalAssign lexData
        lexData''        <- verifyAndConsume SemiColon lexData'
        pure (tree, lexData'')


parseOptionalAssign :: [LexDat] -> ParserState (Maybe Tree, [LexDat])
parseOptionalAssign lexData@(_:d@LexDat{tok=OpTok op}:_)
        | Tokens.isAssign op = do
                (tree, lexData') <- parseExpression lexData
                pure (Just tree, lexData')
        | otherwise = throwError $ SyntaxError (UnexpectedLexDat d)
parseOptionalAssign lexData = do
        lexData' <- consumeTok lexData
        pure (Nothing, lexData')