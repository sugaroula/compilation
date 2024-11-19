
(**
   Translation from IMP to MIPS with optimized function argument handling.
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

let arg_regs = [| a0; a1; a2; a3 |]
let nb_arg_regs = Array.length arg_regs

let push reg = subi sp sp 4 @@ sw reg 0(sp)
let pop reg = lw reg 0(sp) @@ addi sp sp 4

(* Allocate function arguments *)
let allocate_arguments args =
  let alloc = Hashtbl.create 16 in
  List.iteri (fun i arg ->
    if i < nb_arg_regs then
      Hashtbl.add alloc arg (arg_regs.(i))
    else
      Hashtbl.add alloc arg "spill"
  ) args;
  alloc

let rec compile_function_with_args fdef =
  let alloc = allocate_arguments fdef.args in
  let live = liveness fdef in
  let intervals = compute_intervals live in
  let reg_alloc = linear_scan intervals in
  compile_instr (Hashtbl.merge (fun _ a b -> Some (Option.value b ~default:a)) alloc reg_alloc) fdef.code

