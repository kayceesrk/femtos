open Sync

let test_mvar_create_and_state () =
  let empty_mvar = Mvar.create () in
  assert (Mvar.is_empty empty_mvar) ;
  assert (not (Mvar.is_full empty_mvar)) ;

  let full_mvar = Mvar.create_full 42 in
  assert (not (Mvar.is_empty full_mvar)) ;
  assert (Mvar.is_full full_mvar) ;

  Printf.printf "MVar create and state test passed\n"

let test_mvar_try_operations () =
  let mvar = Mvar.create () in

  (* Try to take from empty MVar should return None *)
  (match Mvar.try_take mvar with
  | None -> Printf.printf "try_take on empty MVar correctly returned None\n"
  | Some _ -> assert false) ;

  (* Try to put into empty MVar should succeed *)
  assert (Mvar.try_put mvar 100) ;
  assert (Mvar.is_full mvar) ;
  Printf.printf "try_put on empty MVar succeeded\n" ;

  (* Try to put into full MVar should fail *)
  assert (not (Mvar.try_put mvar 200)) ;
  Printf.printf "try_put on full MVar correctly failed\n" ;

  (* Try to take from full MVar should succeed *)
  (match Mvar.try_take mvar with
  | Some value ->
    assert (value = 100) ;
    Printf.printf "try_take from full MVar returned correct value: %d\n" value
  | None -> assert false) ;

  assert (Mvar.is_empty mvar) ;
  Printf.printf "MVar try operations test passed\n"

let test_mvar_create_full () =
  let mvar = Mvar.create_full "hello" in
  assert (Mvar.is_full mvar) ;

  (* Should be able to take the initial value *)
  (match Mvar.try_take mvar with
  | Some value ->
    assert (value = "hello") ;
    Printf.printf "Retrieved initial value from create_full: %s\n" value
  | None -> assert false) ;

  assert (Mvar.is_empty mvar) ;

  (* Should be able to put a new value *)
  assert (Mvar.try_put mvar "world") ;
  assert (Mvar.is_full mvar) ;

  Printf.printf "MVar create_full test passed\n"

let test_mvar_state_transitions () =
  let mvar = Mvar.create () in

  (* Empty -> Full transition *)
  assert (Mvar.try_put mvar 1) ;
  assert (Mvar.is_full mvar) ;

  (* Full -> Empty transition *)
  (match Mvar.try_take mvar with
  | Some value -> assert (value = 1)
  | None -> assert false) ;
  assert (Mvar.is_empty mvar) ;

  (* Empty -> Full -> Empty again *)
  assert (Mvar.try_put mvar 2) ;
  (match Mvar.try_take mvar with
  | Some value -> assert (value = 2)
  | None -> assert false) ;
  assert (Mvar.is_empty mvar) ;

  Printf.printf "MVar state transitions test passed\n"

let () =
  test_mvar_create_and_state () ;
  test_mvar_try_operations () ;
  test_mvar_create_full () ;
  test_mvar_state_transitions () ;
  Printf.printf
    "All MVar tests passed (without blocking operations - require effect \
     handler)!\n"
