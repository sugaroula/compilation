
(**
   Translation from IMP to MIPS with support for spilling intermediate values.
*)

open Imp
open Mips
open Liveness
open LinearScan

exception Error of string

let tmp_regs = [| t0; t1; t2; t3; t4; t5; t6; t7; t8; t9 |]
let nb_tmp_regs = Array.length tmp_regs

let var_regs = [| s0; s1; s2; s3; s4; s5; s6; s7 |]
let nb_var_regs = Array.length var_regs

let push reg = subi sp sp 4 @@ sw reg 0(sp)
let pop reg = lw reg 0(sp) @@ addi sp sp 4

(* Helper to handle temporary register exhaustion by spilling *)
let spill_stack = ref 0

let get_spill_slot () =
  let slot = !spill_stack in
  spill_stack := !spill_stack + 1;
  -slot * 4

let spill reg =
  let offset = get_spill_slot () in
  sw reg offset(sp), offset

let load_spill reg offset = lw reg offset(sp)

let rec compile_expr_with_spill alloc reg expr =
  match expr with
  | Num n -> li reg n
  | Var x ->
      let src = translate_variable alloc x in
      if src = "spill" then
        let offset = get_spill_slot () in
        load_spill reg offset
      else
        move reg src
  | Binop (op, e1, e2) ->
      let reg1 = tmp_regs.(0) and reg2 = tmp_regs.(1) in
      let spill1 = spill reg1 in
      let spill2 = spill reg2 in
      compile_expr_with_spill alloc reg1 e1 @@
      compile_expr_with_spill alloc reg2 e2 @@
      (match op with
       | Add -> add reg reg1 reg2
       | Sub -> sub reg reg1 reg2
       | Mul -> mul reg reg1 reg2
       | Div -> div reg reg1 reg2) @@
      load_spill reg1 (snd spill1) @@
      load_spill reg2 (snd spill2)
  | _ -> failwith "Not implemented"

