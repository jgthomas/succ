
module ConverterTest.ConverterTestSpec (converterTest) where


import ConverterTest.ConverterArraySpec       (converterArrayTest)
import ConverterTest.ConverterDeclarationSpec (converterDeclarationTest)
import ConverterTest.ConverterErrorSpec       (converterErrorTest)
import ConverterTest.ConverterExpressionSpec  (converterExpressionTest)
import ConverterTest.ConverterFuncCallSpec    (converterFuncCallTest)
import ConverterTest.ConverterPointerSpec     (converterPointerTest)
import ConverterTest.ConverterStatementSpec   (converterStatementTest)


converterTest :: IO ()
converterTest = do
        converterDeclarationTest
        converterExpressionTest
        converterStatementTest
        converterFuncCallTest
        converterPointerTest
        converterArrayTest
        converterErrorTest
