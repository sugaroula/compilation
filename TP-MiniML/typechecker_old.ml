open Miniml

module Env = Map.Make(String)
(* typing environment for variables *)
type tenv = typ Env.t
(* typing environment for constructors *)
type senv = (typ list * string) Env.t
(* Env. find <constructor name> senv ===> (<argument types>, <name of constructed type>)
Env. find         "N"           senv ===> ([TStruct "treet"; TStruct "tree"], "tree")

type tree = E | N of tree * tree *)

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
    | Var(x) -> Env.find x tenv
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
      if typ e (Env.add x t tenv) = t then
        t
      else
        failwith "type error: fix"
    | Uop(op, e) ->
      begin match op, typ e tenv with
      | Not, TBool -> TBool
      | Minus, TInt -> TInt
      | Fst, TPair(t1, _) -> t1
      | Snd, TPair(_, t2) -> t2
      | _ -> failwith "type error: unop"
      end
    | Constr(c, args) ->
      begin match Env.find_opt c senv with
      | Some (expected_args, name_of_Tstruct) ->
        if List.length args <> List.length expected_args then 
          failwith "type error: wrong number of arguments"
        else
          List.iter2
            (fun arg expected_type ->
              if typ arg tenv <> expected_type then
                failwith "type error: argument type mismatch")
            args expected_args;
        TStruct name_of_Tstruct
      | None -> failwith "type error: constructor not found"
      end
    | Match(e, cases) ->
      let t = typ e tenv in
      let case_type =
        List.fold_left (fun acc (pat, body) ->
          let pat_env, pat_t = typ_pattern pat senv t in
          if pat_t <> t then
            failwith "type error: pattern type mismatch";
          let body_t = typ body pat_env in
          match acc with
          | None -> Some body_t
          | Some t_acc when t_acc = body_t -> Some t_acc
          | _ -> failwith "type error: case body type mismatch")
          None cases
      in
      (match case_type with
      | Some t -> t
      | None -> failwith "type error: no cases found")
    | _ -> failwith "not implemented"

  and typ_pattern pat senv t =
    match pat with
    | PVar x -> (Env.singleton x t, t)
    | PPair(p1, p2) ->
      let tenv1, t1 = typ_pattern p1 senv (fst_type t) in
      let tenv2, t2 = typ_pattern p2 senv (snd_type t) in
      (Env.union (fun _ _ _ -> failwith "Duplicate variable in pattern") tenv1 tenv2, TPair(t1, t2))
    | PCstr(c, args) ->
      (match Env.find_opt c senv with
      | Some (expected_args, result_type) ->
        if result_type <> t then
          failwith "type error: pattern result type mismatch";
        let arg_envs, arg_types =
          List.split (List.map2 (typ_pattern) args expected_args)
        in
        (List.fold_left Env.union Env.empty arg_envs, TStruct result_type)
      | None -> failwith "type error: constructor not found in pattern")
    | PWildcard -> (Env.empty, t)
  in
  typ e Env.empty

let typ_prog p =
  let senv = Env.empty (* Replace with an actual initialization! *) in
  typ_expr p.code senv
