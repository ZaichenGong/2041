%{
    open Ast
%}
%token SEMI
%token LCUR
%token RCUR
%token LPAREN
%token RPAREN
%token VAR
%token IF
%token ELSE
%token ASSIGN
%token LET
%token PROVE
%token HINT
%token AXIOM
%token INDUCTION
%token TYPE
%token <string> IDENT 
%token <string> NUM 
%token <string> STRING 
%token EOF
%start main
%type <statement List> main 
%type <statement> statement 
%type <expression> expression 
%type <proof_statement> proof_statement
%type <hint_option> hint_option
%type <type_variant list> type_variants
%% 

main:
stmts = list(statement) ; EOF { stmts }

statement:
// Variable Declaration
| VAR ; var = IDENT ; ASSIGN ; expr = expression SEMI { Declaration (var,expr) }
// Assignment
| var = IDENT ; ASSIGN ; expr = expression SEMI { Assignment (var, expr) }
//Conditional
| IF ; LPAREN ; expr = expression ; RPAREN ; LCUR ; stmts1 = list (statement) ; RCUR ;
    ELSE ; LCUR ; stmts2 = list(statement) ; RCUR { If_Else (expr,stmts1, stmts2) }
| TYPE ; type_name = IDENT ; variants = type_variants { TypeDeclaration (type_name, variants) }
| proof = proof_statement { Proof proof }

expression:
| LPAREN ; expr = expression ; RPAREN { expr }
| str = STRING { String str }
| var = IDENT { Identifier var }
| num = NUM { Number num}
| func = IDENT ; LPAREN ; args = list(expression) ; RPAREN { Function (func, args) }

type_variants:
| LCUR ; variants = list(type_variant) ; RCUR { variants }

type_variant:
| PIPE ; variant = IDENT { TypeVariant (variant, []) }
| PIPE ; variant = IDENT ; LPAREN ; args = list(IDENT, IDENT) ; RPAREN { TypeVariant (variant, args) }

proof_statement:
| LET ; PROVE ; name = IDENT ; LPAREN ; args = list(IDENT) ; RPAREN ; expr = expression ;
    hint = hint_option { Prove (name, args, expr, hint) }
| LET ; AXIOM ; name = IDENT ; LPAREN ; args = list(IDENT) ; RPAREN ; expr = expression { Axiom (name, args, expr) }

hint_option:
| HINT ; AXIOM { AxiomHint }
| HINT ; INDUCTION ; var = IDENT { Induction var }
| /* empty */ { NoHint }


(*
| e = expression ; EOF { [e]}
expression:
| LPAREN ; e = expression ; RPAREN { e }
| nm = IDENT { Identifier nm }
| e1 = expression ; nm = IDENT { Applicaion (e1, Identifier nm)}
| e1 = expression ; LPAREN ; e2 = expression ; RPAREN { Applicaion (e1, e2)}
*)