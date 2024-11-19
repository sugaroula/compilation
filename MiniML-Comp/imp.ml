(**
   Extended abstract syntax for the IMP language.
   Added: pointers on data and on functions; more unary/binary operators.
 *)

type expression =
  | Int   of int
  | Bool  of bool
  | Var   of string
  | Unop  of Ops.unop * expression
  | Binop of Ops.binop * expression * expression
  | Call  of string * expression list
  (* pointers *)
  | Deref of expression (* read a memory address *)
  | Addr  of string     (* & -> gives the address of a variable,
                                used here to get function pointers *)
  | PCall of expression * expression list (* function call, by pointer *)
  | Sbrk  of expression (* primitive for heap extension *)
      
type instruction =
  | Putchar of expression
  | Set     of string * expression
  | If      of expression * sequence * sequence
  | While   of expression * sequence
  | Return  of expression
  | Expr    of expression
  (* pointers *)
  | Write   of expression * expression (* write a memory address *)
      
and sequence = instruction list

(* The abstract syntax contains no constructors for explicit handling arrays,
   but the following four functions provide macros that simulate arrays using
   simple pointer arithmetic *)
let array_access (a: expression) (i: expression): expression =
  (* compute the pointer to index  i  of the array  a  *)
  Binop(Ops.Add, a, Binop(Ops.Mul, i, Int 4))
let array_get (a: expression) (i: expression): expression =
  (* read operation  a[i]  *)
  Deref(array_access a i)
let array_set (a: expression) (i: expression) (e: expression): instruction =
  (* write operation  a[i] = e  *)
  Write(array_access a i, e)
let array_create (n: expression): expression =
  (* allocation of an array of size  n  *)
  Call("malloc", [Binop(Mul, n, Int 4)])
    
type function_def = {
  name: string;
  code: sequence;
  params: string list;
  locals: string list;
}
    
type program = {
  (* minor variation with respect to IMP:
     we introducea main sequence of instructions instead of requiring
     a function called  main  *)
  main: sequence;
  functions: function_def list;
  globals: string list;
}

(* Merge several programs (cheap way of including libraries) *)
let merge lib prog = {
  main = lib.main @ prog.main;
  functions = lib.functions @ prog.functions;
  globals = lib.globals @ prog.globals;
}
