(**************************************************************************)
(*                                                                        *)
(*  Copyright 2013 OCamlPro                                               *)
(*                                                                        *)
(*  All rights reserved.  This file is distributed under the terms of     *)
(*  the Lesser GNU Public License version 3.0.                            *)
(*                                                                        *)
(*  This software is distributed in the hope that it will be useful,      *)
(*  but WITHOUT ANY WARRANTY; without even the implied warranty of        *)
(*  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the         *)
(*  Lesser GNU General Public License for more details.                   *)
(*                                                                        *)
(**************************************************************************)

(** This module contains the run-time for the command-line ocp-index tool *)


open Cmdliner

let default_cmd =
  let doc = "Explore the interfaces of installed OCaml libraries." in
  Term.(ret (pure (fun _ -> `Help (`Pager, None)) $ IndexOptions.common_opts)),
  Term.info "ocp-index" ~version:"0.3.0" ~doc

let complete_cmd =
  let doc = "Complete identifiers starting with prefix $(docv)." in
  let t =
    Arg.(required & pos 0 (some string) None & info [] ~doc ~docv:"STRING")
  in
  let sexpr: bool Term.t =
    let doc = "Output the result as a s-expression." in
    Arg.(value & flag & info ["sexp"] ~doc)
  in
  let print_compl opts sexpr query =
    let fmt = Format.std_formatter in
    let results =
      LibIndex.complete
        opts.IndexOptions.lib_info
        ~filter:opts.IndexOptions.filter
        query
    in
    if sexpr then (
      Format.pp_print_string fmt "(\n";
      List.iter (fun info ->
          let (!) f x = f ?colorise:None x in
          Format.fprintf fmt "  (\"%a\"" !LibIndex.Format.path info;
          Format.fprintf fmt " (:name . \"%a\")" !LibIndex.Format.name info;
          Format.fprintf fmt " (:type . %S)" (LibIndex.Print.ty info);
          Format.fprintf fmt " (:kind . \"%a\")" !LibIndex.Format.kind info;
          (if Lazy.force info.LibIndex.doc <> None
           then Format.fprintf fmt " (:doc . %S)" (LibIndex.Print.doc info));
          Format.fprintf fmt ")\n"
        )
        results;
      Format.pp_print_string fmt ")\n"
    ) else
      List.iter (fun info ->
          LibIndex.Format.info
            ~colorise:(if opts.IndexOptions.color
                       then LibIndex.Format.color
                       else LibIndex.Format.no_color)
            fmt info;
          Format.pp_print_newline fmt ())
        results;
    Format.pp_print_flush fmt ()
  in
  let doc = "Print completions to stdout." in
  Term.(pure print_compl $ IndexOptions.common_opts $ sexpr $ t),
  Term.info "complete" ~doc

let type_cmd =
  let doc = "Print the type of OCaml identifier $(docv)." in
  let t =
    Arg.(required & pos 0 (some string) None & info [] ~doc ~docv:"STRING")
  in
  let print_ty opts query =
    try
      let id = LibIndex.get opts.IndexOptions.lib_info query in
      print_endline (LibIndex.Print.ty id)
    with Not_found -> exit 2
  in
  let doc = "Print the type of an identifier." in
  Term.(pure print_ty $ IndexOptions.common_opts $ t),
  Term.info "type" ~doc

let locate_cmd =
  let doc = "Get the location of definition of $(docv)." in
  let t =
    Arg.(required & pos 0 (some string) None & info [] ~doc ~docv:"STRING")
  in
  let interface: bool Term.t =
    let doc =
      "Lookup the interface instead of the implementation, if it exists" in
    Arg.(value & flag & info ["i";"interface"] ~doc)
  in
  let print_loc opts intf query =
    match LibIndex.get_all opts.IndexOptions.lib_info query with
    | [] -> exit 2
    | ids ->
        let loc_as_string id =
          LibIndex.Print.loc ?root:opts.IndexOptions.project_root ~intf id
        in
        List.iter (fun id -> print_endline (loc_as_string id)) ids
  in
  let doc = "Get the location where an identifier was defined." in
  Term.(pure print_loc $ IndexOptions.common_opts $ interface $ t),
  Term.info "locate" ~doc

let () =
  match Term.eval_choice default_cmd [complete_cmd; type_cmd; locate_cmd] with
  | `Error _ -> exit 1
  | _ -> exit 0
