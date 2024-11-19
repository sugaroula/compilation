open Miniml

module Env = Map.Make(String)
type value =
  | VInt of int
  | VBool of bool
  | VClos of string * expr * env
  | VFix of expr * string * value * env 
  | VCstr of string * value list
  | VPair of value * value
and env = value Env.t

open Printf
let rec print_value = function
  | VInt n -> printf "%d" n
  | VBool b -> printf "%b" b
  | VClos _ -> printf "<fun>"
  | VFix(Fun _, _, _, _) -> printf "<fun>"
  | VFix _ -> failwith "fix value error"
  | VPair(v1, v2) -> printf "("; print_value v1; printf ", "; print_value v2; printf ")"
  | VCstr(c, vlist) -> printf "%s(" c; print_vlist vlist; printf ")"
and print_vlist = function
  | [] -> ()
  | [v] -> print_value v
  | v::vlist -> print_value v; printf ", "; print_vlist vlist

let rec eval e env = match e with
  | Int n -> VInt n
  | Bool b -> VBool b
  | Var x -> Env.find x env
  | Let(x, e1, e2) -> let v1 = eval e1 env in eval e2 @@ Env.add x v1 env
  | Bop(op, e1, e2) -> eval_bop op (eval e1 env) (eval e2 env)
  | Uop(op, e) -> eval_uop op (eval e env)
  | If(c, e1, e2) -> 
     begin match eval c env with
       | VBool b -> if b then eval e1 env else eval e2 env
       | _ -> failwith "unauthorized operation"
     end
  | App(e1, e2) ->
     let x, e, env' = match force @@ eval e1 env with
       | VClos(x, e, env) -> x, e, env
       | _ -> failwith "unauthorized operation"
     in
     let v2 = eval e2 env in 
     eval e (Env.add x v2 env')
  | Fun(x, _, e) -> VClos(x, e, env)
  | Fix(x, _, e) -> let rec v = VFix(e, x, v, env) in v
  | Pair(e1, e2) -> VPair(eval e1 env, eval e2 env)
  | Match(e, cases) ->
      let v = eval e env in
      let rec match_pattern v = function
        | [] -> failwith "Non-exhaustive pattern match"
        | (p, e) :: rest ->
            (try eval e (extend_env_with_pattern env p v)
             with Match_failure -> match_pattern v rest)
      in match_pattern v cases
  | Constr(c, args) -> VCstr(c, List.map (fun e -> eval e env) args)
  | _ -> failwith "not implemented"
and force v = match v with
  | VFix(e, x, v, env) -> force (eval e @@ Env.add x v env)
  | v -> v
and eval_uop uop v =
  match uop, v with
  | Not, VBool b -> VBool (not b)
  | Minus, VInt n -> VInt (-n)
  | Fst, VPair(v1, _) -> v1
  | Snd, VPair(_, v2) -> v2
  | _ -> failwith "Invalid unary operation"
and eval_bop bop v1 v2 =
  match bop, v1, v2 with
  | Add, VInt n1, VInt n2 -> VInt (n1 + n2)
  | Sub, VInt n1, VInt n2 -> VInt (n1 - n2)
  | Mul, VInt n1, VInt n2 -> VInt (n1 * n2)
  | Div, VInt n1, VInt n2 when n2 <> 0 -> VInt (n1 / n2)
  | And, VBool b1, VBool b2 -> VBool (b1 && b2)
  | Or, VBool b1, VBool b2 -> VBool (b1 || b2)
  | Pair, v1, v2 -> VPair(v1, v2)
  | _ -> failwith "Invalid binary operation"
and extend_env_with_pattern env pat v =
  match pat, v with
  | PVar x, v -> Env.add x v env
  | PPair(p1, p2), VPair(v1, v2) ->
      extend_env_with_pattern (extend_env_with_pattern env p1 v1) p2 v2
  | PCstr(c, args), VCstr(c', values) when c = c' ->
      List.fold_left2 extend_env_with_pattern env args values
  | PWildcard, _ -> env
  | _ -> failwith "Pattern match failure"

let eval_prog p = eval p.code Env.empty
