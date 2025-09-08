open Femtos

(* Test 1: Basic already signaled case (tests the `else` branch) *)
let test_basic_already_signaled () =
  Printf.printf "=== Test 1: Basic already signaled trigger ===\n%!";

  let trigger = Trigger.create () in
  let signaled = Trigger.signal trigger in
  assert signaled; (* Should succeed *)

  (* This should use the `else` branch in the scheduler *)
  let result = Effect.perform (Trigger.Await trigger) in
  assert (result = None);
  Printf.printf "✓ Already signaled trigger completed correctly\n%!"

(* Test 2: Wait-then-signal case (tests the `true` branch) *)
let test_wait_then_signal () =
  Printf.printf "=== Test 2: Wait then signal trigger ===\n%!";

  let trigger = Trigger.create () in
  let received_signal = ref false in

  (* Fork a task that will wait *)
  Mux.Fifo.fork (fun _ ->
    Printf.printf "  Waiter: About to wait on trigger\n%!";
    let result = Effect.perform (Trigger.Await trigger) in
    received_signal := true;
    assert (result = None);
    Printf.printf "  Waiter: Received signal successfully\n%!"
  );

  (* Yield to let the waiter start *)
  Mux.Fifo.yield ();

  (* Now signal the trigger *)
  Printf.printf "  Signaler: About to signal trigger\n%!";
  let signaled = Trigger.signal trigger in
  assert signaled;
  Printf.printf "  Signaler: Trigger signaled\n%!";

  (* Yield to let the waiter complete *)
  Mux.Fifo.yield ();

  assert !received_signal;
  Printf.printf "✓ Wait-then-signal completed correctly\n%!"

(* Test 3: Multiple signalers (only first should succeed) *)
let test_multiple_signalers () =
  Printf.printf "=== Test 3: Multiple signalers ===\n%!";

  let trigger = Trigger.create () in
  let first_success = ref false in
  let second_success = ref false in

  (* First signaler *)
  Mux.Fifo.fork (fun _ ->
    Printf.printf "  Signaler1: Attempting to signal\n%!";
    if Trigger.signal trigger then (
      first_success := true;
      Printf.printf "  Signaler1: Successfully signaled\n%!"
    ) else (
      Printf.printf "  Signaler1: Signal failed (already signaled)\n%!"
    )
  );

  (* Second signaler *)
  Mux.Fifo.fork (fun _ ->
    Printf.printf "  Signaler2: Attempting to signal\n%!";
    if Trigger.signal trigger then (
      second_success := true;
      Printf.printf "  Signaler2: Successfully signaled\n%!"
    ) else (
      Printf.printf "  Signaler2: Signal failed (already signaled)\n%!"
    )
  );

  (* Let both signalers run *)
  Mux.Fifo.yield ();
  Mux.Fifo.yield ();

  (* Exactly one should succeed *)
  assert (!first_success <> !second_success);
  Printf.printf "✓ Multiple signalers: exactly one succeeded\n%!"

(* Test 4: Individual trigger semantics *)
let test_individual_triggers () =
  Printf.printf "=== Test 4: Individual trigger semantics ===\n%!";

  (* Each trigger can have exactly one waiter - test multiple independent triggers *)
  let trigger1 = Trigger.create () in
  let trigger2 = Trigger.create () in
  let trigger3 = Trigger.create () in

  let completions = ref [] in

  (* Waiter on trigger1 *)
  Mux.Fifo.fork (fun _ ->
    Printf.printf "  Waiter1: Waiting on trigger1\n%!";
    let result = Effect.perform (Trigger.Await trigger1) in
    assert (result = None);
    completions := "waiter1" :: !completions;
    Printf.printf "  Waiter1: Completed\n%!"
  );

  (* Waiter on trigger2 *)
  Mux.Fifo.fork (fun _ ->
    Printf.printf "  Waiter2: Waiting on trigger2\n%!";
    let result = Effect.perform (Trigger.Await trigger2) in
    assert (result = None);
    completions := "waiter2" :: !completions;
    Printf.printf "  Waiter2: Completed\n%!"
  );

  (* Waiter on trigger3 *)
  Mux.Fifo.fork (fun _ ->
    Printf.printf "  Waiter3: Waiting on trigger3\n%!";
    let result = Effect.perform (Trigger.Await trigger3) in
    assert (result = None);
    completions := "waiter3" :: !completions;
    Printf.printf "  Waiter3: Completed\n%!"
  );

  (* Let all waiters start *)
  Mux.Fifo.yield ();
  Mux.Fifo.yield ();
  Mux.Fifo.yield ();

  (* Signal all triggers *)
  Printf.printf "  Signaling all triggers\n%!";
  assert (Trigger.signal trigger1);
  assert (Trigger.signal trigger2);
  assert (Trigger.signal trigger3);

  (* Let all complete *)
  Mux.Fifo.yield ();
  Mux.Fifo.yield ();
  Mux.Fifo.yield ();

  let completions = !completions in
  assert (List.length completions = 3);
  assert (List.mem "waiter1" completions);
  assert (List.mem "waiter2" completions);
  assert (List.mem "waiter3" completions);
  Printf.printf "✓ Individual triggers all completed independently\n%!"

(* Test 5: Mix of already-signaled and wait-then-signal *)
let test_mixed_scenarios () =
  Printf.printf "=== Test 5: Mixed scenarios ===\n%!";

  (* Pre-signaled trigger *)
  let pre_signaled = Trigger.create () in
  ignore (Trigger.signal pre_signaled);

  (* Regular trigger *)
  let regular = Trigger.create () in

  let results = ref [] in

  (* Task using pre-signaled trigger (else branch) *)
  Mux.Fifo.fork (fun _ ->
    Printf.printf "  Task1: Using pre-signaled trigger\n%!";
    let result = Effect.perform (Trigger.Await pre_signaled) in
    results := ("pre-signaled", result) :: !results;
    Printf.printf "  Task1: Completed with pre-signaled\n%!"
  );

  (* Task using regular trigger (true branch) *)
  Mux.Fifo.fork (fun _ ->
    Printf.printf "  Task2: Using regular trigger\n%!";
    let result = Effect.perform (Trigger.Await regular) in
    results := ("regular", result) :: !results;
    Printf.printf "  Task2: Completed with regular\n%!"
  );

  (* Let tasks start *)
  Mux.Fifo.yield ();
  Mux.Fifo.yield ();

  (* Signal the regular trigger *)
  Printf.printf "  Signaling regular trigger\n%!";
  ignore (Trigger.signal regular);

  (* Let everything complete *)
  Mux.Fifo.yield ();
  Mux.Fifo.yield ();

  (* Verify results *)
  let results = !results in
  assert (List.length results = 2);
  assert (List.mem ("pre-signaled", None) results);
  assert (List.mem ("regular", None) results);
  Printf.printf "✓ Mixed scenarios completed correctly\n%!"

(* Test 6: Stress test with many triggers and mixed scenarios *)
let test_stress () =
  Printf.printf "=== Test 6: Stress test ===\n%!";

  let num_pairs = 5 in
  let completions = ref 0 in

  (* Test both branches with multiple trigger/waiter pairs *)
  for i = 0 to num_pairs - 1 do
    (* Create a regular trigger (tests true branch) *)
    let wait_trigger = Trigger.create () in
    Mux.Fifo.fork (fun _ ->
      Printf.printf "  WaitWaiter%d: Waiting\n%!" i;
      let result = Effect.perform (Trigger.Await wait_trigger) in
      assert (result = None);
      incr completions;
      Printf.printf "  WaitWaiter%d: Done\n%!" i
    );

    (* Create a pre-signaled trigger (tests else branch) *)
    let pre_trigger = Trigger.create () in
    ignore (Trigger.signal pre_trigger);
    Mux.Fifo.fork (fun _ ->
      Printf.printf "  PreWaiter%d: Waiting on pre-signaled\n%!" i;
      let result = Effect.perform (Trigger.Await pre_trigger) in
      assert (result = None);
      incr completions;
      Printf.printf "  PreWaiter%d: Done\n%!" i
    );

    (* Let waiters start *)
    Mux.Fifo.yield ();
    Mux.Fifo.yield ();

    (* Signal the wait trigger *)
    Printf.printf "  Signaling trigger %d\n%!" i;
    let signaled = Trigger.signal wait_trigger in
    assert signaled;

    (* Let both complete *)
    Mux.Fifo.yield ();
    Mux.Fifo.yield ();
  done;

  assert (!completions = num_pairs * 2);
  Printf.printf "✓ Stress test: all %d triggers completed (%d each branch)\n%!"
    (num_pairs * 2) num_pairs

let run_all_tests () =
  test_basic_already_signaled ();
  test_wait_then_signal ();
  test_multiple_signalers ();
  test_individual_triggers ();
  test_mixed_scenarios ();
  test_stress ()

(* Test the single waiter constraint separately *)
let test_single_waiter_constraint_separate () =
  Printf.printf "=== Test: Single waiter constraint ===\n%!";

  let trigger = Trigger.create () in

  (* This should fail because we try to have two waiters on same trigger *)
  let test_failed_as_expected = ref false in

  (try
    Mux.Fifo.run (fun _ ->
      (* First waiter *)
      Mux.Fifo.fork (fun _ ->
        Printf.printf "  Waiter1: Starting to wait\n%!";
        let _ = Effect.perform (Trigger.Await trigger) in
        Printf.printf "  Waiter1: Should not reach here\n%!"
      );

      (* Let first waiter start and block *)
      Mux.Fifo.yield ();

      (* Second waiter - this should cause the constraint violation *)
      Mux.Fifo.fork (fun _ ->
        Printf.printf "  Waiter2: Attempting to wait (should fail)\n%!";
        let _ = Effect.perform (Trigger.Await trigger) in
        Printf.printf "  Waiter2: Should not reach here\n%!"
      );

      (* This yield should trigger the constraint violation *)
      Mux.Fifo.yield ()
    );
  with
  | Failure msg when String.length msg > 10 &&
                     String.sub msg 0 10 = "Trigger.on" ->
      test_failed_as_expected := true;
      Printf.printf "  ✓ Correctly failed with constraint violation: %s\n%!" msg
  | exn ->
      Printf.printf "  ❌ Unexpected exception: %s\n%!" (Printexc.to_string exn);
      raise exn
  );

  assert !test_failed_as_expected;
  Printf.printf "✓ Single waiter constraint properly enforced\n%!"

let () =
  Printf.printf "=== Comprehensive Trigger Scheduler Tests ===\n%!";

  (* Run the main tests *)
  (try
    Mux.Fifo.run (fun _ -> run_all_tests ());
    Printf.printf "\n✓ All main trigger tests passed!\n%!"
  with
  | exn ->
    Printf.printf "\n❌ Main tests failed with exception: %s\n%!" (Printexc.to_string exn);
    Printf.printf "Backtrace:\n%s\n%!" (Printexc.get_backtrace ());
    raise exn
  );

  (* Run the constraint test separately *)
  test_single_waiter_constraint_separate ();

  Printf.printf "\n🎉 All comprehensive trigger tests passed!\n%!"