open Femtos

let test_mutex_basic () =
  let mutex = Sync.Mutex.create () in

  (* Test initial state *)
  assert (not (Sync.Mutex.is_locked mutex));

  (* Test try_lock on unlocked mutex *)
  assert (Sync.Mutex.try_lock mutex);
  assert (Sync.Mutex.is_locked mutex);

  (* Test try_lock on locked mutex *)
  assert (not (Sync.Mutex.try_lock mutex));

  (* Test unlock *)
  Sync.Mutex.unlock mutex;
  assert (not (Sync.Mutex.is_locked mutex));

  Printf.printf "Mutex basic operations test passed\n"

let test_mutex_blocking () =
  let mutex = Sync.Mutex.create () in
  let results = ref [] in

  Mux.Fifo.run (fun _terminator ->
    (* Start task that holds the lock for a while *)
    Mux.Fifo.fork (fun _ ->
      results := "task1_start" :: !results;
      Sync.Mutex.lock mutex;
      results := "task1_locked" :: !results;
      Mux.Fifo.yield ();  (* Let other task try to acquire *)
      results := "task1_yield" :: !results;
      Sync.Mutex.unlock mutex;
      results := "task1_unlocked" :: !results
    );

    (* Start task that waits for the lock *)
    Mux.Fifo.fork (fun _ ->
      results := "task2_start" :: !results;
      Sync.Mutex.lock mutex;  (* This should block *)
      results := "task2_locked" :: !results;
      Sync.Mutex.unlock mutex;
      results := "task2_unlocked" :: !results
    );

    (* Main task yields to let others run *)
    Mux.Fifo.yield ();
    Mux.Fifo.yield ();
    Mux.Fifo.yield ()
  );

  let execution_order = List.rev !results in
  Printf.printf "Execution order: %s\n" (String.concat " -> " execution_order);

  (* Verify proper blocking behavior *)
  assert (execution_order = [
    "task1_start"; "task1_locked"; "task2_start";
    "task1_yield"; "task1_unlocked"; "task2_locked"; "task2_unlocked"
  ]);

  Printf.printf "Mutex blocking operations test passed\n"

let test_mutex_multiple_waiters () =
  let mutex = Sync.Mutex.create () in
  let counter = ref 0 in

  Mux.Fifo.run (fun _terminator ->
    (* Create multiple tasks that compete for the mutex *)
    for i = 1 to 3 do
      Mux.Fifo.fork (fun _ ->
        Printf.printf "Task %d: Attempting to acquire mutex\n" i;
        Sync.Mutex.lock mutex;
        Printf.printf "Task %d: Acquired mutex\n" i;
        incr counter;
        let current = !counter in
        Mux.Fifo.yield ();  (* Simulate some work *)
        assert (!counter = current);  (* No other task should modify counter *)
        Printf.printf "Task %d: Releasing mutex\n" i;
        Sync.Mutex.unlock mutex
      )
    done;

    (* Let all tasks run *)
    for _ = 1 to 6 do Mux.Fifo.yield () done
  );

  assert (!counter = 3);
  Printf.printf "Mutex multiple waiters test passed\n"

let run_tests () =
  Printf.printf "=== Testing Mutex ===\n";
  test_mutex_basic ();
  test_mutex_blocking ();
  test_mutex_multiple_waiters ();
  Printf.printf "All Mutex tests passed!\n"

let () = run_tests ()
