# succ

**S**uper **U**seless **C** **C**ompiler

Compiling a laughably small subset of C to unoptimised assembly since 2019

## what it does

C goes in, x86-64 assembly code comes out

## acknowledgements 

[Nora Sandler](https://norasandler.com/2017/11/29/Write-a-Compiler.html), who broke down compilers in a practical way.

[Bartosz Milewski](https://www.schoolofhaskell.com/user/bartosz/basics-of-haskell/4-symbolic-calculator-recursion), who gave me a glimpse into how this might be done in Haskell.

## supported language elements

**Integer literals**
* Return statements (return 1)

**Unary operators**
* Negation (-)
* Logical negation (!)
* Bitwise complement (~)

**Binary operators**
* Addition (+)
* Subtraction (-)
* Multiplication (*)
* Division (/)
* Modulo (%)
* Equal (==)
* Not equal (!=)
* Greater than (>)
* Less than (<)
* Greater than or equal (>=)
* Less than or equal (<=)
* Logical or (||)
* Logical and (&&)
* Assignment (=, +=, -=, *=, /=, %=)

**Local variables**
* Declaration (int a)
* Assignment (a = 10)
* Declaration and assignment (int a = 10)

**Conditionals**
* if
* else
* conditional expressions (a = 1 ? 2 : 3)

**Loops**
* for
* while
* do while
* break
* continue

**Multiple functions**
* Function calls
* Function declarations
* Function definitions
* Passing parameters using x86-64 calling convention

**Global variables**
* Declaration
* Definition
* Initialized in *.data*
* Uninitialized in *.bss*

**Pointers**
* Declared and defined locally or globally
* Pointing to local or global variables
* Passing as arguments
* Pass without assignment using '&'

**Rudimentary Type Checking**
* int vs. int*
* Check sides of assignments match
* Compare parameters to arguments
* Check function declaration against return values