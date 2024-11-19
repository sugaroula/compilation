
open Miniml
open Clj

(* Module for sets of variables *)
module VSet = Set.Make(String)

let translate_program (p: Miniml.prog) =
  let fdefs = ref [] in
  let new_fname =
    let cpt = ref (-1) in
    fun () -> incr cpt; Printf.sprintf "fun_%i" !cpt
  in

  let rec tr_expr (e: Miniml.expr) (bvars: VSet.t): Clj.expression * (string * int) list =
    let cvars = ref [] in
    let new_cvar =
      let cpt = ref 0 in
      fun x -> incr cpt; cvars := (x, !cpt) :: !cvars; !cpt
    in

    let rec convert_var x bvars =
      Clj.(if VSet.mem x bvars then Name(x)
           else if List.mem_assoc x !cvars then CVar(List.assoc x !cvars)
           else CVar(new_cvar x))
    in

    let rec crawl (e: Miniml.expr) bvars: Clj.expression =
      match e with
      | Int(n) -> Int(n)
      | Bool(b) -> Bool(b)
      | Var(x) -> Var(convert_var x bvars)
      | Bop(op, e1, e2) -> Binop(op, crawl e1 bvars, crawl e2 bvars)
      | Uop(Fst, e1) -> Unop(Fst, crawl e1 bvars)
      | Uop(Snd, e1) -> Unop(Snd, crawl e1 bvars)
      | Uop(op, e1) -> Unop(op, crawl e1 bvars)
      | Let(x, e1, e2) -> Let(x, crawl e1 bvars, crawl e2 (VSet.add x bvars))
      | If(e1, e2, e3) -> If(crawl e1 bvars, crawl e2 bvars, crawl e3 bvars)
      | Fun(x, _, e) ->
        let fname = new_fname () in
        let body, vars = tr_expr e (VSet.add x VSet.empty) in
        let nfdef = Clj.{name = fname; body; param = x} in
        fdefs := nfdef :: !fdefs;
        let vl = List.sort (fun (_, i) (_, j) -> compare i j) vars in
        MkClj(fname, List.map (fun (v, _) -> convert_var v bvars) vl)
      | App(e1, e2) -> App(crawl e1 bvars, crawl e2 bvars)
      | Fix(x, _, e) -> Fix(x, crawl e (VSet.add x bvars))
      | Cstr(ctor, args) -> Cstr(ctor, List.map (fun arg -> crawl arg bvars) args)
      | Match(e, cases) ->
        let check_no_duplicate_vars pattern =
          let rec collect_vars (vars, seen) = function
            | [] -> vars, seen
            | x::xs ->
              if List.mem x seen then failwith "Duplicate variable in pattern"
              else collect_vars (x::vars, x::seen) xs
          in
          collect_vars ([], []) pattern
        in
        Match(crawl e bvars,
              List.map (fun ((ctor, vars), expr) ->
                let vars, _ = check_no_duplicate_vars vars in
                (ctor, vars), crawl expr (List.fold_right VSet.add vars bvars))
              cases)
    in
    let te = crawl e bvars in
    te, !cvars
  in

  let code, cvars = tr_expr p.code VSet.empty in
  assert (cvars = []);
  Clj.({
    functions = !fdefs;
    code;
  })
