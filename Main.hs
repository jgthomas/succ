
module Main (main) where


import System.IO
import System.Environment (getArgs)
import System.FilePath (dropExtension)

import Lexer (tokenize)
import Parser (parse)
import Generator


main :: IO()
main = do
        args <- getArgs
        let infileName = head args
        let outfileName = dropExtension infileName
        print infileName
        handle <- openFile infileName ReadMode
        contents <- hGetContents handle
        let tokens = tokenize contents
        print tokens
        let parsedTree = parse tokens
        print parsedTree
        let extractedNodes = generate parsedTree
        print extractedNodes
        let outfileText = progString extractedNodes
        print outfileText
        writeFile outfileName outfileText
        hClose handle
