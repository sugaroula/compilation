(**
   Translation from IMP to MIPS.

   Result of an expression stored in $t0. Every intermediate value on the
   stack, every function argument and every local variable also on the stack.
 *)

open Imp
open Mips

exception Error of string

let tmp_regs = [| t0; t1; t2; t3; t4; t5; t6; t7; t8; t9 |]
let nb_tmp_regs = Array.length tmp_regs

let var_regs = [| s0; s1; s2; s3; s4; s5; s6; s7 |]
let nb_var_regs = Array.length var_regs

let push reg = subi sp sp 4 @@ sw reg 0(sp)
let pop  reg = lw reg 0(sp) @@ addi sp sp 4

let rec    save regs k = if k < 0 then nop else save regs (k-1) @@ push regs.(k)
let rec restore regs k = if k < 0 then nop else    pop regs.(k) @@ restore regs (k-1)

let    save_tmp = save    tmp_regs
let restore_tmp = restore tmp_regs

(* explicit allocation information for a local variable *)
type explicit_alloc =
  | Reg   of string  (* name of the register *)
  | Stack of int     (* offset on the stack, relative to fp *)

(* create an explicit allocation for all local variables and function 
   parameters of a function [fdef] *)
let allocate_locals fdef =
  let nfdef = Nimp.from_imp_fdef fdef in
  let raw_alloc, r_max, spill_count = Linearscan.lscan_alloc nb_var_regs nfdef in
  let alloc =
    failwith "not implemented"
  in
  failwith "not implemented"

(* Generate Mips code for an Imp function *)
(* Call frame

     | sp                          fp             |
   --+-------------+--------+----+----+-----------+------
     | temp values | locals | ra | fp | arguments |
   --+-------------+--------+----+----+-----------+------
     |               callee frame                 |   caller frame

   The caller is reponsible for pushing/popping the arguments, the callee
   is reponsible for everything else. *)
let tr_function fdef =
  (* Allocation info for local variables and function parameters *)
  (* TODO: replace with an explicit allocation table deduced from [allocate_locals] *)
  let alloc = Hashtbl.create 16 in
  List.iteri (fun k id -> Hashtbl.add alloc id (4*(k+1))) fdef.params;
  List.iteri (fun k id -> Hashtbl.add alloc id (-4*(k+2))) fdef.locals;

  (* Generate Mips code for an Imp expression. The generated code produces the
     result in register $ti, and do not alter registers $tj with j < i. *)
  let rec tr_expr i e =
    let ti = 
      if i < nb_tmp_regs then tmp_regs.(i) 
      else raise (Error "not enough temporary registers")
    in 
    match e with
    | Cst(n)  -> li ti n
    | Bool(b) -> if b then li ti 1 else li ti 0
    | Var(x) -> 
      (* TODO: replace to take into account explicit allocation info *)
      (match Hashtbl.find_opt alloc x with
       | Some offset -> lw ti offset(fp)
       | None -> la ti x @@ lw ti 0(ti)) (* non-local assumed to be a valid global *)
    | Binop(bop, e1, e2) ->
       let op = match bop with
         | Add -> add
         | Mul -> mul
         | Lt  -> slt
       in
       if i+1 >= nb_tmp_regs then raise (Error "not enough temporary registers");
       tr_expr i e1 @@ tr_expr (i+1) e2 @@ op ti ti tmp_regs.(i+1)

    (* Function call.
       Evaluate the arguments and push their values onto the stack.
       Save all temporary registers with number < i
       Jump to the function.
       Finallly restore saved tempary registers and clean the stack. *)
    | Call(f, params) ->
       tr_params i params @@ save_tmp (i-1) 
       @@ jal f 
       @@ restore_tmp (i-1) @@ addi sp sp (4 * List.length params)

  and tr_params i = function
    | []        -> nop
    | e::params -> tr_params i params @@ tr_expr i e @@ push tmp_regs.(i)

  in

  (* Generate new labels for jumps *)
  let new_label =
    let cpt = ref (-1) in
    fun () -> incr cpt; Printf.sprintf "__%s_%i" fdef.name !cpt
  in

  (* Generate MIPS code for an Imp instruction or sequence. *)
  let rec tr_seq = function
    | []   -> nop
    | i::s -> tr_instr i @@ tr_seq s

  and tr_instr = function
    | Putchar(e) -> tr_expr 0 e @@ move a0 t0 @@ li v0 11 @@ syscall
    | Set(x, e) ->
       (* TODO: replace to take into account explicit allocation info *)
       let set_code = match Hashtbl.find_opt alloc x with
         | Some offset -> sw t0 offset(fp)
         | None -> la t1 x @@ sw t0 0(t1)
       in
       tr_expr 0 e @@ set_code

    | If(c, s1, s2) ->
       let then_label = new_label()
       and end_label = new_label()
       in
       tr_expr 0 c @@ bnez t0 then_label
       (* fall to else branch *) @@ tr_seq s2 @@ b end_label
       @@ label then_label @@ tr_seq s1 (* fall through *)
       @@ label end_label

    | While(c, s) ->
       let test_label = new_label()
       and code_label = new_label()
       in
       b test_label
       @@ label code_label @@ tr_seq s
       @@ label test_label @@ tr_expr 0 c @@ bnez t0 code_label
       (* fall through *)

    (* Return from a call with a value. Includes cleaning the stack. *)
    | Return(e) -> tr_expr 0 e @@ addi sp fp (-4) @@ pop ra @@ pop fp @@ jr ra
    | Expr(e) -> tr_expr 0 e
  in

  (* Mips code for the function itself. 
     Initialize the stack frame and save callee-saved registers, run the code of 
     the function, then restore callee-saved, clean the stack and returns with a 
     dummy value if no explicit return met. *)
  push fp @@ push ra @@ addi fp sp 4
  (* TODO: replace the following, to save callee-saved registers and allocate 
     the right number of slots on the stack for spilled local variables *)
  @@ addi sp sp (-4 * List.length fdef.locals)
  @@ tr_seq fdef.code
  (* TODO: restore callee-saved registers *)
  @@ addi sp fp (-4) 
  @@ pop ra @@ pop fp @@ li t0 0 @@ jr ra

(* Generate Mips code for an Imp program. *)
let translate_program prog =
  let init = 
    beqz a0 "init_end" @@ lw a0 0(a1) @@ jal "atoi"
    @@ label "init_end" @@ push v0
    @@ jal "main"
    @@ li v0 10 @@ syscall
  and built_ins =
    comment "built-in atoi"
    @@ label "atoi" @@ li v0 0
    @@ label "atoi_loop" @@ lbu t0 0(a0) @@ beqz t0 "atoi_end"
    @@ addi t0 t0 (-48) @@ bltz t0 "atoi_error" @@ bgei t0 10 "atoi_error"
    @@ muli v0 v0 10 @@ add v0 v0 t0 @@ addi a0 a0 1 @@ b "atoi_loop"
    @@ label "atoi_error" @@ li v0 10 @@ syscall
    @@ label "atoi_end" @@ jr ra
  in

  let function_codes = List.fold_left
    (fun code fdef -> code @@ label fdef.name @@ tr_function fdef)
    nop prog.functions
  in
  let text = init @@ function_codes @@ built_ins in
  let data = List.fold_left
      (fun code id -> code @@ label id @@ dword [0])
      nop prog.globals
  in
  
  { text; data }
