let usage = "usage: ./minimlc file.ml"

let spec = []
  
let file =
    let file = ref None in
    let set_file s =
      if not (Filename.check_suffix s ".ml") then
        raise (Arg.Bad "no .ml extension");
      file := Some s
    in
    Arg.parse spec set_file usage;
    match !file with Some f -> f | None -> Arg.usage spec usage; exit 1

let () =
  let c  = open_in file in
  let lb = Lexing.from_channel c in
  let prog = Parser.program Lexer.token lb
  in
  close_in c;
  let progclj = Mini2clj.translate_program prog in
  let progimp = Clj2imp.translate_program progclj in
  let output_file = (Filename.chop_suffix file ".ml") ^ ".imp" in
  let out = open_out output_file in
  Imppp.pp_program progimp out;
  close_out out;
  exit 0
    
