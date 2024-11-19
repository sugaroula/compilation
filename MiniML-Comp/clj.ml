(**
   Intermediate language Clj
   Similar to MiniML, but without anonymous functions
   All functions are defined globally (at "toplevel") 
   and take one explicit parameter and one implicit closure
 *)

(* Variables are split into two categories *)
type var =
  | CVar of int    (* closure variables, indexed locally by numbers *)
  | Name of string (* other variables, identified by their name     *)

(* Expressions, similar to MiniMLs, without anonymous functions *)
type expression =
  | Int   of int
  | Bool  of bool
  | Var   of var
  | Unop  of Ops.unop * expression
  | Binop of Ops.binop * expression * expression

  (* builds a closre, given a global function name and a list of free variables *)
  | MkClj of string * var list

  | App   of expression * expression
  | If    of expression * expression * expression
  | Let   of string * expression * expression
  | Fix   of string * expression

  | Cstr  of string * expression list
  | Match of expression * case list
and case = pattern * expression
and pattern = string * string list
      
(* Definition of a global function *)
type function_def = {
  name: string; (* function name, as used in [MkClj] *)
  body: expression;
  param: string; (* name of the unique parameter *)
}

(* A program is a main expression and a set of global function definitions *)
type program = {
  functions: function_def list;
  code: expression;
}
