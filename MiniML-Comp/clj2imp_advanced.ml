
open Clj
open Imp

module STbl = Map.Make(String)

let tr_var v env = match v with
  | Clj.Name(x) -> Imp.(if STbl.mem x env then Var(STbl.find x env) else Var x)
  | Clj.CVar(n) -> Imp.(array_get (Var "closure") (Int n))

let rec tr_expr (e: Clj.expression) (env: string STbl.t):
    Imp.sequence * Imp.expression =
  let cpt = ref (-1) in
  let vars = ref [] in
  let new_var id =
    incr cpt;
    let v = Printf.sprintf "%s_%i" id !cpt in
    vars := v :: !vars;
    v
  in
  let rec translate (e: Clj.expression) (env: string STbl.t):
      Imp.sequence * Imp.expression =
    match e with
    | Clj.Int(n) -> [], Imp.Int(n)
    | Clj.Bool(b) -> [], Imp.Bool(b)
    | Clj.Var(v) -> [], tr_var v env
    | Clj.Binop(op, e1, e2) ->
      let is1, te1 = translate e1 env in
      let is2, te2 = translate e2 env in
      is1 @ is2, Imp.Binop(op, te1, te2)
    | Clj.Unop(Fst, e1) ->
      let is1, te1 = translate e1 env in
      is1, Imp.Deref(Imp.Binop(Add, te1, Imp.Int 4))
    | Clj.Unop(Snd, e1) ->
      let is1, te1 = translate e1 env in
      is1, Imp.Deref(Imp.Binop(Add, te1, Imp.Int 8))
    | Clj.Unop(op, e1) ->
      let is1, te1 = translate e1 env in
      is1, Imp.Unop(op, te1)
    | Clj.Let(x, e1, e2) ->
      let lv = new_var x in
      let is1, t1 = translate e1 env in
      let is2, t2 = translate e2 (STbl.add x lv env) in
      Imp.(is1 @ [Set(lv, t1)] @ is2, t2)
    | Clj.Match(e, cases) ->
      let is1, te1 = translate e env in
      let res_var = new_var "match" in
      let id_var = new_var "case_id" in
      let is2 = [Imp.Set(id_var, Imp.array_get te1 (Imp.Int 1))] in
      let rec compile_cases = function
        | [] -> []
        | ((ctor, args), body)::rest ->
          let matched_id = ctor in
          let bind_vars = List.mapi (fun i x -> Imp.Set(x, Imp.array_get te1 (Imp.Int (i + 2)))) args in
          let is_body, te_body = translate body env in
          Imp.If(Imp.Binop(Eq, Imp.Var id_var, Imp.Int matched_id),
                 bind_vars @ is_body @ [Imp.Set(res_var, te_body)],
                 compile_cases rest)
      in
      is1 @ is2 @ compile_cases cases, Imp.Var res_var
    | _ -> failwith "Not yet implemented"
  in
  let seq, expr = translate e env in
  seq, expr

let tr_fdef fdef =
  let env =
    let x = Clj.(fdef.param) in
    STbl.add x ("param_" ^ x) STbl.empty
  in
  let seq, te, locals = tr_expr Clj.(fdef.body) env in
  Imp.({
    name = Clj.(fdef.name);
    code = seq @ [Return te];
    params = ["param_" ^ Clj.(fdef.param); "closure"];
    locals;
  })

let translate_program prog =
  let functions = List.map tr_fdef Clj.(prog.functions) in
  let seq, te, globals = tr_expr Clj.(prog.code) STbl.empty in
  let main = Imp.(seq @ [Expr(Call("print_int", [te]))]) in
  Imp.({main; functions; globals})
