open Miniml
open Interpreter

let () =
  (* Unary Operators *)
  assert (eval (Uop(Minus, Int 42)) Env.empty = VInt (-42));
  assert (eval (Uop(Not, Bool false)) Env.empty = VBool true);

  (* Binary Operators *)
  assert (eval (Bop(Add, Int 1, Int 2)) Env.empty = VInt 3);
  assert (eval (Bop(And, Bool true, Bool false)) Env.empty = VBool false);

  (* Pairs and Projections *)
  let pair = Pair(Int 1, Bool true) in
  assert (eval (Uop(Fst, pair)) Env.empty = VInt 1);
  assert (eval (Uop(Snd, pair)) Env.empty = VBool true);

  (* Constructors *)
  assert (eval (Constr("N", [Int 1; Int 2])) Env.empty = VCstr("N", [VInt 1; VInt 2]));
  assert (eval (Constr("E", [])) Env.empty = VCstr("E", []));

  (* Pattern Matching *)
  let match_expr = Match(
    Constr("N", [Int 1; Int 2]),
    [
      (PCstr("E", []), Int 0);
      (PCstr("N", [PVar "x"; PVar "y"]), Bop(Add, Var "x", Var "y"))
    ]
  ) in
  assert (eval match_expr Env.empty = VInt 3);

  Printf.printf "All tests passed!\n"
