type statement =
  | Declaration of ident * expression
  | Assignment of ident * expression
  | If_Else of expression * statement list * statement list
  | TypeDeclaration of ident * type_variant list  (* New: Type declarations *)
  | Proof of proof_statement                    (* New: Proof statements *)

and expression = 
  | Number of int
  | String of string
  | Identifier of ident
  | Application of expression * expression
  | Function of ident * ident * expression (* New: Function definition *)
  | Equation of expression * expression   (* New: For equations in proofs *)

and ident = string

and type_variant = 
  | TypeVariant of ident * (ident * ident) list (* New: For type variants *)

and proof_statement = 
  | Prove of ident * expression * hint_option
  | Axiom of ident * expression                 (* New: Axiom statements *)

and hint_option = 
  | NoHint
  | Hint of hint_type                           (* New: For proof hints *)

and hint_type = 
  | AxiomHint
  | Induction of ident                          (* New: Induction hint *)