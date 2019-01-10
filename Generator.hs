
module Generator (genASM) where


import Lexer (Operator(..))
import Parser (Tree(..))


genASM :: Tree -> String

genASM (ProgramNode tree) = genASM tree

genASM (FunctionNode name tree) = functionName name ++ genASM tree

genASM (ReturnNode tree) = genASM tree ++ returnStatement

genASM (ConstantNode n) = loadValue n

genASM (UnaryNode tree op) = genASM tree ++ unary op

genASM (BinaryNode left right op) = binary (genASM left) (genASM right) op


functionName :: String -> String
functionName f = ".globl " ++ f ++ "\n" ++ f ++ ":\n"

loadValue :: Int -> String
loadValue n = "movq $" ++ (show n) ++ ", %rax\n"

returnStatement :: String
returnStatement = "ret\n"

unary :: Operator -> String
unary o
   | o == Minus         = "neg %rax\n"
   | o == BitwiseCompl  = "not %rax\n"
   | o == LogicNegation = "cmpq $0, %rax\nmovq $0, %rax\nsete %al\n"

binary :: String -> String -> Operator -> String
binary loadVal1 loadVal2 o
   | o == Plus         = loadTwoValues loadVal1 loadVal2 ++ "addq %rcx, %rax\n"
   | o == Multiply     = loadTwoValues loadVal1 loadVal2 ++ "imul %rcx, %rax\n"
   | o == Minus        = loadTwoValues loadVal2 loadVal1 ++ "subq %rcx, %rax\n"
   | o == Divide       = loadVal1 ++ "pushq %rax\n" ++ loadVal2 ++ "movq %rax, %rbx\n"
                         ++ "popq %rax\n" ++ "cqto\n" ++ "idivq %rbx\n"
   | o == Equal        = comparison loadVal1 loadVal2 ++ "sete %al\n"
   | o == NotEqual     = loadVal1 ++ "pushq %rax\n" ++ loadVal2 ++ "popq %rcx\n" ++ "cmpq %rax, %rcx\n"
                         ++ "movq $0, %rax\n" ++ "setne %al\n"
   | o == GreaterThan  = loadVal1 ++ "pushq %rax\n" ++ loadVal2 ++ "popq %rcx\n" ++ "cmpq %rax, %rcx\n"
                         ++ "movq $0, %rax\n" ++ "setg %al\n"
   | o == LessThan     = loadVal1 ++ "pushq %rax\n" ++ loadVal2 ++ "popq %rcx\n" ++ "cmpq %rax, %rcx\n"
                         ++ "movq $0, %rax\n" ++ "setl %al\n"
   | o == GreaterThanOrEqual = loadVal1 ++ "pushq %rax\n" ++ loadVal2 ++ "popq %rcx\n" ++ "cmpq %rax, %rcx\n"
                             ++ "movq $0, %rax\n" ++ "setge %al\n"


loadTwoValues :: String -> String -> String
loadTwoValues loadVal1 loadVal2 = loadVal1
                                  ++ "pushq %rax\n"
                                  ++ loadVal2
                                  ++ "popq %rcx\n"


comparison :: String -> String -> String
comparison loadVal1 loadVal2 = (loadTwoValues loadVal1 loadVal2)
                               ++ "cmpq %rax, %rcx\n"
                               ++ "movq $0, %rax\n"
