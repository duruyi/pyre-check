(** Copyright (c) 2016-present, Facebook, Inc.

    This source code is licensed under the MIT license found in the
    LICENSE file in the root directory of this source tree. *)


open OUnit2
open Service
open EnvironmentSharedMemory


let test_decodable _ =
  let assert_decode prefix key value expected =
    let key = Prefix.make_key prefix key in
    assert_equal
      (Decodable.decode ~key ~value)
      (Ok expected)
  in
  assert_decode
    EdgeValue.prefix
    (IntKey.to_string 1234)
    (Marshal.to_string [] [Marshal.Closures]) (OrderEdges.Decoded (1234, []));
  assert_decode
    BackedgeValue.prefix
    (IntKey.to_string 1234)
    (Marshal.to_string [] [Marshal.Closures]) (OrderBackedges.Decoded (1234, []));
  assert_equal
    (Error `Malformed_key)
    (Decodable.decode ~key:"" ~value:(Marshal.to_string [] [Marshal.Closures]));
  let unregistered_prefix = Prefix.make () in
  assert_equal
    (Error `Unknown_type)
    (Decodable.decode
       ~key:(Prefix.make_key unregistered_prefix "")
       ~value:(Marshal.to_string [] [Marshal.Closures]))


let () =
  "decodable">:::[
    "decodable">::test_decodable;
  ]
  |> Test.run
