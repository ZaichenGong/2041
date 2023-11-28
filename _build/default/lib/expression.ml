include Ast

module Parser = Parser
module Lexer = Lexer

let empty = []
let singleton x y = [(x,y)]
let merge s1 s2 = match s1 with
  | [] -> Some s2 (* this case is actually correct, but it shouldn't be needed once the other one is fixed *)
  | _ -> Some s1 (* todo: fix *)

let find x s = match s with
  | [] -> failwith "Not found (find was passed an empty list)"
  | [(k,v)] -> if x = k then v else failwith "Not found (find failed but the substitution being passed in really does not contain the variable)"
  | _ -> failwith "Find failed (key not found because this part of the find function is utterly broken)"

let parse (s : string) : declaration list =
  let lexbuf = Lexing.from_string s in
  let ast = Parser.main Lexer.token lexbuf in
     ast

let rec string_of_expression (e : expression) : string =
  match e with
  | Application (e, arg) ->
    (string_of_expression e) ^ " (" ^ string_of_expression arg ^ ")"
  | Identifier name -> name

let string_of_hint (h : hint option) : string =
  match h with
  | Some Axiom -> "\n(*hint: axiom *)"
  | None -> ""

let string_of_equality (e : equality) : string =
  match e with
  | Equality (e1, e2) -> "(" ^ (string_of_expression e1) ^ " = " ^ (string_of_expression e2) ^ ")"

let string_of_typedvariable (TypedVariable (name, type_name) : typedVariable) : string =
  "(" ^ name ^ " : " ^ type_name ^ ")"

let string_of_declaration (d : declaration) : string =
  match d with
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
      (* Add more cases for other expression types if needed *)
      | _ -> None)

and match_expressions (variables : string list) (pattern : expression) (expr : expression) : expression option =
  match pattern, expr with
  | Identifier var, _ when List.mem var variables -> Some expr
  | Application (p1, p2), Application (e1, e2) ->
    (match match_expressions variables p1 e1, match_expressions variables p2 e2 with
    | Some matched_p1, Some matched_p2 -> Some (Application (matched_p1, matched_p2))
    | _ -> None)
  (* Add more cases for other expression types if needed *)
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
  in
  let result = helper "" [] declarations in
  "(* Generated Proof *)\n" ^ result