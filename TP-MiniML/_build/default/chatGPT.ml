open Miniml

module Env = Map.Make(String)
(* typing environment for variables *)
type tenv = typ Env.t
(* typing environment for constructors *)
type senv = (typ list * string) Env.t

let typ_expr (e: expr) (senv: senv) =
  let rec typ (e: expr) (tenv: tenv) = match e with
    | Int _ -> TInt
    | Bool _ -> TBool
    | Bop(op, e1, e2) ->
      begin match op, typ e1 tenv, typ e2 tenv with
        | (Add | Sub | Mul | Div | Lsl | Lsr), TInt, TInt -> TInt
        | (Lt | Le | Gt | Ge), TInt, TInt -> TBool
        | (Eq | Neq), t1, t2 when t1 = t2 -> TBool
        | Pair, t1, t2 -> TPair(t1, t2)
        | (And | Or), TBool, TBool -> TBool 
        | _ -> failwith "type error: binop"
      end
    | Var(x) -> 
      begin try Env.find x tenv
      with Not_found -> failwith ("type error: unbound variable " ^ x)
      end
    | Let(x, e1, e2) ->
      let t1 = typ e1 tenv in
      typ e2 (Env.add x t1 tenv) 
    | If(c, e1, e2) ->
      begin match typ c tenv, typ e1 tenv, typ e2 tenv with
        | TBool, t1, t2 when t1 = t2 -> t1
        | _ -> failwith "type error: if"
      end
    | App(e1, e2) ->
      begin match typ e1 tenv, typ e2 tenv with
        | TFun(ta, t1), t2 when ta = t2 -> t1
        | _ -> failwith "type error: application"
      end
    | Fun(x, t, e) ->
       TFun(t, typ e (Env.add x t tenv))
    | Fix(x, t, e) ->
      if typ e (Env.add x t tenv) = t then t
      else failwith "type error: fix"
    | Uop(op, e) ->
      begin match op, typ e tenv with
      | Not, TBool -> TBool
      | Minus, TInt -> TInt
      | Fst, TPair(t1, _) -> t1
      | Snd, TPair(_, t2) -> t2
      | _ -> failwith "type error: unop"
      end
    | Cstr(c, args) ->
      let (expected_args, struct_name) =
        try Env.find c senv
        with Not_found -> failwith ("type error: constructor not found " ^ c)
      in
      if List.length args <> List.length expected_args then
        failwith "type error: wrong number of arguments"
      else
        let arg_types = List.map (fun arg -> typ arg tenv) args in
        if List.for_all2 (=) arg_types expected_args then
          TStruct struct_name
        else
          failwith "type error: argument type mismatch"
    | Match(e, cases) ->
      let expr_type = typ e tenv in
      let case_type =
        match cases with
        | [] -> failwith "type error: empty match cases"
        | (pattern, branch_expr) :: rest_cases ->
          let first_case_type = typ_case expr_type pattern branch_expr tenv in
          List.fold_left (fun acc_type (pattern, branch_expr) ->
            let current_case_type = typ_case expr_type pattern branch_expr tenv in
            if acc_type = current_case_type then acc_type
            else failwith "type error: match branches must have the same type"
          ) first_case_type rest_cases
      in case_type
  and typ_case expr_type pattern branch_expr tenv =
    let tenv' = type_pattern pattern expr_type tenv in
    typ branch_expr tenv'
  and type_pattern pattern expected_type tenv = match pattern with
    | PVar x -> Env.add x expected_type tenv
    | PCstr(c, sub_patterns) ->
      let (arg_types, result_type) =
        try Env.find c senv
        with Not_found -> failwith ("type error: unknown constructor in pattern " ^ c)
      in
      if result_type <> expected_type then
        failwith "type error: constructor pattern type mismatch"
      else if List.length arg_types <> List.length sub_patterns then
        failwith "type error: wrong number of constructor pattern arguments"
      else
        List.fold_left2
          (fun tenv sub_pattern arg_type ->
            type_pattern sub_pattern arg_type tenv)
          tenv sub_patterns arg_types
  in
  typ e Env.empty
  
let typ_prog p =
  let senv = List.fold_left (fun acc (struct_name, constructors) ->
    List.fold_left (fun acc (cstr_name, arg_types) ->
      Env.add cstr_name (arg_types, struct_name) acc
    ) acc constructors
  ) Env.empty p.typs in
  typ_expr p.code senv
  
