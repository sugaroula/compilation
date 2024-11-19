
open Imp
open Nimp

(* Sort intervals by start time and end time *)
let sort_intervals intervals =
  List.sort (fun (_, start1, _) (_, start2, _) -> compare start1 start2)
    (List.sort (fun (_, _, end1) (_, _, end2) -> compare end1 end2) intervals)

(* Insert interval into active list maintaining order by end time *)
let rec insert_active interval active =
  match active with
  | [] -> [interval]
  | i :: rest ->
    let (_, _, end_i) = i in
    let (_, _, end_interval) = interval in
    if end_i < end_interval then i :: insert_active interval rest
    else interval :: active

(* Linear scan register allocation *)
let lscan_alloc nb_regs fdef =
  let live_intervals = Liveness.liveness_intervals_from_liveness fdef in
  let alloc = Hashtbl.create (List.length fdef.locals) in
  let active = ref [] in
  let free = ref (List.init nb_regs (fun i -> i)) in
  let r_max = ref (-1) in
  let spill_count = ref 0 in

  let rec expire_old_intervals timestamp =
    active := List.filter (fun (_, _, end_time) -> end_time >= timestamp) !active
  in

  List.iter (fun (var, start_time, end_time) ->
      expire_old_intervals start_time;

      if !free <> [] then
        let reg = List.hd !free in
        free := List.tl !free;
        r_max := max !r_max reg;
        Hashtbl.add alloc var reg;
        active := insert_active (var, start_time, end_time) !active
      else
        (Hashtbl.add alloc var (-1); incr spill_count)
    ) (sort_intervals live_intervals);

  alloc, !r_max, !spill_count
