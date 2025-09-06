open Femtos_sync

let test_mvar_basic_operations () =
  (* Test create and basic put/take *)
  let mvar = Mvar.create () in
  Printf.printf "Created empty MVar\n" ;

  (* Put a value into the MVar *)
  Mvar.put mvar 42 ;
  Printf.printf "Put value 42 into MVar\n" ;

  (* Take the value from the MVar *)
  let value = Mvar.take mvar in
  assert (value = 42) ;
  Printf.printf "Took value %d from MVar\n" value ;

  Printf.printf "MVar basic operations test passed\n"

let test_mvar_create_full () =
  (* Test create_full *)
  let mvar = Mvar.create_full "hello" in
  Printf.printf "Created MVar with initial value\n" ;

  (* Take the initial value *)
  let value = Mvar.take mvar in
  assert (value = "hello") ;
  Printf.printf "Retrieved initial value from create_full: %s\n" value ;

  (* Put a new value *)
  Mvar.put mvar "world" ;
  Printf.printf "Put new value into MVar\n" ;

  (* Take the new value *)
  let new_value = Mvar.take mvar in
  assert (new_value = "world") ;
  Printf.printf "Retrieved new value: %s\n" new_value ;

  Printf.printf "MVar create_full test passed\n"

let test_mvar_multiple_operations () =
  let mvar = Mvar.create () in

  (* Sequence of put/take operations *)
  let values = [1; 2; 3; 4; 5] in

  List.iter (fun v ->
    Mvar.put mvar v ;
    let taken = Mvar.take mvar in
    assert (taken = v) ;
    Printf.printf "Put and took value: %d\n" v
  ) values ;

  Printf.printf "MVar multiple operations test passed\n"

let () =
  test_mvar_basic_operations () ;
  test_mvar_create_full () ;
  test_mvar_multiple_operations () ;
  Printf.printf "All MVar tests passed (basic interface only)!\n"
