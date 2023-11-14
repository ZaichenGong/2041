{
    open Parser
    exception SyntaxError of string
}

let newline = '\r' | '\n' | "\r\n"
let identifier = ['a'-'z' 'A'-'Z'] ['a'-'z' 'A'-'Z' '0'-'9']*
let num = ['0'-'9']+

rule token = parse
    | [' ' '\t'] {token lexbuf}
    | newline { Lexing.new_line lexbuf; token lexbuf }
    | "//" { line_comment lexbuf }
    | ";" {SEMI}
    | "{" {LCUR}
    | "}" {RCUR}
    | "(" {LPAREN}
    | ")" {RPAREN}
    | "=" {ASSIGN}
    | "\"" { stringParse lexbuf }
    | "var" {VAR}
    | "if" {IF}
    | "else" {ELSE}
    | "let" { LET }
    | "prove" { PROVE }
    | "hint" { HINT }
    | "axiom" { AXIOM }
    | "induction" { INDUCTION }
    | "type" { TYPE }
    | identifier as id { IDENT id }
    | num as n { NUM (int_of_string n) }
    | _ { raise (SyntaxError ("Unexpected char: " ^ Lexing.lexeme lexbuf)) }
    | eof { EOF }

and stringParse = parse
    | (['a'-'z' 'A'-'Z' '0'-'9']* as str) "\"" {STRING str}

and line_comment = parse
    | newline { Lexing.new_line lexbuf; token lexbuf }
    | _ { line_comment lexbuf }
    | eof { EOF }
    