%{

  open Lexing
  open Miniml

%}

%token PLUS MINUS STAR SLASH MOD
%token LSL LSR EQ NEQ LT LE GT GE
%token AND OR NOT

%token <int> INT
%token <bool> BOOL
%token <string> IDENT
%token <string> CSTR
%token FUN ARROW
%token LET REC IN
%token IF THEN ELSE
%token LPAR RPAR
%token COLON
%token TINT TBOOL 
%token TYPE OF BAR
%token MATCH WITH
%token FST SND
%token COMMA
%token EOF

%nonassoc IN ARROW CSTR
%nonassoc ELSE BAR
%left AND OR
%left LT LE GT GE EQ NEQ
%left PLUS MINUS
%left STAR SLASH MOD
%left LSL LSR
%nonassoc FST SND
%nonassoc LPAR IDENT INT BOOL

%start program
%type <Miniml.prog> program

%%

program:
| typs=list(type_def) code=expression EOF { {typs; code} }
;

simple_ty:
| TINT { TInt }
| TBOOL { TBool }
| id=IDENT { TStruct(id) }
| LPAR alpha=ty RPAR { alpha }
;

ty:
| alpha=simple_ty { alpha }
| alpha=ty ARROW beta=ty { TFun(alpha, beta) }
| alpha=ty STAR beta=ty { TPair(alpha, beta) }
;

typed_ident:
| LPAR x=IDENT COLON alpha=ty RPAR { (x, alpha) }
;

type_def:
| TYPE id=IDENT EQ cstrs=separated_nonempty_list(BAR, cstr_def) { (id, cstrs) }
;

cstr_def:
| c=CSTR { (c, []) }
| c=CSTR OF targs=separated_nonempty_list(STAR, simple_ty) { (c, targs) }
;

simple_expression:
| n=INT { Int(n) }
| b=BOOL { Bool(b) }
| id=IDENT { Var(id) }
| LPAR e=expression RPAR { e }
;

expression:
| e=simple_expression { e }
| op=unop e=simple_expression { Uop(op, e) }
| e1=expression op=binop e2=expression { Bop(op, e1, e2) }
| LPAR e1=expression COMMA e2=expression RPAR { Bop(Pair, e1, e2) }
| FST e=expression { Uop(Fst, e) }
| SND e=expression { Uop(Snd, e) }
| e1=expression e2=simple_expression { App(e1, e2) }
| FUN tid=typed_ident ARROW e=expression { let x,t = tid in Fun(x, t, e) }
| IF e1=expression THEN e2=expression ELSE e3=expression { If(e1, e2, e3) }
| c=CSTR { Cstr(c, []) }
| c=CSTR LPAR args=separated_list(COMMA, expression) RPAR { Cstr(c, args) }
/* | MATCH e=expression WITH cases=nonempty_list(case) { Match(e, cases) } */
| MATCH e=expression WITH cases=cases { Match(e, cases) }
(* Let/Letrec intègre sucre pour les fonctions *)
| LET f=IDENT txs=list(typed_ident) EQ e1=expression IN e2=expression
    { Let(f, mk_fun txs e1, e2) }
| LET REC f=IDENT txs=list(typed_ident) COLON alpha=ty EQ e1=expression IN e2=expression
    { Let(f, Fix(f, mk_fun_type txs alpha, mk_fun txs e1), e2) }
;

cases:
| BAR p=pattern ARROW e=expression { (p, e) :: [] }
| BAR p=pattern ARROW e=expression cases=cases { (p, e) :: cases }
;

pattern:
| id=IDENT { PVar id }
| c=CSTR { PCstr(c, []) }
| c=CSTR LPAR pargs=separated_list(COMMA, pattern) RPAR { PCstr(c, pargs) }
;

%inline unop:
| MINUS { Minus }
| NOT { Not }
;

%inline binop:
| PLUS { Add }
| MINUS { Sub }
| STAR { Mul }
| SLASH { Div }
| MOD { Rem }
| LSL { Lsl }
| LSR { Lsr }
| EQ { Eq }
| NEQ { Neq }
| LT { Lt }
| LE { Le }
| GT { Gt }
| GE { Ge }
| AND { And }
| OR { Or }
;

