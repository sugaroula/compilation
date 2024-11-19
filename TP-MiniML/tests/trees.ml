type tree = E | N of tree * tree

let is_empty (t: tree) = match t with
  | E -> true
  | N(t1, t2) -> false
in
let is_singleton (t: tree) = match t with
  | E -> false
  | N(t1, t2) -> if is_empty t1 then is_empty t2 else false
in
let rec size (t: tree): int = match t with
  | E -> 1
  | N(t1, t2) -> 1 + (size t1) + (size t2)
in

let max (x: int) (y: int) = if x < y then y else x in
let rec height (t: tree): int = match t with
  | E -> 0
  | N(t1, t2) -> 1 + max (height t1) (height t2)
in

let t = N(E, N(N(E, E), E)) in
height t
