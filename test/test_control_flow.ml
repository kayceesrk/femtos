open Femtos

let test_control_flow () =
  Printf.printf "=== Testing Control Flow ===\n";
  let mutex = Sync.Mutex.create () in

  Mux.Fifo.run (fun _terminator ->
    Printf.printf "[MAIN] Starting main fiber\n%!";

    (* Fork first task *)
    Mux.Fifo.fork (fun _ ->
      Printf.printf "[TASK1] Starting task1\n%!";
      Printf.printf "[TASK1] About to lock mutex\n%!";
      Sync.Mutex.lock mutex;
      Printf.printf "[TASK1] Acquired mutex, about to yield\n%!";
      Mux.Fifo.yield ();
      Printf.printf "[TASK1] After yield, about to unlock\n%!";
      Sync.Mutex.unlock mutex;
      Printf.printf "[TASK1] Unlocked mutex, task1 done\n%!"
    );

    (* Fork second task *)
    Mux.Fifo.fork (fun _ ->
      Printf.printf "[TASK2] Starting task2\n%!";
      Printf.printf "[TASK2] About to try locking mutex (should block)\n%!";
      Sync.Mutex.lock mutex;
      Printf.printf "[TASK2] Acquired mutex (after blocking)\n%!";
      Sync.Mutex.unlock mutex;
      Printf.printf "[TASK2] Unlocked mutex, task2 done\n%!"
    );

    Printf.printf "[MAIN] Forked both tasks, about to yield\n%!";
    Mux.Fifo.yield ();
    Printf.printf "[MAIN] After first yield\n%!";
    Mux.Fifo.yield ();
    Printf.printf "[MAIN] After second yield\n%!";
    Mux.Fifo.yield ();
    Printf.printf "[MAIN] Main fiber done\n%!"
  );

  Printf.printf "=== Control Flow Test Complete ===\n"

let () = test_control_flow ()
