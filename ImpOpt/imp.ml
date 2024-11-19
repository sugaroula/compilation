(**
   Abstract syntax for the IMP language.
 *)

type binop = Add | Mul | Lt

type expression =
  | Cst   of int
  | Bool  of bool
  | Var   of string
  | Binop of binop * expression * expression
  | Call  of string * expression list

type instruction =
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
   An interpreter for IMP.
 *)

type value =
  | VInt of int
  | VBool of bool
  | Undef

exception EReturn of value

let exec_prog prog arg =
  let global_env = Hashtbl.create 16 in
  List.iter (fun id -> Hashtbl.add global_env id Undef) prog.globals;

  let rec exec_call f args =
    let fdef = List.find (fun fdef -> fdef.name = f) prog.functions in
    let local_env = Hashtbl.create 16 in
    List.iter2 (fun id arg -> Hashtbl.add local_env id arg) fdef.params args;
    List.iter (fun id -> Hashtbl.add local_env id Undef) fdef.locals;

    let rec eval_int e = match eval_expr e with
      | VInt n -> n
      | _ -> failwith "not an int"
    and eval_bool e = match eval_expr e with
      | VBool b -> b
      | _ -> failwith "not a boolean"
    and eval_expr = function
      | Cst n -> VInt n
      | Bool b -> VBool b
      | Var id -> begin
          match Hashtbl.find_opt local_env id with
          | Some v -> v
          | None -> Hashtbl.find global_env id
        end
      | Binop(op, e1, e2) ->
         let n1 = eval_int e1 in
         let n2 = eval_int e2 in
         begin match op with
           | Add -> VInt (n1 + n2)
           | Mul -> VInt (n1 * n2)
           | Lt  -> VBool (n1 < n2)
         end
      | Call(f, args) ->
         exec_call f (List.map eval_expr args)
    in

    let rec exec_seq s =
      List.iter exec_instr s

    and exec_instr = function
      | Putchar e -> print_char (char_of_int (eval_int e))
      | Set(id, e) ->
         let v = eval_expr e in
         if Hashtbl.mem local_env id then
           Hashtbl.replace local_env id v
         else
           Hashtbl.replace global_env id v
      | If(e, s1, s2) ->
         if eval_bool e then
           exec_seq s1
         else
           exec_seq s2
      | While(e, s) as i ->
         if eval_bool e then
           (exec_seq s; exec_instr i)
      | Return e -> raise (EReturn(eval_expr e))
      | Expr e -> ignore (eval_expr e)

    in

    try
      exec_seq fdef.code; Undef
    with
      EReturn v -> v
    
  in

  exec_call "main" [arg]
