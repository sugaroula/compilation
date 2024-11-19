
open Imp
open Nimp

(* sort by ascending lower bound, and sort equals by ascending upper bound *)
let sort_2 l =
  List.stable_sort (fun (_, l1, _) (_, l2, _) -> l1 - l2) l
let sort_3 l =
  List.stable_sort (fun (_, _, h1) (_, _, h2) -> h1 - h2) l
let sort_intervals l =
  sort_2 (sort_3 l)

(* insert interval [i] in active list [l]
   pre/post-condition: sorted by ascending upper bound *)
let rec insert_active i l =
  match l with
  | [] -> [i]
  | h :: t -> if snd (snd i) <= snd (snd h) then i :: l else h :: insert_active i t

(* allocate registers for variables *)
let linear_scan intervals =
  let active = ref [] in
  let available = ref ["$s0"; "$s1"; "$s2"; "$s3"; "$s4"; "$s5"; "$s6"; "$s7"] in
  let alloc = Hashtbl.create 16 in

  let expire_old_intervals current_time =
    active := List.filter (fun (_, _, b) -> b >= current_time) !active;
    List.iter (fun (v, reg, _) -> available := reg :: !available) !active
  in

  List.iter (fun (x, a, b) ->
    expire_old_intervals a;
    if !available <> [] then
      let reg = List.hd !available in
      available := List.tl !available;
      Hashtbl.add alloc x reg;
      active := insert_active (x, reg, b) !active
    else
      (* Spill logic *)
      Hashtbl.add alloc x "spill"
  ) (sort_intervals intervals);
  alloc
