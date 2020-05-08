
module Parser.ParserExpression (parseExpression) where


import           Parser.ParserShared (consumeTok, makeNodeDat,
                                      parseBracketedSeq, verifyAndConsume)
import           Parser.ParState     (ParserState, throwError)
import           Types.AST           (ArrayNode (..), Tree (..))
import           Types.Error         (CompilerError (ImpossibleError, ParserError, SyntaxError),
                                      ParserError (..), SyntaxError (..))
import           Types.LexDat        (LexDat (..))
import qualified Types.Operator      as Operator (tokToAssignOp, tokToBinOp,
                                                  tokToPostUnaryOp,
                                                  tokToUnaryOp)
import           Types.Tokens        (CloseBracket (..), OpTok (..),
                                      OpTokType (..), OpenBracket (..),
                                      Token (..))
import qualified Types.Tokens        as Tokens (isAssign, isPostPos, kind)


parseExpression :: [LexDat] -> ParserState (Tree, [LexDat])
parseExpression lexData = do
        (tree, lexData') <- parseTernaryExp lexData
        case lexData' of
             (d@LexDat{tok=OpTok op}:rest)
                | Tokens.isAssign op  -> parseAssignment tree lexData'
                | Tokens.isPostPos op -> do
                        dat <- makeNodeDat lexData'
                        let unOp = Operator.tokToPostUnaryOp op
                        pure (UnaryNode tree unOp dat, rest)
                | otherwise ->
                        throwError $ SyntaxError (UnexpectedLexDat d)
             _ -> pure (tree, lexData')


parseAssignment :: Tree -> [LexDat] -> ParserState (Tree, [LexDat])
parseAssignment tree (LexDat{tok=OpTok op}:rest) = do
                   (asgn, lexData') <- parseExpression rest
                   let asgnOp = Operator.tokToAssignOp op
                   dat <- makeNodeDat lexData'
                   case tree of
                     arrPosNode@(ArrayNode ArrayItemAssign{}) ->
                             pure (ArrayNode (ArrayAssignPosNode arrPosNode asgn asgnOp dat), lexData')
                     varNode@VarNode{} ->
                             pure (AssignmentNode varNode asgn asgnOp dat, lexData')
                     derefNode@DereferenceNode{} ->
                             pure (AssignDereferenceNode derefNode asgn asgnOp dat, lexData')
                     _ -> throwError $ ParserError (TreeError tree)
parseAssignment _ lexData = throwError $ ParserError (LexDataError lexData)


parseTernaryExp :: [LexDat] -> ParserState (Tree, [LexDat])
parseTernaryExp lexData = do
        dat              <- makeNodeDat lexData
        (cond, lexData') <- parseLogicalOrExp lexData
        case lexData' of
             (LexDat{tok=QuestMark}:rest) -> do
                     (expr1, lexData'')   <- parseExpression rest
                     lexData'''           <- verifyAndConsume Colon lexData''
                     (expr2, lexData'''') <- parseTernaryExp lexData'''
                     pure (TernaryNode cond expr1 expr2 dat, lexData'''')
             _ -> pure (cond, lexData')


parseLogicalOrExp :: [LexDat] -> ParserState (Tree, [LexDat])
parseLogicalOrExp lexData = do
        (orTree, lexData') <- parseLogicalAndExp lexData
        parseBinaryExp orTree lexData' parseLogicalAndExp (Tokens.kind LogicalOR)


parseLogicalAndExp :: [LexDat] -> ParserState (Tree, [LexDat])
parseLogicalAndExp lexData = do
        (andTree, lexData') <- parseBitwiseOR lexData
        parseBinaryExp andTree lexData' parseBitwiseOR (Tokens.kind LogicalAND)


parseBitwiseOR :: [LexDat] -> ParserState (Tree, [LexDat])
parseBitwiseOR lexData = do
        (orTree, lexData') <- parseBitwiseXOR lexData
        parseBinaryExp orTree lexData' parseBitwiseXOR (Tokens.kind BitwiseOR)


parseBitwiseXOR :: [LexDat] -> ParserState (Tree, [LexDat])
parseBitwiseXOR lexData = do
        (xorTree, lexData') <- parseBitwiseAND lexData
        parseBinaryExp xorTree lexData' parseBitwiseAND (Tokens.kind BitwiseXOR)


parseBitwiseAND :: [LexDat] -> ParserState (Tree, [LexDat])
parseBitwiseAND lexData = do
        (andTree, lexData') <- parseEqualityExp lexData
        parseBinaryExp andTree lexData' parseEqualityExp (Tokens.kind BitwiseAND)


parseEqualityExp :: [LexDat] -> ParserState (Tree, [LexDat])
parseEqualityExp lexData = do
        (equTree, lexData') <- parseRelationalExp lexData
        parseBinaryExp equTree lexData' parseRelationalExp (Tokens.kind Equality)


parseRelationalExp :: [LexDat] -> ParserState (Tree, [LexDat])
parseRelationalExp lexData = do
        (relaTree, lexData') <- parseBitShiftExp lexData
        parseBinaryExp relaTree lexData' parseBitShiftExp (Tokens.kind Relational)


parseBitShiftExp :: [LexDat] -> ParserState (Tree, [LexDat])
parseBitShiftExp lexData = do
        (shiftTree, lexData') <- parseAdditiveExp lexData
        parseBinaryExp shiftTree lexData' parseAdditiveExp (Tokens.kind Shift)


parseAdditiveExp :: [LexDat] -> ParserState (Tree, [LexDat])
parseAdditiveExp lexData = do
        (termTree, lexData') <- parseTerm lexData
        parseBinaryExp termTree lexData' parseTerm (Tokens.kind Term)


parseTerm :: [LexDat] -> ParserState (Tree, [LexDat])
parseTerm lexData = do
        (facTree, lexData') <- parseFactor lexData
        parseBinaryExp facTree lexData' parseFactor (Tokens.kind Factor)


parseFactor :: [LexDat] -> ParserState (Tree, [LexDat])
parseFactor [] = throwError $ ParserError (LexDataError [])
parseFactor lexData@(next:rest) =
        case next of
             LexDat{tok=SemiColon}             -> parseNullExpression lexData
             LexDat{tok=ConstInt _}            -> parseConstant lexData
             LexDat{tok=OpTok Ampersand}       -> parseAddressOf lexData
             LexDat{tok=OpTok Asterisk}        -> parseDereference lexData
             LexDat{tok=OpTok MinusSign}       -> parseUnary lexData
             LexDat{tok=OpTok Tilde}           -> parseUnary lexData
             LexDat{tok=OpTok Bang}            -> parseUnary lexData
             LexDat{tok=OpTok PlusPlus}        -> parseUnary lexData
             LexDat{tok=OpTok MinusMinus}      -> parseUnary lexData
             LexDat{tok=OpTok PlusSign}        -> parseUnary lexData
             LexDat{tok=OpenBracket OpenParen} -> parseParenExp rest
             LexDat{tok=Ident _}               -> parseIdent lexData
             _ -> throwError $ ParserError (LexDataError lexData)


parseIdent :: [LexDat] -> ParserState (Tree, [LexDat])
parseIdent lexData@(LexDat{tok=Ident _}:LexDat{tok=OpenBracket OpenParen}:_) =
        parseFuncCall lexData
parseIdent lexData@(LexDat{tok=Ident _}:LexDat{tok=OpenBracket OpenBrace}:_) =
        parseArrayItems lexData
parseIdent lexData@(LexDat{tok=Ident _}:LexDat{tok=OpenBracket OpenSqBracket}:_) =
        parseArrayIndex lexData
parseIdent lexData@(LexDat{tok=Ident a}:rest) = do
        dat <- makeNodeDat lexData
        pure (VarNode a dat, rest)
parseIdent (a:_) = throwError $ SyntaxError (UnexpectedLexDat a)
parseIdent lexData  = throwError $ ParserError (LexDataError lexData)


parseArrayItems :: [LexDat] -> ParserState (Tree, [LexDat])
parseArrayItems lexData@(LexDat{tok=Ident name}:LexDat{tok=OpenBracket OpenBrace}:_) = do
        varDat             <- makeNodeDat lexData
        lexData'           <- consumeTok lexData
        dat                <- makeNodeDat lexData'
        (items, lexData'') <- parseItems [] lexData'
        lexData'''         <- verifyAndConsume (CloseBracket CloseBrace) lexData''
        pure (ArrayNode (ArrayItemsNode (VarNode name varDat) items dat), lexData''')
parseArrayItems lexData = throwError $ ParserError (LexDataError lexData)


parseItems :: [Tree] -> [LexDat] -> ParserState ([Tree], [LexDat])
parseItems items lexData = parseBracketedSeq items lexData parseTheItems


parseTheItems :: [Tree] -> [LexDat] -> ParserState ([Tree], [LexDat])
parseTheItems items lexData = do
        (item, lexData') <- parseItem lexData
        parseItems (item:items) lexData'


parseItem :: [LexDat] -> ParserState (Tree, [LexDat])
parseItem lexData = do
        dat              <- makeNodeDat lexData
        (item, lexData') <- parseExpression lexData
        pure (ArrayNode (ArraySingleItemNode item dat), lexData')


parseNullExpression :: [LexDat] -> ParserState (Tree, [LexDat])
parseNullExpression lexData = do
        dat      <- makeNodeDat lexData
        lexData' <- verifyAndConsume SemiColon lexData
        pure (NullExprNode dat, lexData')


parseConstant :: [LexDat] -> ParserState (Tree, [LexDat])
parseConstant lexData@(LexDat{tok=ConstInt n}:rest) = do
        dat <- makeNodeDat lexData
        pure (ConstantNode n dat, rest)
parseConstant lexData = throwError $ ParserError (LexDataError lexData)


parseUnary :: [LexDat] -> ParserState (Tree, [LexDat])
parseUnary lexData@(LexDat{tok=OpTok op}:rest) = do
        dat              <- makeNodeDat lexData
        (tree, lexData') <- parseFactor rest
        let unOp = Operator.tokToUnaryOp op
        pure (UnaryNode tree unOp dat, lexData')
parseUnary lexData = throwError $ ParserError (LexDataError lexData)


parseArrayIndex :: [LexDat] -> ParserState (Tree, [LexDat])
parseArrayIndex lexData@(LexDat{tok=Ident a}:
                         LexDat{tok=OpenBracket OpenSqBracket}:
                         LexDat{tok=ConstInt n}:
                         LexDat{tok=CloseBracket CloseSqBracket}:
                         oper@LexDat{tok=OpTok _}:rest) = do
        dat <- makeNodeDat lexData
        pure (ArrayNode $ ArrayItemAssign n (VarNode a dat) dat, oper:rest)
parseArrayIndex lexData@(LexDat{tok=Ident a}:
                         LexDat{tok=OpenBracket OpenSqBracket}:
                         LexDat{tok=ConstInt n}:
                         LexDat{tok=CloseBracket CloseSqBracket}:rest) = do
        dat <- makeNodeDat lexData
        pure (ArrayNode $ ArrayItemAccess n (VarNode a dat) dat, rest)
parseArrayIndex lexData = throwError $ ParserError (LexDataError lexData)


parseParenExp :: [LexDat] -> ParserState (Tree, [LexDat])
parseParenExp lexData = do
        (tree, lexData') <- parseExpression lexData
        lexData''        <- verifyAndConsume (CloseBracket CloseParen) lexData'
        pure (tree, lexData'')


parseAddressOf :: [LexDat] -> ParserState (Tree, [LexDat])
parseAddressOf lexData@(LexDat{tok=OpTok Ampersand}:LexDat{tok=Ident n}:rest) = do
        dat <- makeNodeDat lexData
        pure (AddressOfNode n dat, rest)
parseAddressOf (_:a:_)   = throwError $ SyntaxError (NonValidIdentifier a)
parseAddressOf lexData = throwError $ ParserError (LexDataError lexData)


parseDereference :: [LexDat] -> ParserState (Tree, [LexDat])
parseDereference lexData@(LexDat{tok=OpTok Asterisk}:LexDat{tok=Ident n}:rest) = do
        dat <- makeNodeDat lexData
        pure (DereferenceNode n dat, rest)
parseDereference (_:a:_)   = throwError $ SyntaxError (NonValidIdentifier a)
parseDereference lexData = throwError $ ParserError (LexDataError lexData)


parseFuncCall :: [LexDat] -> ParserState (Tree, [LexDat])
parseFuncCall lexData@(LexDat{tok=Ident a}:LexDat{tok=OpenBracket OpenParen}:_) = do
        dat               <- makeNodeDat lexData
        lexData'          <- consumeTok lexData
        (tree, lexData'') <- parseArgs [] lexData'
        lexData'''        <- verifyAndConsume (CloseBracket CloseParen) lexData''
        pure (FuncCallNode a tree dat, lexData''')
parseFuncCall (d@LexDat{tok=Ident _}:_:_) =
        throwError $ SyntaxError (MissingToken (OpenBracket OpenParen) d)
parseFuncCall (a:LexDat{tok=OpenBracket OpenParen}:_) =
        throwError $ SyntaxError (NonValidIdentifier a)
parseFuncCall (a:_:_) =
        throwError $ SyntaxError (UnexpectedLexDat a)
parseFuncCall lexData =
        throwError $ ParserError (LexDataError lexData)


parseArgs :: [Tree] -> [LexDat] -> ParserState ([Tree], [LexDat])
parseArgs args lexData = parseBracketedSeq args lexData parseTheArgs


parseTheArgs :: [Tree] -> [LexDat] -> ParserState ([Tree], [LexDat])
parseTheArgs as lexData = do
        (tree, lexData') <- parseArg lexData
        parseArgs (tree:as) lexData'


parseArg :: [LexDat] -> ParserState (Tree, [LexDat])
parseArg lexData = do
        dat              <- makeNodeDat lexData
        (tree, lexData') <- parseExpression lexData
        pure (ArgNode tree dat, lexData')


parseBinaryExp :: Tree
               -> [LexDat]
               -> ([LexDat] -> ParserState (Tree, [LexDat]))
               -> [OpTok]
               -> ParserState (Tree, [LexDat])
parseBinaryExp _ [] _ _ = throwError $ ParserError (LexDataError [])
parseBinaryExp _ _ _ [] = throwError ImpossibleError
parseBinaryExp tree lexData@(LexDat{tok=OpTok op}:rest) f ops
        | op `elem` ops = do
                dat                <- makeNodeDat lexData
                (ntree, lexData'') <- f rest
                let binOp = Operator.tokToBinOp op
                parseBinaryExp (BinaryNode tree ntree binOp dat) lexData'' f ops
        | otherwise = pure (tree, lexData)
parseBinaryExp tree lexData _ _ = pure (tree, lexData)