
module LexerSpec (lexerTest) where


import Data.Either
import Test.Hspec

import Error
import Lexer
import Tokens


lexerTest :: IO ()
lexerTest = hspec $ do
        describe "Lex string into tokens" $ do
                it "Should correctly lex all separator characters" $
                  concatMap (fromRight [] . tokenize) ["(",
                                                       ")",
                                                       "{",
                                                       "}",
                                                       ";",
                                                       ":",
                                                       "?",
                                                       ","]
                  `shouldBe` [OpenParen,
                              CloseParen,
                              OpenBrace,
                              CloseBrace,
                              SemiColon,
                              Colon,
                              QuestMark,
                              Comma]


                it "Should correctly lex all language keywords" $
                  concatMap (fromRight [] . tokenize) ["int",
                                                       "return",
                                                       "if",
                                                       "else",
                                                       "for",
                                                       "while",
                                                       "do",
                                                       "break",
                                                       "continue"]
                  `shouldBe` [Keyword Int,
                              Keyword Return,
                              Keyword If,
                              Keyword Else,
                              Keyword For,
                              Keyword While,
                              Keyword Do,
                              Keyword Break,
                              Keyword Continue]


                it "simple token of a single variable" $
                  fromRight [] (tokenize "int a;") `shouldBe` [Keyword Int,Ident "a",SemiColon]

                it "should be a two-character operator then a single one I" $
                  fromRight [] (tokenize "+=+") `shouldBe` [OpTok PlusEqual,OpTok PlusSign]

                it "should be a two character operator then a single one II" $
                  fromRight [] (tokenize "+==") `shouldBe` [OpTok PlusEqual,OpTok EqualSign]

                it "should be two of the SAME two-character operators" $
                  fromRight [] (tokenize "+=+=") `shouldBe` [OpTok PlusEqual,OpTok PlusEqual]

                it "should throw error for unrecognised character" $
                  fromLeft ImpossibleError (tokenize "$") `shouldBe` LexerError (BadInput "$")

                it "should throw error for empty input" $
                  fromLeft ImpossibleError (tokenize "") `shouldBe` LexerError EmptyInput

                it "should lex the caret operator" $
                  fromRight [] (tokenize "^") `shouldBe` [OpTok Caret]
