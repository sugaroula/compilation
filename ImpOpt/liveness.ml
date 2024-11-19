
open Imp
open Nimp

module VSet = Set.Make(String)

(* Compute variables used in expressions *)
let rec use_expr e =
  match e with
  | Var x -> VSet.singleton x
  | Cst _ -> VSet.empty
  | Binop (_, e1, e2) -> VSet.union (use_expr e1) (use_expr e2)
  | Call (_, args) -> List.fold_left (fun acc arg -> VSet.union acc (use_expr arg)) VSet.empty args
  | _ -> VSet.empty

(* Compute liveness sets for a function definition *)
let liveness fdef =
  let n = max_instr_list fdef.code in
  let live = Array.make (n + 1) VSet.empty in

  let rec lv_in_instr instr lv_out =
    match instr.instr with
    | Set (x, e) -> VSet.union (use_expr e) (VSet.remove x lv_out)
    | Putchar e | Expr e -> VSet.union (use_expr e) lv_out
    | If (cond, t_branch, f_branch) ->
        VSet.union (use_expr cond)
          (VSet.union (lv_in_list t_branch lv_out) (lv_in_list f_branch lv_out))
    | While (cond, body) ->
        let first_pass = VSet.union (use_expr cond) (lv_in_list body lv_out) in
        VSet.union (use_expr cond) (lv_in_list body first_pass)
    | Return e -> use_expr e
    | _ -> lv_out

  and lv_in_list code lv_out =
    List.fold_right (fun instr acc -> lv_in_instr instr acc) code lv_out
  in

  ignore (lv_in_list fdef.code VSet.empty);
  live

let liveness_intervals_from_liveness fdef =
  let live_sets = liveness fdef in
  let intervals = Hashtbl.create 16 in

  Array.iteri (fun i vars ->
      VSet.iter (fun var ->
          let (start_time, _) =
            try Hashtbl.find intervals var
            with Not_found -> (i, i)
          in
          Hashtbl.replace intervals var (start_time, i)
        ) vars
    ) live_sets;

  Hashtbl.fold (fun var (start, end_time) acc -> (var, start, end_time) :: acc) intervals []
