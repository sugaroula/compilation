open Miniml

module Env = Map.Make(String)
type value =
  | VInt of int
  | VBool of bool
  | VClos of string * expr * env
  | VFix of expr * string * value * env 
  | VCstr of string * value list
and env = value Env.t

open Printf
let rec print_value = function
  | VInt n -> printf "%d" n
  | VBool b -> printf "%b" b
  | VClos _ -> printf "<fun>"
  | VFix(Fun _, _, _, _) -> printf "<fun>"
  | VFix _ -> failwith "fix value error"
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
  | Bop(op, e1, e2) ->
     begin match op, eval e1 env, eval e2 env with
       | Add, VInt n1, VInt n2 -> VInt (n1 + n2)
       | Sub, VInt n1, VInt n2 -> VInt (n1 - n2)
       | Mul, VInt n1, VInt n2 -> VInt (n1 * n2)
       | Lt,  VInt n1, VInt n2 -> VBool (n1 < n2)
       | Eq,  v1,      v2      -> VBool (v1 = v2)
       | _ -> failwith "unauthorized operation"
     end
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
  | _ -> failwith "not implemented"
and force v = match v with
  | VFix(e, x, v, env) -> force (eval e @@ Env.add x v env)
  | v -> v

let eval_prog p = eval p.code Env.empty
