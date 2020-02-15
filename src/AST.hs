
module AST where


import Operator (BinaryOp, Operator, UnaryOp)
import Type     (Type)


data Tree = ProgramNode [Tree]
          | FunctionNode Type String [Tree] (Maybe [Tree]) NodeDat
          | DeclarationNode Tree Type (Maybe Tree) NodeDat
          | PointerNode Tree Type (Maybe Tree) NodeDat
          | ArrayNode ArrayNode
          | CompoundStmtNode [Tree] NodeDat
          | ReturnNode Tree NodeDat
          | AssignmentNode Tree Tree Operator NodeDat
          | AssignDereferenceNode Tree Tree Operator NodeDat
          | ExprStmtNode Tree NodeDat
          | IfNode Tree Tree (Maybe Tree) NodeDat
          | WhileNode Tree Tree NodeDat
          | DoWhileNode Tree Tree NodeDat
          | ForLoopNode Tree Tree Tree Tree NodeDat
          | BreakNode NodeDat
          | ContinueNode NodeDat
          | ConstantNode Int NodeDat
          | FuncCallNode String [Tree] NodeDat
          | ParamNode Type Tree NodeDat
          | ArgNode Tree NodeDat
          | NullExprNode NodeDat
          | VarNode String NodeDat
          | AddressOfNode String NodeDat
          | DereferenceNode String NodeDat
          | UnaryNode Tree UnaryOp NodeDat
          | BinaryNode Tree Tree BinaryOp NodeDat
          | TernaryNode Tree Tree Tree NodeDat
          deriving (Show, Eq)


data ArrayNode = ArrayDeclareNode Int Tree Type (Maybe Tree) NodeDat
               | ArrayAssignNode Tree Tree Operator NodeDat
               | ArrayItemsNode [Tree] NodeDat
               | ArraySingleItemNode Tree NodeDat
               | ArrayVarNode String NodeDat
               deriving (Eq, Show)


data NodeDat = NodeDat { startLine :: Int
                       , endLine   :: Int }
             deriving (Show, Eq)


mkNodeDat :: Int -> Int -> NodeDat
mkNodeDat n m = NodeDat n m
