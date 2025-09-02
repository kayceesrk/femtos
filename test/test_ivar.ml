open Sync

let test_promise_fill_and_exception () =
  let promise = Ivar.create () in

  (* Fill the promise *)
  let success = Ivar.try_fill promise 42 in
  assert success ;
  Printf.printf "Filled promise with 42\n" ;

  (* Try to fill again - should return false *)
  let success = Ivar.try_fill promise 100 in
  if not success then
    Printf.printf "Ivar try_fill correctly returned false for already filled promise\n"
  else
    assert false ; (* Should not reach here *)

  Printf.printf "Ivar fill and try_fill test passed\n"

let test_promise_different_types () =
  let int_promise = Ivar.create () in
  let string_promise = Ivar.create () in

  (* Fill with different types *)
  let success1 = Ivar.try_fill int_promise 123 in
  let success2 = Ivar.try_fill string_promise "hello world" in
  assert success1;
  assert success2;

  (* Try to fill again - both should return false *)
  let success1 = Ivar.try_fill int_promise 456 in
  if not success1 then
    Printf.printf "Int promise try_fill correctly returned false\n"
  else
    assert false;

  let success2 = Ivar.try_fill string_promise "goodbye" in
  if not success2 then
    Printf.printf "String promise try_fill correctly returned false\n"
  else
    assert false;

  Printf.printf "Different types test passed\n"

let () =
  test_promise_fill_and_exception () ;
  test_promise_different_types () ;
  Printf.printf
    "All promise tests passed (without await - requires effect handler)!\n"
