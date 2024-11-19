(**
   Abstract syntax for the IMP language, with instructions numbered.
   It is assumed that every instruction in a given function body has
   a unique number.
 *)

type binop = Imp.binop
type expression = Imp.expression

type instruction = { nb: int; instr: instr }
and instr =
  | Putchar of expression
  | Set     of string * expression
  | If      of expression * sequence * sequence
  | While   of expression * sequence
  | Return  of expression
  | Expr    of expression
and sequence = instruction list

type function_def = {
    name: string;
    params: string list;
    locals: string list;
    code: sequence;
  }

type program = {
    globals: string list;
    functions: function_def list;
  }

(**
   Numbering and utility functions.
 *)

let rec max_instr i = match i.instr with
    | Putchar _ | Set _ | Expr _ | Return _ -> i.nb
    | While(_, is) -> max i.nb (max_instr_list is)
    | If(_, is1, is2) -> max i.nb (max (max_instr_list is1) (max_instr_list is2))
and max_instr_list = function
    | [] -> -1
    | i::l -> max (max_instr i) (max_instr_list l)

let from_imp_fdef fdef =
  (* Printf.printf "numbering %s..." Imp.(fdef.name); *)
  let cpt = ref (-1) in
  let new_lbl () = incr cpt; !cpt in
  let rec from_imp_instr = function
    | Imp.Putchar e -> { nb = new_lbl(); instr = Putchar(e) }
    | Imp.Set(x, e) -> { nb = new_lbl(); instr = Set(x, e) }
    | Imp.Expr e    -> { nb = new_lbl(); instr = Expr(e) }
    | Imp.Return e  -> { nb = new_lbl(); instr = Return(e) }
    | Imp.While(e, is1) -> 
       let nb = new_lbl() in
       { nb; instr = While(e, from_imp_list is1) }
    | Imp.If(e, is1, is2) -> 
       let nb = new_lbl() in
       { nb; instr = If(e, from_imp_list is1, from_imp_list is2) }
  and from_imp_list = function
    | []   -> []
    | i::l -> let i = from_imp_instr i in i :: from_imp_list l
  in
  let code = from_imp_list Imp.(fdef.code) in
  (* Printf.printf " ok, max %d\n" (max_instr_list code); *)
  { name = Imp.(fdef.name);
    code = code;
    params = Imp.(fdef.params);
    locals = Imp.(fdef.locals); }

let from_imp_program p =
  { globals = Imp.(p.globals);
    functions = List.map from_imp_fdef Imp.(p.functions) }
