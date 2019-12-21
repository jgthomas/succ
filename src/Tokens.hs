
module Tokens where


data Operator = PlusSign
              | MinusSign
              | Asterisk
              | BackSlash
              | Percent
              | Tilde
              | Bang
              | PipePipe
              | AmpAmp
              | RightArrow
              | RightArrowEquals
              | LeftArrow
              | LeftArrowEquals
              | EqualEqual
              | BangEqual
              | EqualSign
              | PlusEqual
              | MinusEqual
              | AsteriskEqual
              | BackSlashEqual
              | PercentEqual
              deriving (Show, Eq)


unary :: [Operator]
unary = [MinusSign,Tilde,Bang]


data TokenType = Unary
               | LogicalOR
               | LogicalAND
               | Factor
               | Term
               | Assign
               | Equalit
               | Relational
               deriving (Eq)


kind :: TokenType -> [Operator]
kind tokTyp =
        case tokTyp of
             Unary      -> [MinusSign,
                            Tilde,
                            Bang]
             LogicalOR  -> [PipePipe]
             LogicalAND -> [AmpAmp]
             Factor     -> [Asterisk,
                            BackSlash,
                            Percent]
             Term       -> [PlusSign,
                            MinusSign]
             Equalit    -> [EqualEqual,
                            BangEqual]
             Relational -> [RightArrow,
                            LeftArrow,
                            RightArrowEquals,
                            LeftArrowEquals]
             Assign     -> [EqualSign,
                            PlusEqual,
                            MinusEqual,
                            AsteriskEqual,
                            BackSlashEqual,
                            PercentEqual]


data Keyword = Int
             | Return
             | If
             | Else
             | For
             | While
             | Do
             | Break
             | Continue
             deriving (Show, Eq)


data Token = OpenParen
           | CloseParen
           | OpenBrace
           | CloseBrace
           | SemiColon
           | Op Operator
           | Ident String
           | ConstInt Int
           | Keyword Keyword
           | Colon
           | QuestMark
           | Comma
           | Ampersand
           | Wut
           deriving (Show, Eq)
