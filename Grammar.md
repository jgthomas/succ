## Grammar used by succ

```

<program> ::= { <function> | <declaration> }

<function> ::= <type> <id> "(" [ <parameter-list> ] ")" "{" { <block-item> } "}"
<parameter-list> ::= <parameter> { "," <parameter> }
<parameter> := <type> <id>

<declaration> ::= <type> [ "*" ] <id> [ "=" <exp> ] ";"

<block-item> ::= <declaration> | <statement>
<statement> ::= "return" <exp> ";"
              | "if" "(" <exp> ")" <statement> [ "else" <statement> ]
              | "for" "(" <exp-opt-semicolon> <exp-opt-semicolon> <exp-opt> ")" <statement>
              | "for" "(" <declaration> <exp-opt-semicolon> <exp-opt> ")" <statement>
              | "while" "(" <exp> ")" <statement>
              | "do" <statement> "while" "(" <exp> ")" ";"
              | "break" ";"
              | "continue" ";"
              | <exp-option> ";"
              | "{" { <block-item> } "}"

<exp-opt> ::= <exp> | ""
<exp-opt-semicolon> ::= <exp> ";" | ";"

<exp> ::= [ "*" ] <id> <assign-op> <exp> | <conditional-exp>
<conditional-exp> ::= <logical-or-exp> [ "?" <exp> ":" <conditional-exp> ]
<logical-or-exp> ::= <logical-and-exp> { "||" <logical-and-exp> }
<logical-and-exp> ::= <equality-exp> { "&&" <equality-exp> }
<equality-exp> ::= <relational-exp> { ("==" | "!=") <relational-exp> }
<relational-exp> ::= <additive-exp> { ("<" | ">" | "<=" | ">=") <additive-exp> }
<additive-exp> ::= <term> { ("+" | "-") <term> }
<term> ::= <factor> { ("*" | "/" | "%") <factor> }

<factor> ::= <int>
           | <id>
           | <unary-op> <factor>
           | "(" <exp> ")"
           | <function-call>

<function-call> ::= <id> "(" [ <argument-list> ] ")"
<argument-list> := <argument> { "," <argument> }
<argument> ::= <exp>

<unary-op> ::= "-" | "+" | "~" | "!" | "&" | "*" | "++" | "--"

<assign-op> ::= "=" | "+=" | "-=" | "*=" | "/=" | "%=" | "&=" | "^=" | "|=" | "<<=" | ">>="

<type> ::= <int> | <int*>
```
