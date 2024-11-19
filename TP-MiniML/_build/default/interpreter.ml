open Miniml
open Printf

exception Match_fail

module Env = Map.Make(String)
type value =
  | VInt of int
  | VBool of bool
  | VClos of string * expr * env
  | VFix of expr * string * value * env
  | VCstr of string * value list
  | VPair of value * value
and env = value Env.t

let rec eval e env =
  match e with
  | Int n -> VInt n
  | Bool b -> VBool b
  | Var x -> Env.find x env
  | Let(x, e1, e2) ->
      let v1 = eval e1 env in eval e2 (Env.add x v1 env)
  | Uop(op, e) -> eval_uop op (eval e env)
  | Bop(op, e1, e2) -> eval_bop op (eval e1 env) (eval e2 env)
  | If(c, e1, e2) ->
      (match eval c env with
      | VBool true -> eval e1 env
      | VBool false -> eval e2 env
      | _ -> failwith "type error: if condition")
  | Fun(x, _, e) -> VClos(x, e, env)
  | App(e1, e2) ->
      let v1 = eval e1 env in
      let v2 = eval e2 env in
      (match v1 with
      | VClos(x, body, env') -> eval body (Env.add x v2 env')
      | _ -> failwith "type error: application")
  | Fix(x, _, e) ->
      let rec v = VFix(e, x, v, env) in v
  | Cstr(c, args) -> VCstr(c, List.map (fun e -> eval e env) args)
  | Match(e, cases) ->
      let v = eval e env in
      eval_cases v cases env

and eval_uop op v =
  match op, v with
  | Not, VBool b -> VBool (not b)
  | Minus, VInt n -> VInt (-n)
  | Fst, VPair(v1, _) -> v1
  | Snd, VPair(_, v2) -> v2
  | _ -> failwith "Invalid unary operation"

and eval_bop op v1 v2 =
  match op, v1, v2 with
  | Add, VInt n1, VInt n2 -> VInt (n1 + n2)
  | Sub, VInt n1, VInt n2 -> VInt (n1 - n2)
  | Mul, VInt n1, VInt n2 -> VInt (n1 * n2)
  | Div, VInt n1, VInt n2 when n2 != 0 -> VInt (n1 / n2)
  | Rem, VInt n1, VInt n2 when n2 != 0 -> VInt (n1 mod n2)
  | Lsl, VInt n1, VInt n2 -> VInt (n1 lsl n2)
  | Lsr, VInt n1, VInt n2 -> VInt (n1 lsr n2)
  | And, VBool b1, VBool b2 -> VBool (b1 && b2)
  | Or, VBool b1, VBool b2 -> VBool (b1 || b2)
  | Eq, v1, v2 -> VBool (v1 = v2)
  | Neq, v1, v2 -> VBool (v1 <> v2)
  | Lt, VInt n1, VInt n2 -> VBool (n1 < n2)
  | Le, VInt n1, VInt n2 -> VBool (n1 <= n2)
  | Gt, VInt n1, VInt n2 -> VBool (n1 > n2)
  | Ge, VInt n1, VInt n2 -> VBool (n1 >= n2)
  | Pair, v1, v2 -> VPair(v1, v2)
  | _ -> failwith "Invalid binary operation"

and eval_cases v cases env =
  match cases with
  | [] -> failwith "Non-exhaustive patterns"
  | (pat, body) :: rest ->
      (try eval body (match_pattern v pat env) with
      | Match_fail -> eval_cases v rest env)

and match_pattern v pat env =
  match pat, v with
  | PVar x, _ -> Env.add x v env
  | PCstr(c, args), VCstr(c', vals) when c = c' ->
      (try List.fold_left2 (fun acc pat arg -> match_pattern arg pat acc) env args vals
       with Invalid_argument _ -> raise Match_fail)
  | _ -> raise Match_fail

let eval_prog p = eval p.code Env.empty

let rec print_value = function
  | VInt n -> printf "%d\n" n
  | VBool b -> printf "%b\n" b
  | VClos _ -> printf "<fun>\n"
  | VFix(Fun _, _, _, _) -> printf "<fun>\n"
  | VFix _ -> failwith "fix value error\n"
  | VCstr(c, vlist) -> printf "%s(" c; print_vlist vlist; printf ")\n"
  | VPair(x, y) -> printf "("; print_value x; printf ","; print_value y; printf ")\n"
and print_vlist = function
  | [] -> ()
  | [v] -> print_value v
  | v :: vlist -> print_value v; printf ", "; print_vlist vlist
