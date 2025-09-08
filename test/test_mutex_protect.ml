open Femtos

let test_protect_success () =
  Printf.printf "=== Testing Mutex.protect success case ===\n%!";
  let mutex = Sync.Mutex.create () in
  let result = ref 0 in

  let protected_computation () =
    Printf.printf "Inside protected section\n%!";
    assert (Sync.Mutex.is_locked mutex);
    result := 42;
    "success"
  in

  let return_value = Sync.Mutex.protect mutex protected_computation in
  assert (return_value = "success");
  assert (!result = 42);
  assert (not (Sync.Mutex.is_locked mutex));
  Printf.printf "✓ Protect success test passed\n%!"

let test_protect_exception () =
  Printf.printf "=== Testing Mutex.protect exception case ===\n%!";
  let mutex = Sync.Mutex.create () in

  let protected_computation () =
    Printf.printf "Inside protected section before exception\n%!";
    assert (Sync.Mutex.is_locked mutex);
    failwith "test exception"
  in

  (try
    let _ = Sync.Mutex.protect mutex protected_computation in
    assert false (* Should not reach here *)
  with
  | Failure msg when msg = "test exception" ->
    Printf.printf "Caught expected exception: %s\n%!" msg;
    assert (not (Sync.Mutex.is_locked mutex));
    Printf.printf "✓ Mutex was properly released after exception\n%!"
  | exn ->
    Printf.printf "Unexpected exception: %s\n%!" (Printexc.to_string exn);
    assert false
  );
  Printf.printf "✓ Protect exception test passed\n%!"

let test_protect_concurrent () =
  Printf.printf "=== Testing Mutex.protect with concurrency ===\n%!";

  Mux.Fifo.run (fun _ ->
    let mutex = Sync.Mutex.create () in
    let shared_counter = ref 0 in
    let results = ref [] in

    let protected_increment id =
      let old_value = !shared_counter in
      Printf.printf "Task %d: incrementing from %d\n%!" id old_value;
      (* Simulate some work *)
      Mux.Fifo.yield ();
      shared_counter := old_value + 1;
      Printf.printf "Task %d: incremented to %d\n%!" id !shared_counter;
      !shared_counter
    in

    (* Fork multiple tasks *)
    Mux.Fifo.fork (fun _ ->
      let result = Sync.Mutex.protect mutex (fun () -> protected_increment 1) in
      results := ("task1", result) :: !results
    );

    Mux.Fifo.fork (fun _ ->
      let result = Sync.Mutex.protect mutex (fun () -> protected_increment 2) in
      results := ("task2", result) :: !results
    );

    Mux.Fifo.fork (fun _ ->
      let result = Sync.Mutex.protect mutex (fun () -> protected_increment 3) in
      results := ("task3", result) :: !results
    );

    (* Let all tasks complete *)
    Mux.Fifo.yield ();
    Mux.Fifo.yield ();
    Mux.Fifo.yield ();
    Mux.Fifo.yield ();

    (* Verify results *)
    let results = !results in
    assert (List.length results = 3);
    assert (!shared_counter = 3);
    assert (not (Sync.Mutex.is_locked mutex));

    Printf.printf "Final counter value: %d\n%!" !shared_counter;
    Printf.printf "✓ Concurrent protect test passed\n%!"
  )

let () =
  Printf.printf "=== Testing Mutex.protect function ===\n%!";
  test_protect_success ();
  test_protect_exception ();
  test_protect_concurrent ();
  Printf.printf "\n🎉 All Mutex.protect tests passed!\n%!"
