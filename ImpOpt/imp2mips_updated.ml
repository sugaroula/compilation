
(**
   Translation from IMP to MIPS with register allocation.
   Incorporates liveness analysis and linear scan register allocation.
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

(* Helper to translate variables to allocated registers or stack *)
let translate_variable alloc var =
  try Hashtbl.find alloc var
  with Not_found -> raise (Error ("Unallocated variable: " ^ var))

(* Function to handle instructions with allocation *)
let rec compile_instr alloc instr =
  match instr.ins with
  | Assign (x, e) ->
      let reg = translate_variable alloc x in
      compile_expr alloc reg e
  | Print e ->
      let reg = tmp_regs.(0) in
      compile_expr alloc reg e @@ move a0 reg @@ li v0 1 @@ syscall
  | Seq (s1, s2) -> compile_instr alloc s1 @@ compile_instr alloc s2
  | _ -> failwith "Not implemented" (* Handle other cases similarly *)

and compile_expr alloc reg expr =
  match expr with
  | Num n -> li reg n
  | Var x -> let src = translate_variable alloc x in move reg src
  | _ -> failwith "Not implemented" (* Handle other cases similarly *)

(* Main compilation function *)
let compile_function fdef =
  let live = liveness fdef in
  let intervals = compute_intervals live in
  let alloc = linear_scan intervals in
  compile_instr alloc fdef.code

