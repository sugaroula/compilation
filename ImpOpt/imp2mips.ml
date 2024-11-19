
(**
   Translation from IMP to MIPS.

   Result of an expression stored in $t0. Every intermediate value on the
   stack, every function argument and every local variable also on the stack.
 *)

open Imp
open Mips

exception Error of string

let tmp_regs = [| t0; t1; t2; t3; t4; t5; t6; t7; t8; t9 |]
let var_regs = [| s0; s1; s2; s3; s4; s5; s6; s7 |]

(* Translate expressions into MIPS *)
let rec tr_expr i e alloc =
  match e with
  | Var x -> (
      match Hashtbl.find_opt alloc x with
      | Some r -> move tmp_regs.(i) r
      | None -> raise (Error ("Variable " ^ x ^ " not allocated"))
    )
  | Cst n -> li tmp_regs.(i) n
  | Binop (op, e1, e2) ->
      let instr = match op with Add -> add | Sub -> sub | Mul -> mul | Div -> div in
      tr_expr i e1 alloc @@ tr_expr (i + 1) e2 alloc @@ instr tmp_regs.(i) tmp_regs.(i + 1)
  | _ -> raise (Error "Unsupported expression")

(* Translate instructions into MIPS *)
let rec tr_instr instr alloc =
  match instr with
  | Set (x, e) ->
      tr_expr 0 e alloc @@ sw tmp_regs.(0) (Hashtbl.find alloc x)
  | Putchar e -> tr_expr 0 e alloc @@ syscall
  | If (cond, t_branch, f_branch) ->
      let then_label = Printf.sprintf "then_%d" (Random.int 1000) in
      let end_label = Printf.sprintf "end_%d" (Random.int 1000) in
      tr_expr 0 cond alloc @@ bnez tmp_regs.(0) then_label @@ tr_instr t_branch alloc @@ b end_label @@ label then_label @@ tr_instr f_branch alloc @@ label end_label
  | _ -> nop

(* Translate a function *)
let tr_function fdef =
  List.fold_left (fun acc instr -> acc @@ tr_instr instr fdef.alloc) nop fdef.code

(* Translate a program *)
let translate_program prog =
  List.map tr_function prog.functions
