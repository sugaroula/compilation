open Miniml

module Env = Map.Make(String)
type tenv = typ Env.t
type senv = (typ list * string) Env.t

(* Add constructors to the environment *)
let rec populate_cstr_env type_name constructors env =
  match constructors with
  | [] -> env
  | (c_name, c_types) :: rest ->
      let env = Env.add c_name (c_types, type_name) env in
      populate_cstr_env type_name rest env

(* Add type definitions to the environment *)
let rec populate_type_env type_decls env =
  match type_decls with
  | [] -> env
  | (type_name, constructors) :: rest ->
      let env = populate_cstr_env type_name constructors env in
      populate_type_env rest env

(* Typechecking expressions *)
let typ_expr e senv =
  let rec typ e tenv =
    match e with
    | Int _ -> TInt
    | Bool _ -> TBool
    | Var x -> Env.find x tenv
    | Let(x, e1, e2) ->
        let t1 = typ e1 tenv in
        typ e2 (Env.add x t1 tenv)
    | Bop(op, e1, e2) ->
        let t1 = typ e1 tenv and t2 = typ e2 tenv in
        (match op, t1, t2 with
        | (Add | Sub | Mul | Div | Rem | Lsl | Lsr), TInt, TInt -> TInt
        | (Lt | Le | Gt | Ge), TInt, TInt -> TBool
        | (And | Or), TBool, TBool -> TBool
        | (Eq | Neq), t1, t2 when t1 = t2 -> TBool
        | Pair, t1, t2 -> TPair(t1, t2)
        | _ -> failwith "Invalid binary operation")
    | Uop(op, e) ->
        let t = typ e tenv in
        (match op, t with
        | Not, TBool -> TBool
        | Minus, TInt -> TInt
        | Fst, TPair(t1, _) -> t1
        | Snd, TPair(_, t2) -> t2
        | _ -> failwith "Invalid unary operation")
    | If(c, e1, e2) ->
        let tc = typ c tenv and t1 = typ e1 tenv and t2 = typ e2 tenv in
        if tc = TBool && t1 = t2 then t1
        else failwith "If branches must have the same type"
    | Fun(x, t, e) ->
        let t2 = typ e (Env.add x t tenv) in
        TFun(t, t2)
    | App(e1, e2) ->
        let t1 = typ e1 tenv and t2 = typ e2 tenv in
        (match t1 with
        | TFun(arg_t, ret_t) when arg_t = t2 -> ret_t
        | _ -> failwith "Invalid function application")
    | Cstr(c_name, args) ->
        (match Env.find_opt c_name senv with
        | Some(expected_types, type_name) ->
            if check_args args expected_types tenv then TStruct type_name
            else failwith (Printf.sprintf "Invalid arguments for constructor %s" c_name)
        | None -> failwith (Printf.sprintf "Unknown constructor %s" c_name))
    | Match(e, cases) ->
        let t = typ e tenv in
        check_cases t cases tenv
    | Fix(x, t, e) ->
        if typ e (Env.add x t tenv) = t then t
        else failwith "Invalid recursive definition"
  and check_args args expected_types tenv =
    try
      List.for_all2 (fun arg expected_typ -> typ arg tenv = expected_typ) args expected_types
    with Invalid_argument _ -> failwith "Argument count mismatch"
  and check_cases expr_type cases tenv =
    match cases with
    | [] -> failwith "No cases provided"
    | (pat, body) :: rest ->
        let body_t = check_case pat body expr_type tenv in
        check_case_types body_t expr_type rest tenv
  and check_case pat body expr_type tenv =
    let extended_tenv = extend_tenv_with_pattern pat expr_type tenv in
    typ body extended_tenv
  and check_case_types body_t expr_type cases tenv =
    List.fold_left
      (fun acc (pat, body) ->
        let body_t' = check_case pat body expr_type tenv in
        if body_t = body_t' then body_t
        else failwith "Mismatched case types")
      body_t
      cases
  and extend_tenv_with_pattern pat t tenv =
    match pat with
    | PVar x -> Env.add x t tenv
    | PCstr(c_name, sub_pats) ->
        (match Env.find_opt c_name senv with
        | Some(arg_types, struct_name) when TStruct struct_name = t ->
            List.fold_left2
              (fun acc sub_pat arg_t -> extend_tenv_with_pattern sub_pat arg_t acc)
              tenv sub_pats arg_types
        | _ -> failwith "Invalid pattern constructor")
  in
  typ e Env.empty

let typ_prog p =
  let senv = populate_type_env p.typs Env.empty in
  typ_expr p.code senv
