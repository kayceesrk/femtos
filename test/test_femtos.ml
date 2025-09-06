open Femtos_core

let test_trigger_state_transitions () =
  let trigger = Trigger.create () in

  (* Test Initialized -> Waiting transition *)
  let callback_called = ref false in
  let was_registered =
    Trigger.on_signal trigger (fun _ -> callback_called := true)
  in
  assert was_registered ;
  (* Should return true when successfully registered *)
  assert (not !callback_called) ;

  (* Callback shouldn't be called yet *)

  (* Test Waiting -> Signaled transition *)
  Trigger.signal trigger |> ignore ;
  assert !callback_called ;

  (* Callback should now be called *)

  (* Test that on_signal returns false when already signaled *)
  let callback_called2 = ref false in
  let was_registered2 =
    Trigger.on_signal trigger (fun _ -> callback_called2 := true)
  in
  assert (not was_registered2) ;
  (* Should return false since already signaled *)
  assert (not !callback_called2) ;

  (* Callback should not be called *)
  Printf.printf "State transition test passed\n"

let test_trigger_direct_signal () =
  let trigger = Trigger.create () in

  (* Test Initialized -> Signaled transition (no callback registered) *)
  Trigger.signal trigger |> ignore ;

  (* Trying to register callback after signaling should return false *)
  let callback_called = ref false in
  let was_registered =
    Trigger.on_signal trigger (fun _ -> callback_called := true)
  in
  assert (not was_registered) ;
  (* Should return false *)
  assert (not !callback_called) ;

  (* Callback should not be called *)
  Printf.printf "Direct signal test passed\n"

let test_trigger_multiple_signals () =
  let trigger = Trigger.create () in
  let call_count = ref 0 in
  let was_registered = Trigger.on_signal trigger (fun _ -> incr call_count) in
  assert was_registered ;

  (* Multiple signals should only call callback once *)
  Trigger.signal trigger |> ignore ;
  Trigger.signal trigger |> ignore ;
  Trigger.signal trigger |> ignore ;
  assert (!call_count = 1) ;

  Printf.printf "Multiple signals test passed\n"

let test_trigger_double_wait_error () =
  let trigger = Trigger.create () in
  let _ = Trigger.on_signal trigger (fun _ -> ()) in

  (* Trying to register a second callback should fail *)
  try
    let _ = Trigger.on_signal trigger (fun _ -> ()) in
    assert false (* Should not reach here *)
  with
  | Failure msg when String.equal msg "Trigger.on_signal: already waiting" ->
    Printf.printf "Double wait error test passed\n"
  | _ -> assert false (* Unexpected exception *)

let () =
  test_trigger_state_transitions () ;
  test_trigger_direct_signal () ;
  test_trigger_multiple_signals () ;
  test_trigger_double_wait_error () ;
  Printf.printf "All trigger tests passed!\n"
