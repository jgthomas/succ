
module ParserTest.ParserExpressionSpec (parserExpressionTest) where


import Test.Hspec

import ParserTest.TestUtility (extractExpressionError, extractExpressionTree)
import TestUtility            (mockNodeDat)
import Types.AST
import Types.Error
import Types.Operator
import Types.Tokens


parserExpressionTest :: IO ()
parserExpressionTest = hspec $ do
        describe "Build abstract syntax trees for expressions" $ do

                it "Should build a constant tree" $
                  (extractExpressionTree [ConstInt 3])
                  `shouldBe`
                  ProgramNode [ConstantNode 3 mockNodeDat]

                it "Should build a variable tree" $
                  (extractExpressionTree [Ident "a"])
                  `shouldBe`
                  ProgramNode [VarNode "a" mockNodeDat]

                it "Should build basic assignment tree" $
                  (extractExpressionTree [Ident "a", OpTok EqualSign, ConstInt 2])
                  `shouldBe`
                  ProgramNode [AssignmentNode
                               (VarNode "a" mockNodeDat)
                               (ConstantNode 2 mockNodeDat)
                               Assignment
                               mockNodeDat]

                it "Should build unary operator tree" $
                  (extractExpressionTree [OpTok MinusSign, Ident "a"])
                  `shouldBe`
                  ProgramNode [UnaryNode
                               (VarNode "a" mockNodeDat)
                               (Unary Negate)
                               mockNodeDat]

                it "Should build a binary plus operator tree" $
                  (extractExpressionTree [Ident "a", OpTok PlusSign, ConstInt 2])
                  `shouldBe`
                  ProgramNode [BinaryNode
                               (VarNode "a" mockNodeDat)
                               (ConstantNode 2 mockNodeDat)
                               Plus
                               mockNodeDat]

                it "Should build a binary minus operator tree" $
                  (extractExpressionTree [Ident "a", OpTok MinusSign, ConstInt 2])
                  `shouldBe`
                  ProgramNode [BinaryNode
                               (VarNode "a" mockNodeDat)
                               (ConstantNode 2 mockNodeDat)
                               Minus
                               mockNodeDat]

                it "Should build a binary divide operator tree" $
                  (extractExpressionTree [Ident "a", OpTok Backslash, ConstInt 2])
                  `shouldBe`
                  ProgramNode [BinaryNode
                               (VarNode "a" mockNodeDat)
                               (ConstantNode 2 mockNodeDat)
                               Divide
                               mockNodeDat]

                it "Should build a binary multiply operator tree" $
                  (extractExpressionTree [Ident "a", OpTok Asterisk, ConstInt 2])
                  `shouldBe`
                  ProgramNode [BinaryNode
                               (VarNode "a" mockNodeDat)
                               (ConstantNode 2 mockNodeDat)
                               Multiply
                               mockNodeDat]

                it "Should build a ternary operator tree" $
                  (extractExpressionTree [ConstInt 2,
                                          OpTok EqualEqual,
                                          ConstInt 2,
                                          QuestMark,
                                          ConstInt 10,
                                          Colon,
                                          ConstInt 6,
                                          SemiColon
                                         ]
                  )
                  `shouldBe`
                  ProgramNode [TernaryNode
                               (BinaryNode
                                (ConstantNode 2 mockNodeDat)
                                (ConstantNode 2 mockNodeDat)
                                Equal
                                mockNodeDat
                               )
                               (ConstantNode 10 mockNodeDat)
                               (ConstantNode 6 mockNodeDat)
                               mockNodeDat
                              ]

                it "Should build a simple function call tree" $
                  (extractExpressionTree [Ident "dog", OpenBracket OpenParen, CloseBracket CloseParen])
                  `shouldBe`
                  ProgramNode [FuncCallNode "dog" [] mockNodeDat]

                it "Should build a function call node with arguments tree" $
                  (extractExpressionTree [Ident "cat",
                                          OpenBracket OpenParen,
                                          ConstInt 3,
                                          Comma,
                                          ConstInt 4,
                                          CloseBracket CloseParen
                                         ])
                  `shouldBe`
                  ProgramNode [FuncCallNode "cat"
                               [ArgNode (ConstantNode 3 mockNodeDat) mockNodeDat,
                                ArgNode (ConstantNode 4 mockNodeDat) mockNodeDat
                               ]
                               mockNodeDat]

                it "Should build a pointer dereference tree" $
                  (extractExpressionTree [OpTok Asterisk, Ident "b"])
                  `shouldBe`
                  ProgramNode [DereferenceNode "b" mockNodeDat]

        describe "Throw errors on bad input" $ do

                it "Should throw error on empty input" $
                  (extractExpressionError [])
                  `shouldBe`
                  ParserError (LexDataError [])

