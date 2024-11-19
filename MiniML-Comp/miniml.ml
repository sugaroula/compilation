(**
   Main language MiniML
   Pattern matching is simplified, by forcing each pattern to have
   exactly one constructor (you may replace by the original version
   if you prefer keeping nested patterns)
 *)

type typ =
  | TInt
  | TBool
  | TFun of typ * typ
  | TPair of typ * typ
  | TStruct of string

type expr =
  | Int of int
  | Bool of bool
  | Uop of Ops.unop * expr
  | Bop of Ops.binop * expr * expr
  | Var of string
  | Let of string * expr * expr
  | If  of expr * expr * expr
  | App of expr * expr
  | Fun of string * typ * expr
  | Fix of string * typ * expr
  (* Constructors, and simplified pattern matching (no nested patterns) *)
  | Cstr of string * expr list
  | Match of expr * case list
and case = pattern * expr
and pattern = string * string list

type cstr_decl = string * typ list
type typ_decl = string * cstr_decl list
type prog = {
  code: expr;
  typs: typ_decl list
}

let rec mk_fun xs e = match xs with
  | [] -> e
  | (x, t)::xs -> Fun(x, t, mk_fun xs e)
  
let rec mk_fun_type xs t = match xs with
  | [] -> t
  | (_, ta)::xs -> TFun(ta, mk_fun_type xs t)
