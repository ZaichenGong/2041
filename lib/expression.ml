include Ast
module Parser = Parser
module Lexer = Lexer

module Substitution = struct
  module MM = Map.Make(String)
  type 'a t = 'a MM.t
  
  let empty : 'a t = MM.empty
  
  let singleton (key : string) (value : 'a) : 'a t =
    MM.singleton key value

  let merge (s1 : 'a t) (s2 : 'a t) : 'a t option =
    let merged_map = MM.merge (fun _key v1_opt v2_opt ->
        match v1_opt, v2_opt with
        | Some _, Some v2 -> Some v2
        | Some v1, None | None, Some v1 -> Some v1
        | None, None -> None
      ) s1 s2
    in
    if MM.is_empty merged_map 
    then None
    else Some merged_map

  let find (key : string) (s : 'a t) : 'a =
    MM.find key s
end

let parse (s : string) : declaration list =
  let lexbuf = Lexing.from_string s in
    let ast = Parser.main Lexer.token lexbuf in
    ast

let rec string_of_pattern (p : pattern) : string =
  match p with
  | Constructor (name, []) -> name
  | Constructor (name, patterns) -> name ^ " (" ^ (String.concat ", " (List.map string_of_pattern patterns)) ^ ")"
  | Variable (name, type_name) -> name ^ " : " ^ type_name

let rec string_of_expression (e : expression) : string =
  match e with
  | Application (Application (Identifier ",", e), arg) ->
    (string_of_expression e) ^ ", " ^ (string_of_expression arg)
  | Application (e, arg) ->
    (string_of_expression e) ^ " " ^ string_of_expression_paren arg
  | Identifier name -> name
  | Match (e, cases) ->
    let case_strings = List.map (fun (pattern, body) ->
      let pattern_string = match pattern with
        | Constructor (name, []) -> name
        | Constructor (name, patterns) -> name ^ " (" ^ (String.concat ", " (List.map string_of_pattern patterns)) ^ ")"
        | Variable (name, type_name) -> name ^ " : " ^ type_name
      in
      (* the outer parentheses are redundant if the body does not end in a match, but better to be safe then sorry *)
      pattern_string ^ " -> " ^ (string_of_expression_paren body)
    ) cases in
    "match " ^ (string_of_expression e) ^ " with " ^ (String.concat " | " case_strings)

and string_of_expression_paren (e : expression) : string =
  match e with
  | Identifier name -> name
  | e -> "(" ^ string_of_expression e ^ ")"

let string_of_hint (h : hint option) : string =
  match h with
  | Some Axiom -> "\n(*hint: axiom *)"
  | Some (Induction name) -> "\n(*hint: induction " ^ name ^ " *)"
  | None -> ""

let string_of_equality (e : equality) : string =
  match e with
  | Equality (e1, e2) -> "(" ^ (string_of_expression e1) ^ " = " ^ (string_of_expression e2) ^ ")"

let string_of_typedvariable (TypedVariable (name, type_name) : typedVariable) : string =
  "(" ^ name ^ " : " ^ type_name ^ ")"

let string_of_declaration (d : declaration) : string =
  match d with
  | TypeDeclaration (name, variants) ->
    let variant_strings = List.map (function Variant (name, []) -> name
      | Variant (name, types) -> name ^ " of (" ^ (String.concat "*" types) ^ ")"
    ) variants in
    "type " ^ name ^ " = " ^ (String.concat " | " variant_strings)
  | FunctionDeclaration (TypedVariable (name, type_name), args, body) ->
    let arg_strings = List.map (function TypedVariable (name, type_name) -> "(" ^ name ^ " : " ^ type_name ^ ")") args in
    "let rec " ^ name ^ " " ^ (String.concat " " arg_strings) ^ " : " ^ type_name ^ " = " ^ (string_of_expression body)
  | ProofDeclaration (name, args, equality, hint) ->
    let arg_strings = List.map string_of_typedvariable args in
    "let (*prove*) " ^ name ^ " " ^ (String.concat " " arg_strings) ^ " = "
     ^ string_of_equality equality ^ string_of_hint hint


let rec produce_proof (eq : equality) (eq_list : (string * string list * equality) list) : string list =
  match eq with
  | Equality (lhs, rhs) ->
    let lhs_steps = perform_steps lhs eq_list in
    let rhs_steps = perform_steps rhs eq_list in
    let proof_steps = List.map2 (fun (name, lhs_step) (_, rhs_step) ->
      Printf.sprintf "%s\n= {%s}\n%s" lhs_step name rhs_step) lhs_steps rhs_steps in
    proof_steps @ ["(* Insert ??? if lhs and rhs stay different *)"]

and perform_steps (expr : expression) (eq_list : (string * string list * equality) list) : (string * string) list =
  let rec helper expr steps =
    match try_equalities expr eq_list with
    | Some (name, new_expr) -> helper new_expr ((name, string_of_expression new_expr) :: steps)
    | None -> List.rev steps
  in
  helper expr []

and try_equalities (expr : expression) (eq_list : (string * string list * equality) list) : (string * expression) option =
  List.fold_left (fun acc (name, vars, eq) ->
    match acc with
    | Some _ -> acc
    | None ->
      match attempt_rewrite vars eq expr with
      | Some new_expr -> Some (name, new_expr)
      | None -> None) None eq_list

and attempt_rewrite (vars : string list) (eq : equality) (expr : expression) : expression option =
  match expr, eq with
  | _, Equality (lhs, _) ->
    (* Attempt to match lhs with the expression *)
    match match_expressions vars lhs expr with
    | Some matching_expr -> Some matching_expr
    | None ->
      (* If no direct match, recursively attempt rewrite on subexpressions *)
      (match expr with
      | Application (fn, arg) ->
        (match attempt_rewrite vars eq arg with
        | Some rewritten_arg -> Some (Application (fn, rewritten_arg))
        | None -> None)
      | _ -> None)

and match_expressions (variables : string list) (pattern : expression) (expr : expression) : expression option =
  match pattern, expr with
  | Identifier var, _ when List.mem var variables -> Some expr
  | Application (p1, p2), Application (e1, e2) ->
    (match match_expressions variables p1 e1, match_expressions variables p2 e2 with
    | Some matched_p1, Some matched_p2 -> Some (Application (matched_p1, matched_p2))
    | _ -> None)
  | _ -> None

let produce_output_simple (declarations : declaration list) : string =
  let rec helper acc eq_list = function
    | [] -> acc
    | ProofDeclaration (name, args, equality, hint) :: rest ->
      let proof_statement =
        match hint with
        | Some Axiom -> string_of_declaration (ProofDeclaration (name, args, equality, hint))
        | None ->
          let proof_steps = produce_proof equality eq_list in
          let proof_str = String.concat "\n" proof_steps in
          string_of_declaration (ProofDeclaration (name, args, equality, hint)) ^ "\n" ^ proof_str
      in
      let new_eq_list = (name, List.map (fun (TypedVariable (n, _)) -> n) args, equality) :: eq_list in
      helper (acc ^ proof_statement ^ "\n") new_eq_list rest
    | _ -> "TODO in simple"
  in
  helper "" [] declarations

let lemmas = [
  ("cf_idempotent", [], Equality(Identifier "cf (cf h)", Identifier "cf h"));
  ("inv_involution", [], Equality(Identifier "inv (inv h)", Identifier "h"));
  ("cf_inv_commute", [], Equality(Identifier "cf (inv h)", Identifier "inv (cf h)"));
]

(* Function to find an applicable rewrite rule *)
let find_applicable_rule (expr : expression) (rules : (string * string list * equality) list) : (string * expression) option =
  List.fold_left (fun acc (name, vars, eq) ->
    match acc with
    | Some _ -> acc
    | None -> match attempt_rewrite vars eq expr with
                | Some new_expr -> Some (name, new_expr)
                | None -> None
  ) None rules

(* Function to generate proof steps *)
let rec generate_proof_steps expr rules =
  match find_applicable_rule expr rules with
  | None -> "??? Could not determine a next proof step ???"
  | Some (rule_name, new_expr) ->
    "= {" ^ rule_name ^ "}\n" ^ string_of_expression new_expr ^ "\n" ^ generate_proof_steps new_expr rules

(* Function to generate proof for a single declaration *)
let generate_proof (_decl : declaration list) : string =
  "TODO"   
