
module ParserTest.ParserFunctionSpec (parserFunctionTest) where


import Test.Hspec

import ParserTest.TestUtility (extractFunctionError, extractFunctionTree)
import TestUtility            (makeLexDat, mockNodeDat)
import Types.AST
import Types.Error
import Types.Tokens
import Types.Type


parserFunctionTest :: IO ()
parserFunctionTest = hspec $ do
        describe "Build abstract syntax trees for functions" $ do

                it "Should build a function declaration tree" $
                  (extractFunctionTree [Keyword Int,
                                        Ident "dog",
                                        OpenBracket OpenParen,
                                        CloseBracket CloseParen,
                                        SemiColon
                                       ])
                  `shouldBe`
                  ProgramNode [FunctionNode
                               IntVar
                               "dog"
                               []
                               Nothing
                               mockNodeDat
                              ]

                it "Should build a function definition tree" $
                  (extractFunctionTree [Keyword Int,
                                        Ident "main",
                                        OpenBracket OpenParen,
                                        CloseBracket CloseParen,
                                        OpenBracket OpenBrace,
                                        CloseBracket CloseBrace
                                       ])
                  `shouldBe`
                  ProgramNode [FunctionNode
                               IntVar
                               "main"
                               []
                               (Just [])
                               mockNodeDat]

                it "Should build a function with arguments tree" $
                  (extractFunctionTree [Keyword Int,
                                        Ident "main",
                                        OpenBracket OpenParen,
                                        Keyword Int,
                                        Ident "a",
                                        Comma,
                                        Keyword Int,
                                        Ident "b",
                                        CloseBracket CloseParen,
                                        OpenBracket OpenBrace,
                                        CloseBracket CloseBrace
                                       ])
                  `shouldBe`
                  ProgramNode [FunctionNode
                               IntVar
                               "main"
                               [ParamNode
                                IntVar
                                (VarNode "a" mockNodeDat)
                                mockNodeDat,
                                ParamNode
                                IntVar
                                (VarNode "b" mockNodeDat)
                                mockNodeDat
                               ]
                               (Just [])
                               mockNodeDat]

                it "Should build a function with body statement tree" $
                  (extractFunctionTree [Keyword Int,
                                        Ident "main",
                                        OpenBracket OpenParen,
                                        CloseBracket CloseParen,
                                        OpenBracket OpenBrace,
                                        Keyword Return,
                                        ConstInt 2,
                                        SemiColon,
                                        CloseBracket CloseBrace
                                       ])
                  `shouldBe`
                  ProgramNode [FunctionNode
                               IntVar
                               "main"
                               []
                               (Just
                                [ReturnNode
                                 (ConstantNode 2 mockNodeDat)
                                 mockNodeDat
                                ]
                               )
                               mockNodeDat]

        describe "Throw errors on bad input" $ do

                it "Should throw error on missing function identifier" $
                  (extractFunctionError [Keyword Int,
                                         Comma,
                                         OpenBracket OpenParen,
                                         CloseBracket CloseParen,
                                         OpenBracket OpenBrace,
                                         CloseBracket CloseBrace
                                        ])
                  `shouldBe`
                  SyntaxError (NonValidIdentifier $ makeLexDat (Keyword Int))

                it "Should throw error on unfinished function" $
                  (extractFunctionError [Keyword Int, Ident "a"])
                  `shouldBe`
                  ParserError (LexDataError [(makeLexDat $ Keyword Int), (makeLexDat $ Ident "a")])
