open Femtos

let test_mvar_basic_operations () =
  (* Test create and basic put/take *)
  let mvar = Sync.Mvar.create () in
  Printf.printf "Created empty MVar\n" ;

  (* Put a value into the MVar *)
  Sync.Mvar.put mvar 42 ;
  Printf.printf "Put value 42 into MVar\n" ;

  (* Take the value from the MVar *)
  let value = Sync.Mvar.take mvar in
  assert (value = 42) ;
  Printf.printf "Took value %d from MVar\n" value ;

  Printf.printf "MVar basic operations test passed\n"

let test_mvar_create_full () =
  (* Test create_full *)
  let mvar = Sync.Mvar.create_full "hello" in
  Printf.printf "Created MVar with initial value\n" ;

  (* Take the initial value *)
  let value = Sync.Mvar.take mvar in
  assert (value = "hello") ;
  Printf.printf "Retrieved initial value from create_full: %s\n" value ;

  (* Put a new value *)
  Sync.Mvar.put mvar "world" ;
  Printf.printf "Put new value into MVar\n" ;

  (* Take the new value *)
  let new_value = Sync.Mvar.take mvar in
  assert (new_value = "world") ;
  Printf.printf "Retrieved new value: %s\n" new_value ;

  Printf.printf "MVar create_full test passed\n"

let test_mvar_multiple_operations () =
  let mvar = Sync.Mvar.create () in

  (* Sequence of put/take operations *)
  let values = [ 1; 2; 3; 4; 5 ] in

  List.iter
    (fun v ->
      Sync.Mvar.put mvar v ;
      let taken = Sync.Mvar.take mvar in
      assert (taken = v) ;
      Printf.printf "Put and took value: %d\n" v)
    values ;

  Printf.printf "MVar multiple operations test passed\n"

let test_mvar_blocking_operations () =
  Printf.printf "Testing MVar blocking operations with FIFO scheduler...\n" ;

  let main () =
    let mvar = Sync.Mvar.create () in
    let results = ref [] in

    (* Start a consumer that will block on empty MVar *)
    Femtos_mux.Fifo.fork (fun () ->
      Printf.printf "Consumer: Attempting to take from empty MVar...\n" ;
      let value = Sync.Mvar.take mvar in
      Printf.printf "Consumer: Successfully took value %d\n" value ;
      results := value :: !results
    ) ;

    (* Start a producer that will provide a value *)
    Femtos_mux.Fifo.fork (fun () ->
      Printf.printf "Producer: Yielding to let consumer start...\n" ;
      Femtos_mux.Fifo.yield () ;
      Printf.printf "Producer: Putting value 555 into MVar\n" ;
      Sync.Mvar.put mvar 555 ;
      Printf.printf "Producer: Value put successfully\n"
    ) ;

    (* Start another producer that will block on full MVar *)
    Femtos_mux.Fifo.fork (fun () ->
      Printf.printf "Producer2: Yielding to let first operations complete...\n" ;
      Femtos_mux.Fifo.yield () ;
      Femtos_mux.Fifo.yield () ;
      Printf.printf "Producer2: Putting value 777 into MVar\n" ;
      Sync.Mvar.put mvar 777 ;
      Printf.printf "Producer2: Value put successfully\n"
    ) ;

    (* Another consumer *)
    Femtos_mux.Fifo.fork (fun () ->
      Printf.printf "Consumer2: Yielding to let producers work...\n" ;
      Femtos_mux.Fifo.yield () ;
      Femtos_mux.Fifo.yield () ;
      Femtos_mux.Fifo.yield () ;
      Printf.printf "Consumer2: Taking second value...\n" ;
      let value = Sync.Mvar.take mvar in
      Printf.printf "Consumer2: Successfully took value %d\n" value ;
      results := value :: !results
    ) ;

    Printf.printf "Main: All fibers started\n" ;
    Femtos_mux.Fifo.yield () ;

    Printf.printf "Main: Results received: [%s]\n"
      (String.concat "; " (List.map string_of_int (List.rev !results)))
  in

  Femtos_mux.Fifo.run main ;
  Printf.printf "MVar blocking operations test passed\n"

let () =
  test_mvar_basic_operations () ;
  test_mvar_create_full () ;
  test_mvar_multiple_operations () ;
  test_mvar_blocking_operations () ;
  Printf.printf "All MVar tests passed (including blocking operations with scheduler)!\n"
