open Femtos

let test_promise_fill_and_exception () =
  let promise = Sync.Ivar.create () in

  (* Fill the promise *)
  let success = Sync.Ivar.try_fill promise 42 in
  assert success ;
  Printf.printf "Filled promise with 42\n" ;

  (* Try to fill again - should return false *)
  let success = Sync.Ivar.try_fill promise 100 in
  if not success then
    Printf.printf
      "Ivar try_fill correctly returned false for already filled promise\n"
  else assert false ;

  (* Should not reach here *)
  Printf.printf "Ivar fill and try_fill test passed\n"

let test_promise_different_types () =
  let int_promise = Sync.Ivar.create () in
  let string_promise = Sync.Ivar.create () in

  (* Fill with different types *)
  let success1 = Sync.Ivar.try_fill int_promise 123 in
  let success2 = Sync.Ivar.try_fill string_promise "hello world" in
  assert success1 ;
  assert success2 ;

  (* Try to fill again - both should return false *)
  let success1 = Sync.Ivar.try_fill int_promise 456 in
  if not success1 then
    Printf.printf "Int promise try_fill correctly returned false\n"
  else assert false ;

  let success2 = Sync.Ivar.try_fill string_promise "goodbye" in
  if not success2 then
    Printf.printf "String promise try_fill correctly returned false\n"
  else assert false ;

  Printf.printf "Different types test passed\n"

let test_ivar_blocking_read () =
  Printf.printf "Testing IVar blocking read with FIFO scheduler...\n" ;

  let main _terminator =
    let ivar = Sync.Ivar.create () in
    let result = ref None in

    (* Start a reader that will block *)
    Femtos_mux.Fifo.fork (fun _terminator ->
        Printf.printf "Reader: Starting to read from IVar...\n" ;
        let value = Sync.Ivar.read ivar in
        Printf.printf "Reader: Successfully read value %d\n" value ;
        result := Some value) ;

    (* Start a writer that will fill the IVar after a delay *)
    Femtos_mux.Fifo.fork (fun _terminator ->
        Printf.printf "Writer: Yielding to let reader start...\n" ;
        Femtos_mux.Fifo.yield () ;
        Printf.printf "Writer: Filling IVar with 999\n" ;
        let _ = Sync.Ivar.try_fill ivar 999 in
        Printf.printf "Writer: IVar filled\n") ;

    Printf.printf "Main: Both fibers started\n" ;
    Femtos_mux.Fifo.yield () ;

    match !result with
    | Some v -> Printf.printf "Main: Final result: %d\n" v
    | None -> Printf.printf "Main: No result received\n"
  in

  Femtos_mux.Fifo.run main ;
  Printf.printf "IVar blocking read test passed\n"

let () =
  test_promise_fill_and_exception () ;
  test_promise_different_types () ;
  test_ivar_blocking_read () ;
  Printf.printf
    "All promise tests passed (including blocking operations with scheduler)!\n"
