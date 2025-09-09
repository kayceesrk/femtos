open Femtos

let test_condition_basic () =
  Printf.printf "=== Testing Condition basic signal/wait ===\n%!";

  Mux.Fifo.run (fun _ ->
    let mutex = Sync.Mutex.create () in
    let condition = Sync.Condition.create () in
    let received_signal = ref false in

    (* Waiter task *)
    Mux.Fifo.fork (fun _ ->
      Printf.printf "Waiter: Acquiring mutex\n%!";
      Sync.Mutex.lock mutex;
      Printf.printf "Waiter: Waiting on condition\n%!";
      Sync.Condition.wait condition mutex;
      Printf.printf "Waiter: Condition signaled!\n%!";
      received_signal := true;
      Sync.Mutex.unlock mutex;
      Printf.printf "Waiter: Done\n%!"
    );

    (* Let waiter start and block *)
    Mux.Fifo.yield ();

    (* Signaler task *)
    Mux.Fifo.fork (fun _ ->
      Printf.printf "Signaler: Acquiring mutex\n%!";
      Sync.Mutex.lock mutex;
      Printf.printf "Signaler: Signaling condition\n%!";
      Sync.Condition.signal condition;
      Sync.Mutex.unlock mutex;
      Printf.printf "Signaler: Done\n%!"
    );

    (* Let both tasks complete *)
    Mux.Fifo.yield ();
    Mux.Fifo.yield ();

    assert !received_signal;
    Printf.printf "✓ Basic signal/wait test passed\n%!"
  )

let test_condition_broadcast () =
  Printf.printf "=== Testing Condition broadcast ===\n%!";

  Mux.Fifo.run (fun _ ->
    let mutex = Sync.Mutex.create () in
    let condition = Sync.Condition.create () in
    let waiter_count = ref 0 in
    let num_waiters = 3 in

    (* Create multiple waiters *)
    for i = 1 to num_waiters do
      Mux.Fifo.fork (fun _ ->
        Printf.printf "Waiter%d: Acquiring mutex\n%!" i;
        Sync.Mutex.lock mutex;
        Printf.printf "Waiter%d: Waiting on condition\n%!" i;
        Sync.Condition.wait condition mutex;
        Printf.printf "Waiter%d: Condition signaled!\n%!" i;
        incr waiter_count;
        Sync.Mutex.unlock mutex;
        Printf.printf "Waiter%d: Done\n%!" i
      )
    done;

    (* Let all waiters start and block *)
    for _ = 1 to num_waiters do Mux.Fifo.yield () done;

    (* Broadcaster *)
    Mux.Fifo.fork (fun _ ->
      Printf.printf "Broadcaster: Acquiring mutex\n%!";
      Sync.Mutex.lock mutex;
      Printf.printf "Broadcaster: Broadcasting condition\n%!";
      Sync.Condition.broadcast condition;
      Sync.Mutex.unlock mutex;
      Printf.printf "Broadcaster: Done\n%!"
    );

    (* Let all tasks complete *)
    for _ = 1 to (num_waiters + 2) do Mux.Fifo.yield () done;

    assert (!waiter_count = num_waiters);
    Printf.printf "✓ Broadcast test passed - %d waiters woken up\n%!" !waiter_count
  )

let test_condition_producer_consumer () =
  Printf.printf "=== Testing Condition with producer/consumer pattern ===\n%!";

  Mux.Fifo.run (fun _ ->
    let mutex = Sync.Mutex.create () in
    let not_empty = Sync.Condition.create () in
    let not_full = Sync.Condition.create () in
    let buffer = ref [] in
    let max_size = 2 in
    let produced_count = ref 0 in
    let consumed_count = ref 0 in

    let produce item =
      Sync.Mutex.lock mutex;
      (* Wait for space in buffer *)
      while List.length !buffer >= max_size do
        Printf.printf "Producer: Buffer full, waiting...\n%!";
        Sync.Condition.wait not_full mutex;
      done;
      (* Produce item *)
      buffer := item :: !buffer;
      incr produced_count;
      Printf.printf "Producer: Produced %d (buffer size: %d)\n%!" item (List.length !buffer);
      Sync.Condition.signal not_empty; (* Signal consumer *)
      Sync.Mutex.unlock mutex;
    in

    let consume () =
      Sync.Mutex.lock mutex;
      (* Wait for item in buffer *)
      while !buffer = [] do
        Printf.printf "Consumer: Buffer empty, waiting...\n%!";
        Sync.Condition.wait not_empty mutex;
      done;
      (* Consume item *)
      let item = List.hd !buffer in
      buffer := List.tl !buffer;
      incr consumed_count;
      Printf.printf "Consumer: Consumed %d (buffer size: %d)\n%!" item (List.length !buffer);
      Sync.Condition.signal not_full; (* Signal producer *)
      Sync.Mutex.unlock mutex;
      item
    in

    (* Producer task *)
    Mux.Fifo.fork (fun _ ->
      Printf.printf "Producer: Starting\n%!";
      produce 1;
      produce 2;
      produce 3;
      Printf.printf "Producer: Done\n%!"
    );

    (* Consumer task *)
    Mux.Fifo.fork (fun _ ->
      Printf.printf "Consumer: Starting\n%!";
      let _ = consume () in
      let _ = consume () in
      let _ = consume () in
      Printf.printf "Consumer: Done\n%!"
    );

    (* Let both tasks complete *)
    for _ = 1 to 10 do Mux.Fifo.yield () done;

    assert (!produced_count = 3);
    assert (!consumed_count = 3);
    assert (!buffer = []);
    Printf.printf "✓ Producer/consumer test passed - %d items processed\n%!" !consumed_count
  )

let test_condition_cancellation_mutex_state () =
  Printf.printf "=== Testing Condition cancellation maintains mutex state ===\n%!";

  Mux.Fifo.run (fun terminator ->
    let mutex = Sync.Mutex.create () in
    let condition = Sync.Condition.create () in
    let worker_exception = ref None in
    let mutex_state_when_cancelled = ref false in

    (* Worker that will be cancelled via terminator while waiting on condition *)
    Mux.Fifo.fork (fun _ ->
      try
        Printf.printf "Worker: About to lock mutex and wait on condition\n%!";
        Sync.Mutex.lock mutex;
        Printf.printf "Worker: Mutex locked, about to wait on condition\n%!";

        (* This should: unlock mutex, wait, then reacquire mutex before raising exception *)
        Sync.Condition.wait condition mutex;

        Printf.printf "Worker: This should never print (got unexpected signal)\n%!";
        Sync.Mutex.unlock mutex;
      with
      | exn ->
          Printf.printf "Worker: Caught exception: %s\n%!" (Printexc.to_string exn);
          Printf.printf "Worker: Checking mutex state after exception...\n%!";
          mutex_state_when_cancelled := Sync.Mutex.is_locked mutex;
          Printf.printf "Worker: Mutex is locked: %b\n%!" !mutex_state_when_cancelled;

          (* If mutex is locked, unlock it properly *)
          if !mutex_state_when_cancelled then
            Sync.Mutex.unlock mutex;

          worker_exception := Some exn
    );

    (* Let worker start and block on condition *)
    Mux.Fifo.yield ();

    (* Now terminate the worker by terminating the terminator *)
    Printf.printf "Terminator: About to terminate to cancel worker\n%!";
    Sync.Terminator.terminate terminator (Failure "Worker cancelled") (Printexc.get_callstack 10);

    (* Let worker handle the termination *)
    Mux.Fifo.yield ();

    (* Check results *)
    match !worker_exception with
    | None ->
        Printf.printf "❌ FAIL: Worker should have been cancelled\n%!";
        assert false
    | Some _ ->
        if !mutex_state_when_cancelled then
          Printf.printf "✓ PASS: Mutex was properly reacquired before exception\n%!"
        else (
          Printf.printf "❌ FAIL: Mutex was NOT reacquired - this is the bug!\n%!";
          Printf.printf "❌ Condition.wait should reacquire mutex before raising exception\n%!";
          assert false
        )
  )

let test_condition_mutex_requirement () =
  Printf.printf "=== Testing Condition mutex requirement ===\n%!";

  let mutex = Sync.Mutex.create () in
  let condition = Sync.Condition.create () in

  (* Test that wait fails when mutex is not locked *)
  (try
    Sync.Condition.wait condition mutex;
    assert false (* Should not reach here *)
  with
  | Failure msg when String.sub msg 0 14 = "Condition.wait" ->
    Printf.printf "✓ Correctly rejected wait without locked mutex: %s\n%!" msg
  | exn ->
    Printf.printf "❌ Unexpected exception: %s\n%!" (Printexc.to_string exn);
    assert false
  );

  Printf.printf "✓ Mutex requirement test passed\n%!"

let () =
  Printf.printf "=== Testing Condition Variables ===\n%!";
  test_condition_basic ();
  test_condition_broadcast ();
  test_condition_producer_consumer ();
  test_condition_cancellation_mutex_state ();
  test_condition_mutex_requirement ();
  Printf.printf "\n🎉 All Condition Variable tests passed!\n%!"
