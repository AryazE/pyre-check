(*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 *)

open Base
open OUnit2
open Test
open Ast.Expression
open Ast.Statement

let statements_location_insensitive_equal left right =
  List.compare Statement.location_insensitive_compare left right |> Int.equal 0


let statements_print_to_sexp statements =
  Sexp.to_string_hum ((List.sexp_of_t Statement.sexp_of_t) statements)


let assert_parsed ~expected text =
  match PyreErrpyParser.parse_module text with
  | Result.Error message ->
      let message = Format.sprintf "Unexpected parsing failure: %s" message in
      assert_failure message
  | Result.Ok actual ->
      assert_equal
        ~cmp:statements_location_insensitive_equal
        ~printer:statements_print_to_sexp
        expected
        actual


let assert_not_parsed text =
  match PyreErrpyParser.parse_module text with
  | Result.Ok _ ->
      let message = Format.asprintf "Unexpected parsing success of input: %s" text in
      assert_failure message
  | Result.Error _ -> ()


let test_pass_break_continue _ =
  let assert_parsed = assert_parsed in
  (*TODO: FIX In ERRPY: let assert_not_parsed = assert_not_parsed in*)
  assert_parsed "pass" ~expected:[+Statement.Pass];
  assert_parsed "break" ~expected:[+Statement.Break];
  assert_parsed "continue" ~expected:[+Statement.Continue];
  assert_parsed "pass\npass" ~expected:[+Statement.Pass; +Statement.Pass];
  (*TODO: FIX In ERRPY: assert_not_parsed "pass\n pass";*)
  assert_parsed
    "break\ncontinue\npass\n"
    ~expected:[+Statement.Break; +Statement.Continue; +Statement.Pass];
  ()


let test_global_nonlocal _ =
  let assert_parsed = assert_parsed in
  let assert_not_parsed = assert_not_parsed in
  assert_parsed "global a" ~expected:[+Statement.Global ["a"]];
  assert_parsed "global a, b" ~expected:[+Statement.Global ["a"; "b"]];
  assert_parsed "nonlocal a" ~expected:[+Statement.Nonlocal ["a"]];
  assert_parsed "nonlocal a, b" ~expected:[+Statement.Nonlocal ["a"; "b"]];

  assert_not_parsed "global";
  assert_not_parsed "nonlocal";
  ()


let test_expression_return_raise _ =
  let assert_parsed = assert_parsed in
  assert_parsed "a" ~expected:[+Statement.Expression !"a"];
  assert_parsed
    "a is b"
    ~expected:
      [
        +Statement.Expression
           (+Expression.ComparisonOperator
               { ComparisonOperator.left = !"a"; operator = ComparisonOperator.Is; right = !"b" });
      ];
  assert_parsed
    "foo(x)"
    ~expected:
      [
        +Statement.Expression
           (+Expression.Call
               { callee = !"foo"; arguments = [{ Call.Argument.name = None; value = !"x" }] });
      ];
  assert_parsed
    "return"
    ~expected:[+Statement.Return { Return.expression = None; is_implicit = false }];
  assert_parsed
    "return a"
    ~expected:[+Statement.Return { Return.expression = Some !"a"; is_implicit = false }];
  assert_parsed "raise" ~expected:[+Statement.Raise { Raise.expression = None; from = None }];
  assert_parsed "raise a" ~expected:[+Statement.Raise { Raise.expression = Some !"a"; from = None }];
  assert_parsed
    "raise a from b"
    ~expected:[+Statement.Raise { Raise.expression = Some !"a"; from = Some !"b" }];
  ()


let test_assert_delete _ =
  let assert_parsed = assert_parsed in
  let assert_not_parsed = assert_not_parsed in
  assert_parsed
    "assert a"
    ~expected:
      [+Statement.Assert { Assert.test = !"a"; message = None; origin = Assert.Origin.Assertion }];
  assert_parsed
    "assert a, b"
    ~expected:
      [
        +Statement.Assert
           { Assert.test = !"a"; message = Some !"b"; origin = Assert.Origin.Assertion };
      ];
  assert_parsed
    "assert (a, b)"
    ~expected:
      [
        +Statement.Assert
           {
             Assert.test = +Expression.Tuple [!"a"; !"b"];
             message = None;
             origin = Assert.Origin.Assertion;
           };
      ];
  assert_parsed
    "assert a is not None, 'b or c'"
    ~expected:
      [
        +Statement.Assert
           {
             Assert.test =
               +Expression.ComparisonOperator
                  {
                    ComparisonOperator.left = !"a";
                    operator = ComparisonOperator.IsNot;
                    right = +Expression.Constant Constant.NoneLiteral;
                  };
             message = Some (+Expression.Constant (Constant.String (StringLiteral.create "b or c")));
             origin = Assert.Origin.Assertion;
           };
      ];
  assert_parsed "del ()" ~expected:[+Statement.Delete [+Expression.Tuple []]];
  assert_parsed "del a" ~expected:[+Statement.Delete [!"a"]];
  assert_parsed "del (a)" ~expected:[+Statement.Delete [!"a"]];
  assert_parsed "del a, b" ~expected:[+Statement.Delete [!"a"; !"b"]];
  assert_parsed "del (a, b)" ~expected:[+Statement.Delete [+Expression.Tuple [!"a"; !"b"]]];

  assert_not_parsed "assert";
  assert_not_parsed "del";
  ()


let () =
  "parse_statements"
  >::: [
         "pass_break_continue" >:: test_pass_break_continue;
         "global_nonlocal" >:: test_global_nonlocal;
         "expression_return_raise" >:: test_expression_return_raise;
         "assert_delete" >:: test_assert_delete;
         (*"import" >:: test_import;*)
         (*"for_while_if" >:: test_for_while_if;*)
         (*"try" >:: test_try;*)
         (*"with" >:: test_with;*)
         (*"assign" >:: test_assign;*)
         (*"define" >:: test_define;*)
         (*"class" >:: test_class;*)
         (*TODO: FIX In ERRPY: "match" >:: test_match;*)
       ]
  |> Test.run
