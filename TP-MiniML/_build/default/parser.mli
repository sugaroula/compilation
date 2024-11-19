
(* The type of tokens. *)

type token = 
  | WITH
  | TYPE
  | TINT
  | THEN
  | TBOOL
  | STAR
  | SND
  | SLASH
  | RPAR
  | REC
  | PLUS
  | OR
  | OF
  | NOT
  | NEQ
  | MOD
  | MINUS
  | MATCH
  | LT
  | LSR
  | LSL
  | LPAR
  | LET
  | LE
  | INT of (int)
  | IN
  | IF
  | IDENT of (string)
  | GT
  | GE
  | FUN
  | FST
  | EQ
  | EOF
  | ELSE
  | CSTR of (string)
  | COMMA
  | COLON
  | BOOL of (bool)
  | BAR
  | ARROW
  | AND

(* This exception is raised by the monolithic API functions. *)

exception Error

(* The monolithic API. *)

val program: (Lexing.lexbuf -> token) -> Lexing.lexbuf -> (Miniml.prog)
