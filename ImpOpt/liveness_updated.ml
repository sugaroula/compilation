
open Imp
open Nimp

module VSet = Set.Make(String)

(* returns the set of variables accessed by the expression [e] *)
let rec use_expr e =
  match e with
  | Num _ -> VSet.empty
  | Var x -> VSet.singleton x
  | Unop (_, e) -> use_expr e
  | Binop (_, e1, e2) -> VSet.union (use_expr e1) (use_expr e2)
  | Call (_, args) -> List.fold_left (fun acc e -> VSet.union acc (use_expr e)) VSet.empty args

let liveness fdef =
  let n = max_instr_list fdef.code in
  let live = Array.make (n + 1) VSet.empty in

  (* recursive function to compute live variables for a single instruction *)
  let rec lv_in_instr instr lv_out =
    match instr.ins with
    | Print e | Expr e -> VSet.union (use_expr e) lv_out
    | Return e -> use_expr e
    | Assign (x, e) -> VSet.union (use_expr e) (VSet.remove x lv_out)
    | Seq (s1, s2) -> lv_in_instr s1 (lv_in_instr s2 lv_out)
    | While (e, s) ->
        let lv_entry = VSet.union (use_expr e) (lv_in_instr s lv_out) in
        ignore (lv_in_instr s lv_entry); lv_entry
    | If (e, s1, s2) ->
        VSet.union (use_expr e)
          (VSet.union (lv_in_instr s1 lv_out) (lv_in_instr s2 lv_out))
  in

  (* liveness analysis for the whole program *)
  let lv_in_seq seq lv_out =
    List.fold_right (fun instr acc -> lv_in_instr instr acc) seq lv_out
  in

  (* Iterate through the function code *)
  let _ = lv_in_seq fdef.code VSet.empty in
  live
