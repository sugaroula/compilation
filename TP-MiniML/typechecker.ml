open Miniml

module Env = Map.Make(String)
(* typing environment for variables *)
type tenv = typ Env.t
(* typing environment for constructors *)
type senv = (typ list * string) Env.t
(* Env. find <constructor name> senv ===> (<argument types>, <name of constructed type>)
Env. find         "N"           senv ===> ([TStruct "treet"; TStruct "tree"], "tree")

type tree = E | N of tree * tree *)

(* Typecheck unary operators *)
let typ_uop uop t =
  match uop with
  | Not -> if t = TBool then TBool else failwith "Type error: Not expects TBool"
  | Minus -> if t = TInt then TInt else failwith "Type error: Minus expects TInt"
  | Fst -> (match t with TPair(t1, _) -> t1 | _ -> failwith "Type error: Fst expects a pair")
  | Snd -> (match t with TPair(_, t2) -> t2 | _ -> failwith "Type error: Snd expects a pair")

(* Typecheck binary operators *)
let typ_bop bop t1 t2 =
  match bop with
  | Add | Sub | Mul | Div | Rem | Lsr | Lsl -> if t1 = TInt && t2 = TInt then TInt else failwith "Type error: Arithmetic operators expect TInt"
  | Lt  | Le  | Gt  | Ge -> if t1 = TInt && t2 = TInt then TBool else failwith "Type error: Arithmetic operators expect TInt"
  | And | Or -> if t1 = TBool && t2 = TBool then TBool else failwith "Type error: Logical operators expect TBool"
  | Pair -> TPair(t1, t2)
  | _ -> failwith "Unknown binary operator"

(* Typecheck patterns *)
let rec typ_pattern p tenv senv =
  match p with
  | PVar x -> (Env.add x TInt tenv, TInt)
  | PPair(p1, p2) ->
      let (tenv1, t1) = typ_pattern p1 tenv senv in
      let (tenv2, t2) = typ_pattern p2 tenv1 senv in
      (tenv2, TPair(t1, t2))
  | PWildcard -> (tenv, TInt)
  | PCstr(c, args) ->
      (try
         let (arg_types, result_type) = Env.find c senv in
         if List.length args = List.length arg_types then
           let tenv' = List.fold_left2
             (fun acc arg arg_type ->
                let (tenv'', arg_t) = typ_pattern arg acc senv in
                if arg_t = arg_type then tenv'' else failwith "Pattern argument type mismatch")
             tenv args arg_types
           in
           (tenv', TStruct result_type)
         else failwith "Constructor arity mismatch"
       with Not_found -> failwith ("Unknown constructor: " ^ c))

(* Typecheck expressions *)
let rec typ_expr (e: expr) (tenv: tenv) (senv: senv) =
  match e with
  | Int _ -> TInt
  | Bool _ -> TBool
  | Var x -> (try Env.find x tenv with Not_found -> failwith ("Unbound variable: " ^ x))
  | Uop(op, e) -> typ_uop op (typ_expr e tenv senv)
  | Bop(op, e1, e2) -> typ_bop op (typ_expr e1 tenv senv) (typ_expr e2 tenv senv)
  | Pair(e1, e2) -> TPair(typ_expr e1 tenv senv, typ_expr e2 tenv senv)
  | Match(e, patterns) ->
      let t = typ_expr e tenv senv in
      (match patterns with
       | [] -> failwith "Non-exhaustive pattern matching"
       | _ ->
           let rec check_patterns = function
             | [] -> failwith "No matching patterns"
             | (p, e) :: ps ->
                 let (pat_tenv, pat_type) = typ_pattern p tenv senv in
                 if pat_type = t then typ_expr e pat_tenv senv
                 else failwith "Pattern type mismatch"
           in check_patterns patterns)
  | _ -> failwith "Expression type not supported"
