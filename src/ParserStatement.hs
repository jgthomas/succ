
module ParserStatement (parseStatementBlock) where


import AST               (Tree (..))
import Error             (CompilerError (ParserError, SyntaxError),
                          ParserError (..), SyntaxError (..))
import LexDat            (LexDat (..))
import ParserDeclaration (parsePointerDec, parseValueDec)
import ParserExpression  (parseExpression)
import ParserShared      (nextTokIsNot, verifyAndConsume)
import ParState          (ParserState, throwError)
import Tokens            (Keyword (..), OpTok (..), Token (..))


parseStatementBlock :: [Tree] -> [LexDat] -> ParserState ([Tree], [LexDat])
parseStatementBlock stmts lexData@(LexDat{tok=CloseBrace}:_) = pure (reverse stmts, lexData)
parseStatementBlock stmts lexData = do
        (tree, lexData') <- parseBlockItem lexData
        parseStatementBlock (tree:stmts) lexData'


parseBlockItem :: [LexDat] -> ParserState (Tree, [LexDat])
parseBlockItem lexData@(LexDat{tok=Keyword Int}:LexDat{tok=Ident _}:_) =
        parseValueDec lexData
parseBlockItem lexData@(LexDat{tok=Keyword Int}:LexDat{tok=OpTok Asterisk}:_) =
        parsePointerDec lexData
parseBlockItem lexData = parseStatement lexData


parseStatement :: [LexDat] -> ParserState (Tree, [LexDat])
parseStatement [] = throwError $ ParserError (LexDataError [])
parseStatement lexData@(first:rest) =
        case first of
             LexDat{tok=Keyword Return}   -> parseReturnStmt rest
             LexDat{tok=Keyword If}       -> parseIfStatement rest
             LexDat{tok=Keyword While}    -> parseWhileStatement rest
             LexDat{tok=Keyword Do}       -> parseDoWhile rest
             LexDat{tok=Keyword For}      -> parseForLoop rest
             LexDat{tok=Keyword Break}    -> parseBreak rest
             LexDat{tok=Keyword Continue} -> parseContinue rest
             LexDat{tok=OpenBrace}        -> parseCompoundStmt rest
             _                            -> parseExprStatement lexData


{-
- Parses expressions where a semi-colon is required afterwards
-
- null expression:         ;
- expression statements:   2 + 2;
- elements of loops:       (i = 0; i < 10; i++)
- assignments:             a = 10; *p = 10;
- function calls:          dog(8);
-
-}
parseExprStatement :: [LexDat] -> ParserState (Tree, [LexDat])
parseExprStatement (LexDat{tok=SemiColon}:rest) = parseNullStatement rest
parseExprStatement lexData = do
        (tree, lexData') <- parseExpression lexData
        lexData''        <- verifyAndConsume SemiColon lexData'
        pure (ExprStmtNode tree, lexData'')


parseBreak :: [LexDat] -> ParserState (Tree, [LexDat])
parseBreak (LexDat{tok=SemiColon}:rest) = pure (BreakNode, rest)
parseBreak (d:_) = throwError $ SyntaxError (MissingToken SemiColon d)
parseBreak [] = throwError $ ParserError (LexDataError [])


parseContinue :: [LexDat] -> ParserState (Tree, [LexDat])
parseContinue (LexDat{tok=SemiColon}:rest) = pure (ContinueNode, rest)
parseContinue (d:_) = throwError $ SyntaxError (MissingToken SemiColon d)
parseContinue [] = throwError $ ParserError (LexDataError [])


parseCompoundStmt :: [LexDat] -> ParserState (Tree, [LexDat])
parseCompoundStmt lexData = do
        (items, lexData') <- parseStatementBlock [] lexData
        lexData''         <- verifyAndConsume CloseBrace lexData'
        pure (CompoundStmtNode items, lexData'')


parseForLoop :: [LexDat] -> ParserState (Tree, [LexDat])
parseForLoop lexData = do
        lexData'               <- verifyAndConsume OpenParen lexData
        (ini, lexData'')       <- parseBlockItem lexData'
        (test, lexData''')     <- parseExprStatement lexData''
        (change, lexData'''')  <- parsePostExp lexData'''
        lexData'''''           <- verifyAndConsume CloseParen lexData''''
        (stmts, lexData'''''') <- parseStatement lexData'''''
        if test == NullExprNode
           then pure (ForLoopNode ini (ConstantNode 1) change stmts, lexData'''''')
           else pure (ForLoopNode ini test change stmts, lexData'''''')


parsePostExp :: [LexDat] -> ParserState (Tree, [LexDat])
parsePostExp lexData = do
        (tree, lexData') <- parseForLoopPostExp lexData
        nextTokIsNot SemiColon lexData'
        pure (tree, lexData')


parseForLoopPostExp :: [LexDat] -> ParserState (Tree, [LexDat])
parseForLoopPostExp (d@LexDat{tok=SemiColon}:_) =
        throwError $ SyntaxError (UnexpectedLexDat d)
parseForLoopPostExp lexData@(LexDat{tok=CloseParen}:_) =
        nullExpr lexData
parseForLoopPostExp lexData = parseExpression lexData


parseDoWhile :: [LexDat] -> ParserState (Tree, [LexDat])
parseDoWhile lexData@(LexDat{tok=OpenBrace}:_) = do
        (stmts, lexData') <- parseStatement lexData
        case lexData' of
             (LexDat{tok=Keyword While}:LexDat{tok=OpenParen}:rest) -> do
                     (test, lexData'') <- parseExpression rest
                     lexData'''        <- verifyAndConsume CloseParen lexData''
                     lexData''''       <- verifyAndConsume SemiColon lexData'''
                     pure (DoWhileNode stmts test, lexData'''')
             (_:d@LexDat{tok=OpenParen}:_) ->
                     throwError $ SyntaxError (MissingKeyword While d)
             (d@LexDat{tok=Keyword While}:_:_) ->
                     throwError $ SyntaxError (MissingToken OpenParen d)
             _ -> throwError $ ParserError (LexDataError lexData')
parseDoWhile (d:_) = throwError $ SyntaxError (MissingToken OpenBrace d)
parseDoWhile [] = throwError $ ParserError (LexDataError [])


parseWhileStatement :: [LexDat] -> ParserState (Tree, [LexDat])
parseWhileStatement lexData = do
        (test, lexData')   <- parseConditionalParen lexData
        (stmts, lexData'') <- parseStatement lexData'
        pure (WhileNode test stmts, lexData'')


parseIfStatement :: [LexDat] -> ParserState (Tree, [LexDat])
parseIfStatement lexData = do
        (test, lexData')       <- parseConditionalParen lexData
        (stmts, lexData'')     <- parseStatement lexData'
        (possElse, lexData''') <- parseOptionalElse lexData''
        pure (IfNode test stmts possElse, lexData''')


parseConditionalParen :: [LexDat] -> ParserState (Tree, [LexDat])
parseConditionalParen lexData = do
        lexData'             <- verifyAndConsume OpenParen lexData
        (test, lexData'')    <- parseExpression lexData'
        lexData'''           <- verifyAndConsume CloseParen lexData''
        pure (test, lexData''')


parseOptionalElse :: [LexDat] -> ParserState (Maybe Tree, [LexDat])
parseOptionalElse (LexDat{tok=Keyword Else}:rest) = do
        (tree, lexData') <- parseStatement rest
        pure (Just tree, lexData')
parseOptionalElse lexData = pure (Nothing, lexData)


parseReturnStmt :: [LexDat] -> ParserState (Tree, [LexDat])
parseReturnStmt lexData = do
        (tree, lexData') <- parseExpression lexData
        lexData''        <- verifyAndConsume SemiColon lexData'
        pure (ReturnNode tree, lexData'')


parseNullStatement :: [LexDat] -> ParserState (Tree, [LexDat])
parseNullStatement lexData = pure (NullExprNode, lexData)


nullExpr :: [LexDat] -> ParserState (Tree, [LexDat])
nullExpr lexData = pure (NullExprNode, lexData)