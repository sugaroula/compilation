open Miniml

module Env = Map.Make(String)

(* Initialize constructor typing environment *)
let senv =
  Env.add "N" ([TInt; TInt], "tree") @@
  Env.add "E" ([], "tree") Env.empty

(* Test suite *)
let () =
  (* Unary operators *)
  assert (typ_expr (Uop(Minus, Int 42)) senv = TInt);
  assert (typ_expr (Uop(Not, Bool true)) senv = TBool);

  (* Binary operators *)
  assert (typ_expr (Bop(Add, Int 1, Int 2)) senv = TInt);
  assert (typ_expr (Bop(And, Bool true, Bool false)) senv = TBool);

  (* Pairs *)
  assert (typ_expr (Bop(Pair, Int 1, Bool true)) senv = TPair(TInt, TBool));

  (* Projections *)
  assert (typ_expr (Uop(Fst, Bop(Pair, Int 1, Bool true))) senv = TInt);
  assert (typ_expr (Uop(Snd, Bop(Pair, Int 1, Bool true))) senv = TBool);

  (* Constructors *)
  assert (typ_expr (Constr("E", [])) senv = TStruct "tree");
  assert (typ_expr (Constr("N", [Int 1; Int 2])) senv = TStruct "tree");

  (* Pattern Matching *)
  let expr = Match(
    Constr("N", [Int 1; Int 2]),
    [
      (PCstr("E", []), Int 0);
      (PCstr("N", [PVar "x"; PVar "y"]), Bop(Add, Var "x", Var "y"))
    ]
  ) in
  assert (typ_expr expr senv = TInt);

  (* Exhaustive pattern matching check *)
  let expr_non_exhaustive = Match(
    Constr("N", [Int 1; Int 2]),
    [
      (PCstr("E", []), Int 0)
      (* Missing case for "N" *)
    ]
  ) in
  try
    let _ = typ_expr expr_non_exhaustive senv in
    failwith "Non-exhaustive match did not raise an error"
  with Failure _ -> ();

  (* Nested Patterns (BONUS TASK) *)
  let nested_expr = Match(
    Constr("N", [Constr("N", [Int 1; Int 2]); Constr("E", [])]),
    [
      (PCstr("E", []), Int 0);
      (PCstr("N", [PCstr("N", [PVar "x"; PVar "y"]); PWildcard]), Bop(Add, Var "x", Var "y"))
    ]
  ) in
  assert (typ_expr nested_expr senv = TInt);

  Printf.printf "All tests passed!\n"
