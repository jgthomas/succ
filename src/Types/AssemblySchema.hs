
module Types.AssemblySchema where


data AssemblySchema = ProgramSchema [AssemblySchema]
                    | FunctionSchema [StatementSchema]
                    | DeclarationSchema ExpressionSchema (Maybe ExpressionSchema)
                    | StatementSchema StatementSchema
                    | ExpressionSchema ExpressionSchema
                    deriving (Eq, Show)


data StatementSchema = IfSchema
                     | ForSchema
                     | WhileSchema
                     | DoWhileSchema
                     | ReturnSchema ExpressionSchema
                     deriving (Eq, Show)


data ExpressionSchema = Literal Int
                      | Variable String
                      | Unary
                      | Binary
                      | Ternary
                      deriving (Eq, Show)
