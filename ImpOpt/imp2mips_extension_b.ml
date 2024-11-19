
(**
   Translation from IMP to MIPS with support for reusing stack slots.
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

(* Enhanced stack management for spills *)
let spill_slots = Hashtbl.create 16

let get_or_allocate_spill_slot var =
  try Hashtbl.find spill_slots var
  with Not_found ->
    let offset = Hashtbl.length spill_slots * 4 in
    Hashtbl.add spill_slots var offset;
    offset

let spill var reg =
  let offset = get_or_allocate_spill_slot var in
  sw reg offset(sp)

let load_spill var reg =
  let offset = get_or_allocate_spill_slot var in
  lw reg offset(sp)

let rec compile_expr_with_reuse alloc reg expr =
  match expr with
  | Num n -> li reg n
  | Var x ->
      let src = translate_variable alloc x in
      if src = "spill" then
        load_spill x reg
      else
        move reg src
  | Binop (op, e1, e2) ->
      let reg1 = tmp_regs.(0) and reg2 = tmp_regs.(1) in
      compile_expr_with_reuse alloc reg1 e1 @@
      compile_expr_with_reuse alloc reg2 e2 @@
      (match op with
       | Add -> add reg reg1 reg2
       | Sub -> sub reg reg1 reg2
       | Mul -> mul reg reg1 reg2
       | Div -> div reg reg1 reg2)
  | _ -> failwith "Not implemented"

