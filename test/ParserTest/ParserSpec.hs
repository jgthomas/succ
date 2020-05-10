
module ParserTest.ParserSpec where


import ParserTest.ParserDeclarationSpec (parserDeclarationTest)
import ParserTest.ParserExpressionSpec  (parserExpressionTest)
import ParserTest.TokClassSpec          (tokClassTest)


parserTest :: IO ()
parserTest = do
        parserExpressionTest
        parserDeclarationTest
        tokClassTest