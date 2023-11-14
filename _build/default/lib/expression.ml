include Ast
module Parser = Parser
module Lexer = Lexer

let parse (s : string) : statement list =
  let lexbuf = Lexing.from_string s in
  let ast = Parser.main Lexer.token lexbuf in
    ast

let string_of_expression (e : expression) : string =
  match e with
  | Identifier v -> v
  | Number n -> string_of_int n
  | String str -> "\"" ^ str ^ "\""
  | Function(func, args) -> func ^ "(" ^ String.concat ", " (List.map string_of_expression args) ^ ")"
  | Equation(e1, e2) -> string_of_expression e1 ^ " = " ^ string_of_expression e2


let rec string_of_statements ntabs (es : statement list) : string = 
  List.fold_left (fun acc stmt -> acc ^ string_of_statement ntabs stmt ^ "\n") "" es

and string_of_statement (ntabs : int) (stmt : statement) : string =
  let tabs = String.make ntabs '\t'
  in match stmt with
    | Declaration (var, expr) -> tabs ^ "var " ^ var ^ " = " ^ string_of_expression expr
    | Assignment (var, expr) -> tabs ^ var ^ " = " ^ string_of_expression expr
    | If_Else (expr, thenS, elseS) ->
      tabs ^ "if (" ^ string_of_expression expr ^ ") {\n" ^
      string_of_statements (ntabs + 1) thenS ^
      tabs ^ "} else {\n" ^
      string_of_statements (ntabs + 1) elseS ^
      tabs ^ "}"
    | TypeDeclaration (name, variants) -> tabs ^ "type " ^ name ^ " = " ^ string_of_type_variants variants
    | Proof (proof) -> tabs ^ string_of_proof proof

and string_of_type_variants (variants : type_variant list) : string =
  String.concat " | " (List.map string_of_type_variant variants)
    
and string_of_type_variant (variant : type_variant) : string =
  match variant with
  | TypeVariant (name, []) -> name
  | TypeVariant (name, args) -> name ^ " of " ^ String.concat " * " (List.map (fun (t, n) -> t ^ " " ^ n) args)
    
and string_of_proof (proof : proof_statement) : string =
  match proof with
  | Prove (name, expr, hint) -> "prove " ^ name ^ " = " ^ string_of_expression expr ^ string_of_hint hint
  | Axiom (name, expr) -> "axiom " ^ name ^ " = " ^ string_of_expression expr
    
and string_of_hint (hint : hint_option) : string =
  match hint with
  | NoHint -> ""
  | Hint h -> " (*hint: " ^ string_of_hint_type h ^ "*)"
    
and string_of_hint_type (hint : hint_type) : string =
  match hint with
  | AxiomHint -> "axiom"
  | Induction var -> "induction " ^ var
    
let string_of_program (es : statement list) : string = 
  string_of_statements 0 es


(*
  | Application (e1, e2) ->
    (string_of_expression e1)^ " " ^(string_of_expression_with_parens e2)
and string_of_expression_with_parens e
  = match e with
  | Identifier nm -> nm
  | Application (e1, e2) -> "(" ^ (string_of_expression e) ^ ")"

let rec string_of_pattern (p : pattern) : string =
  match p with
  | Constructor (name, []) -> name
  | Constructor (name, patterns) -> name ^ " (" ^ (String.concat ", " (List.map string_of_pattern patterns)) ^ ")"
  (* ... of course, this part will depend on what your datatypes look like. *)
*)