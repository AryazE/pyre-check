(*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 *)

open Core
open Result

type taint_kind =
  | Named
  | Parametric

type source_or_sink = {
  name: string;
  kind: taint_kind;
}

let parse_source ~allowed ?subkind name =
  match
    List.find allowed ~f:(fun { name = source_name; _ } -> String.equal source_name name), subkind
  with
  (* In order to support parsing parametric sources and sinks for rules, we allow matching
     parametric source kinds with no subkind. *)
  | Some _, None -> Ok (Sources.NamedSource name)
  | Some { kind = Parametric; _ }, Some subkind ->
      Ok (Sources.ParametricSource { source_name = name; subkind })
  | _ -> Error (Format.sprintf "Unsupported taint source `%s`" name)


let parse_sink ~allowed ?subkind name =
  match
    List.find allowed ~f:(fun { name = sink_name; _ } -> String.equal sink_name name), subkind
  with
  (* In order to support parsing parametric sources and sinks for rules, we allow matching
     parametric source kinds with no subkind. *)
  | Some _, None -> Ok (Sinks.NamedSink name)
  | Some { kind = Parametric; _ }, Some subkind ->
      Ok (Sinks.ParametricSink { sink_name = name; subkind })
  | _ -> Error (Format.sprintf "Unsupported taint sink `%s`" name)


let parse_tito ?subkind name =
  match name with
  | "LocalReturn" -> Ok Sinks.LocalReturn
  | update when String.is_prefix update ~prefix:"ParameterUpdate" ->
      let index = String.chop_prefix_exn update ~prefix:"ParameterUpdate" in
      Ok (ParameterUpdate (Int.of_string index))
  | "Transform" when Option.is_some subkind ->
      Ok
        (Sinks.Transform
           {
             local =
               {
                 TaintTransforms.empty with
                 ordered = [TaintTransform.Named (Option.value_exn subkind)];
               };
             global = TaintTransforms.empty;
             base = Sinks.LocalReturn;
           })
  | name -> Error (Format.sprintf "Unsupported taint in taint out specification `%s`" name)
