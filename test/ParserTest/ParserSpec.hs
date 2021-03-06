module ParserTest.ParserSpec
  ( spec,
  )
where

import ParserTest.TestUtility (extractFullProgramError, extractFullProgramTree)
import Test.Hspec
import TestUtility (mockNodeDat)
import Types.AST
import Types.Error
import Types.Operator
import Types.Tokens
import Types.Type

spec :: Spec
spec = do
  describe "Build abstract syntax trees for full programs" $ do
    it "Should build a tree for a simple program returning a constant" $
      ( extractFullProgramTree
          [ Keyword Int dummyLexDat,
            Ident "main" dummyLexDat,
            OpenBracket OpenParen dummyLexDat,
            CloseBracket CloseParen dummyLexDat,
            OpenBracket OpenBrace dummyLexDat,
            Keyword Return dummyLexDat,
            ConstInt 2 dummyLexDat,
            Separator SemiColon dummyLexDat,
            CloseBracket CloseBrace dummyLexDat
          ]
      )
        `shouldBe` ProgramNode
          [ FunctionNode
              IntVar
              "main"
              []
              ( Just $
                  CompoundStmtNode
                    [ ReturnNode
                        (ConstantNode 2 mockNodeDat)
                        mockNodeDat
                    ]
                    mockNodeDat
              )
              mockNodeDat
          ]
    it "Should build a tree for a program with two functions" $
      ( extractFullProgramTree
          [ Keyword Int dummyLexDat,
            Ident "dog" dummyLexDat,
            OpenBracket OpenParen dummyLexDat,
            CloseBracket CloseParen dummyLexDat,
            OpenBracket OpenBrace dummyLexDat,
            Keyword Return dummyLexDat,
            ConstInt 2 dummyLexDat,
            Separator SemiColon dummyLexDat,
            CloseBracket CloseBrace dummyLexDat,
            Keyword Int dummyLexDat,
            Ident "main" dummyLexDat,
            OpenBracket OpenParen dummyLexDat,
            CloseBracket CloseParen dummyLexDat,
            OpenBracket OpenBrace dummyLexDat,
            Keyword Return dummyLexDat,
            Ident "dog" dummyLexDat,
            OpenBracket OpenParen dummyLexDat,
            CloseBracket CloseParen dummyLexDat,
            Separator SemiColon dummyLexDat,
            CloseBracket CloseBrace dummyLexDat
          ]
      )
        `shouldBe` ProgramNode
          [ FunctionNode
              IntVar
              "dog"
              []
              ( Just $
                  CompoundStmtNode
                    [ ReturnNode
                        ( ConstantNode
                            2
                            mockNodeDat
                        )
                        mockNodeDat
                    ]
                    mockNodeDat
              )
              mockNodeDat,
            FunctionNode
              IntVar
              "main"
              []
              ( Just $
                  CompoundStmtNode
                    [ ReturnNode
                        ( FuncCallNode
                            "dog"
                            []
                            mockNodeDat
                        )
                        mockNodeDat
                    ]
                    mockNodeDat
              )
              mockNodeDat
          ]
    it "Should build a tree for a program with a global variable and a function" $
      ( extractFullProgramTree
          [ Keyword Int dummyLexDat,
            Ident "a" dummyLexDat,
            OpTok EqualSign dummyLexDat,
            ConstInt 2 dummyLexDat,
            Separator SemiColon dummyLexDat,
            Keyword Int dummyLexDat,
            Ident "main" dummyLexDat,
            OpenBracket OpenParen dummyLexDat,
            CloseBracket CloseParen dummyLexDat,
            OpenBracket OpenBrace dummyLexDat,
            Keyword Return dummyLexDat,
            Ident "a" dummyLexDat,
            Separator SemiColon dummyLexDat,
            CloseBracket CloseBrace dummyLexDat
          ]
      )
        `shouldBe` ProgramNode
          [ DeclarationNode
              (VarNode "a" mockNodeDat)
              IntVar
              ( Just
                  ( AssignmentNode
                      (VarNode "a" mockNodeDat)
                      (ConstantNode 2 mockNodeDat)
                      Assignment
                      mockNodeDat
                  )
              )
              mockNodeDat,
            FunctionNode
              IntVar
              "main"
              []
              ( Just $
                  CompoundStmtNode
                    [ ( ReturnNode
                          (VarNode "a" mockNodeDat)
                          mockNodeDat
                      )
                    ]
                    mockNodeDat
              )
              mockNodeDat
          ]
  describe "Throw errors on bad input" $ do
    it "Should throw an error on empty input" $
      (extractFullProgramError [])
        `shouldBe` ParserError (LexDataError [])
    it "Should throw error on junk input" $
      (extractFullProgramError [Keyword Int dummyLexDat])
        `shouldBe` ParserError (LexDataError $ [Keyword Int dummyLexDat])
    it "Should throw an error on invalid top level items" $
      (extractFullProgramError [Separator SemiColon dummyLexDat, OpTok PlusSign dummyLexDat])
        `shouldBe` ParserError (LexDataError $ [Separator SemiColon dummyLexDat, OpTok PlusSign dummyLexDat])
    it "Should throw error on invalid identifier for top level item" $
      ( extractFullProgramError
          [ Keyword Int dummyLexDat,
            Separator SemiColon dummyLexDat,
            OpTok PlusSign dummyLexDat
          ]
      )
        `shouldBe` SyntaxError (NonValidIdentifier $ Separator SemiColon dummyLexDat)
