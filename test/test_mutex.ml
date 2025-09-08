open Femtos

let find_index pred lst =
  let rec aux i = function
    | [] -> None
    | x :: xs -> if pred x then Some i else aux (i + 1) xs
  in
  aux 0 lst

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

  (* Verify proper blocking behavior - check key properties instead of exact order *)
  let events = execution_order in

  (* Both tasks should start *)
  assert (List.mem "task1_start" events);
  assert (List.mem "task2_start" events);

  (* Both tasks should acquire and release the lock *)
  assert (List.mem "task1_locked" events);
  assert (List.mem "task1_unlocked" events);
  assert (List.mem "task2_locked" events);
  assert (List.mem "task2_unlocked" events);

  (* Mutual exclusion: task1 must unlock before task2 can lock *)
  let task1_unlock_pos = find_index (String.equal "task1_unlocked") events in
  let task2_lock_pos = find_index (String.equal "task2_locked") events in
  assert (Option.is_some task1_unlock_pos && Option.is_some task2_lock_pos);
  assert (Option.get task1_unlock_pos < Option.get task2_lock_pos);

  Printf.printf "Mutex blocking operations test passed\n"let test_mutex_multiple_waiters () =
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
