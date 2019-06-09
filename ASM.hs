
module ASM where


import Tokens     (Operator(..))
import ASM_Tokens (Jump(..))


-- Registers

result  = "%rax"
scratch = "%r12"

allScratch = [scratch]


-- Functions

functionName :: String -> String
functionName f =
        ".globl "
        ++ f
        ++ "\n"
        ++ f
        ++ ":\n"
        ++ saveBasePointer
        ++ saveScratchResisters


returnStatement :: String
returnStatement =
        restoreScratchRegisters
        ++ restoreBasePointer
        ++ ret


saveBasePointer :: String
saveBasePointer = push "%rbp" ++ move "%rsp" "%rbp"


restoreBasePointer :: String
restoreBasePointer = move "%rbp" "%rsp" ++ pop "%rbp"


saveScratchResisters :: String
saveScratchResisters = concat . map push $ allScratch


restoreScratchRegisters :: String
restoreScratchRegisters = concat . map pop . reverse $ allScratch


-- Local variables

loadValue :: Int -> String
loadValue n = move ("$" ++ show n) "%rax"


varOnStack :: Int -> String
varOnStack offset = move "%rax" (show offset ++ "(%rbp)")


varOffStack :: Int -> String
varOffStack offset = move (show offset ++ "(%rbp)") "%rax"


adjustStackPointer :: Int -> String
adjustStackPointer offset =
        "movq %rbp, %rsp\n"
        ++ "subq $" ++ show offset ++ ", %rsp\n"


-- Operators

unary :: Operator -> String
unary o
   | o == Minus         = "neg %rax\n"
   | o == BitwiseCompl  = "not %rax\n"
   | o == LogicNegation = "cmpq $0, %rax\nmovq $0, %rax\nsete %al\n"


binary :: String -> String -> Operator -> String
binary val1 val2 o
   | o == Plus               = compute add val1 val2
   | o == Minus              = compute sub val2 val1
   | o == Multiply           = computeMul val1 val2
   | o == Divide             = computeDiv val1 val2
   | o == Modulo             = computeMod val1 val2
   | o == Equal              = comparison val1 val2 ++ "sete %al\n"
   | o == NotEqual           = comparison val1 val2 ++ "setne %al\n"
   | o == GreaterThan        = comparison val1 val2 ++ "setg %al\n"
   | o == LessThan           = comparison val1 val2 ++ "setl %al\n"
   | o == GreaterThanOrEqual = comparison val1 val2 ++ "setge %al\n"
   | o == LessThanOrEqual    = comparison val1 val2 ++ "setle %al\n"


logicalOR :: String -> String -> Int -> Int -> String
logicalOR load1 load2 nextLabel endLabel =
        load1
        ++ testResult
        ++ emitJump JE nextLabel
        ++ move "$1" "%rax"
        ++ emitJump JMP endLabel
        ++ emitLabel nextLabel
        ++ load2
        ++ testResult
        ++ move "$0" "%rax"
        ++ "setne %al\n"
        ++ emitLabel endLabel


logicalAND :: String -> String -> Int -> Int -> String
logicalAND load1 load2 nextLabel endLabel =
        load1
        ++ testResult
        ++ emitJump JNE nextLabel
        ++ emitJump JMP endLabel
        ++ emitLabel nextLabel
        ++ load2
        ++ testResult
        ++ move "$0" "%rax"
        ++ "setne %al\n"
        ++ emitLabel endLabel


computeMod :: String -> String -> String
computeMod load1 load2 =
        push "%rdx"
        ++ loadValues load2 load1
        ++ "cqto\n"
        ++ "idivq " ++ scratch ++ "\n"
        ++ move "%rdx" "%rax"
        ++ pop "%rdx"


computeDiv :: String -> String -> String
computeDiv load1 load2 =
        push "%rdx"
        ++ loadValues load2 load1
        ++ "cqto\n"
        ++ "idivq " ++ scratch ++ "\n"
        ++ pop "%rdx"


computeMul :: String -> String -> String
computeMul load1 load2 = compute mul load1 load2


compute :: String -> String -> String -> String
compute op load1 load2 =
        loadValues load1 load2
        ++ op ++ scratch ++ ", " ++ result ++ "\n"


loadValues :: String -> String -> String
loadValues load1 load2 =
        load1
        ++ push result
        ++ load2
        ++ pop scratch


comparison :: String -> String -> String
comparison load1 load2 =
        loadValues load1 load2
        ++ "cmpq %rax, " ++ scratch ++ "\n"
        ++ move "$0" "%rax"


testResult :: String
testResult = "cmpq $0, %rax\n"


-- Jumps and labels

emitJump :: Jump -> Int -> String
emitJump j n
        | j == JMP  = "jmp _label_" ++ show n ++ "\n"
        | j == JE   = "je _label_" ++ show n ++ "\n"
        | j == JNE  = "jne _label_" ++ show n ++ "\n"
        | otherwise = error "Unrecognised type of jump"


emitLabel :: Int -> String
emitLabel n = "_label_" ++ show n ++ ":\n"


-- Function calls and registers

makeFunctionCall :: String -> String
makeFunctionCall funcName = "call " ++ funcName ++ "\n"


putInRegister :: String -> String
putInRegister reg = move "%rax" reg


getFromRegister :: String -> String
getFromRegister reg = move reg "%rax"


selectRegister :: Int -> String
selectRegister callConvSeq
        | callConvSeq == 0 = "%rdi"
        | callConvSeq == 1 = "%rsi"
        | callConvSeq == 2 = "%rdx"
        | callConvSeq == 3 = "%rcx"
        | callConvSeq == 4 = "%r8"
        | callConvSeq == 5 = "%r9"


saveCallerRegisters :: String
saveCallerRegisters =
        "pushq %rdi\n"
        ++ "pushq %rsi\n"
        ++ "pushq %rdx\n"
        ++ "pushq %rcx\n"
        ++ "pushq %r8\n"
        ++ "pushq %r9\n"


restoreCallerRegisters :: String
restoreCallerRegisters =
        "popq %r9\n"
        ++ "popq %r8\n"
        ++ "popq %rcx\n"
        ++ "popq %rdx\n"
        ++ "popq %rsi\n"
        ++ "popq %rdi\n"


-- Global variables

initializedGlobal :: String -> String -> String
initializedGlobal label val =
        ".globl " ++ label ++ "\n"
        ++ ".data\n"
        ++ ".align 4\n"
        ++ label ++ ":\n"
        ++ ".long " ++ val ++ "\n"
        ++ ".text\n"


uninitializedGlobal :: String -> String
uninitializedGlobal label =
        ".globl " ++ label ++ "\n"
        ++ ".bss\n"
        ++ ".align 4\n"
        ++ label ++ ":\n"
        ++ ".text\n"


{-
- gcc treats global labels as position
- independent, PIE, by default, and so as
- relative to %rip, so loads need to be
- from that relative location as well
-}
loadGlobal :: String -> String
loadGlobal label = move (label ++ "(%rip)") "%rax"


storeGlobal :: String -> String
storeGlobal label = move "%rax" (label ++ "(%rip)")


-- Pointers

varAddressLoad :: Int -> String
varAddressLoad offset =
        "leaq " ++ show offset ++ "(%rbp), %rax\n"


varAddressStore :: Int -> String
varAddressStore offset = move "%rax" (show offset ++ "(%rbp)")


dereferenceLoad :: Int -> String
dereferenceLoad offset =
        move (show offset ++ "(%rbp)") scratch
        ++ move ("(" ++ scratch ++ ")") "%rax"


dereferenceStore :: Int -> String
dereferenceStore offset =
        move (show offset ++ "(%rbp)") scratch
        ++ move "%rax" ("(" ++ scratch ++ ")")


-- General

noOutput :: String
noOutput = ""


-- Instructions

add = "addq "
sub = "subq "
mul = "imul "
div = "idivq "

ret = "ret\n"

move :: String -> String -> String
move s d = "movq " ++ s ++ ", " ++ d ++ "\n"

push :: String -> String
push s = "pushq " ++ s ++ "\n"

pop :: String -> String
pop s = "popq " ++ s ++ "\n"

