type tree = E | N of tree * tree
type tag = A of int | B of bool

let is_int (t: tag) = match t with
  | A(n) -> true
  | B(b) -> false
in
let get_int (t: tag) = match t with
  | A(n) -> n
  | B(b) -> if b then 1 else 0
in

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
