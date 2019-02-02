

import System.IO
import System.Environment (getArgs)
import System.FilePath (dropExtension)
import System.Process (system)
import Control.Monad (when)
import qualified Data.Map as M

import Lexer (tokenize)
import Parser (parse)
import Generator (genASM)
import SymTab


newSymTab :: SymTab
newSymTab = Tab (-1) 0 (-8) M.empty


main :: IO()
main = do
        --print $ tokenize "int main() { int a = 2; do { a = a + 1; } while (a < 4); return a; }"
        print $ parse $ tokenize "int main() { int a = 2; do { a = a + 1; } while (a < 4); return a; }"
        args <- getArgs
        let infileName = head args
        handle <- openFile infileName ReadMode
        contents <- hGetContents handle

        -- debugging
        --print contents
        --print $ tokenize contents
        --print $ parse $ tokenize contents

        let outfileName = (dropExtension infileName) ++ ".s"
        let parsed = parse $ tokenize contents

        let symTab = newSymTab
            Ev act = genASM parsed
            (asm, symTab') = act symTab
            in do
                    print symTab'
                    when (length asm > 0) $
                       writeFile outfileName asm

        system $ "gcc -g " ++ outfileName ++ " -o " ++ (dropExtension outfileName)
        system $ "rm " ++ outfileName
        hClose handle
