
module NewOps where


import Tokens


data Oper = UnaryOp UnaryOp
          | BinaryOp BinaryOp
          deriving (Show, Eq)


data BinaryOp = Add
              | Sub
              | Div
              | Mul
              | Mod
              | Equality
              | NotEqu
              | GrThan
              | LeThan
              | GrThanOrEqu
              | LeThanOrEqu
              | Assignment
              | LogicOR
              | LogicAND
              deriving (Show, Eq)


data UnaryOp = Negative
             | BitComp
             | LogicNeg
             deriving (Show, Eq)


tokToBinOp :: Operator -> BinaryOp
tokToBinOp tok =
        case tok of
             PlusSign         -> Add
             MinusSign        -> Sub
             BackSlash        -> Div
             Asterisk         -> Mul
             Percent          -> Mod
             EqualEqual       -> Equality
             BangEqual        -> NotEqu
             RightArrow       -> GrThan
             LeftArrow        -> LeThan
             RightArrowEquals -> GrThanOrEqu
             LeftArrowEquals  -> LeThanOrEqu
             EqualSign        -> Assignment
             PipePipe         -> LogicOR
             AmpAmp           -> LogicAND
             PlusEqual        -> Add
             MinusEqual       -> Sub
             AsteriskEqual    -> Mul
             BackSlashEqual   -> Div
             PercentEqual     -> Mod
             _                -> undefined


tokToUnaryOp :: Operator -> UnaryOp
tokToUnaryOp tok =
        case tok of
             Bang      -> LogicNeg
             MinusSign -> Negative
             Tilde     -> BitComp
             _         -> undefined