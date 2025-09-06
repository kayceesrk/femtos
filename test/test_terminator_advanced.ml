open Femtos

(* Create a single global MVar used by both tests *)
let shared_mvar = Sync.Mvar.create ()

let test_mass_cancellation () =
  Printf.printf "\n=== Testing mass cancellation of 100 waiting threads ===\n%!" ;

  let main terminator =
    let completed_count = ref 0 in
    let cancelled_count = ref 0 in

    Printf.printf "Main: Creating 100 threads that will block on shared MVar\n%!" ;

    (* Create 100 threads that will all block on the shared MVar *)
    for i = 1 to 100 do
      Mux.Fifo.fork (fun _thread_terminator ->
        try
          Printf.printf "Thread %d: Attempting to take from shared MVar...\n%!" i ;
          let _value = Sync.Mvar.take shared_mvar in
          Printf.printf "Thread %d: Successfully took value (this shouldn't happen)\n%!" i ;
          incr completed_count
        with
        | exn ->
          Printf.printf "Thread %d: Cancelled with exception: %s\n%!" i (Printexc.to_string exn) ;
          incr cancelled_count
      )
    done ;

    (* Yield to let all threads start and block *)
    Printf.printf "Main: Yielding to let all threads start and block...\n%!" ;
    Mux.Fifo.yield () ;

    Printf.printf "Main: All threads should now be blocked. Terminating scheduler...\n%!" ;

    (* Terminate the terminator to cancel all waiting threads *)
    let cancellation_exn = Failure "Scheduler terminated" in
    Sync.Terminator.terminate terminator cancellation_exn (Printexc.get_callstack 10) ;

    Printf.printf "Main: Terminator terminated. Completed: %d, Cancelled: %d\n%!"
      !completed_count !cancelled_count
  in

  Mux.Fifo.run main ;
  Printf.printf "Mass cancellation test completed!\n%!"

let test_normal_exchange () =
  Printf.printf "\n=== Testing normal 2-thread value exchange ===\n%!" ;

  let main _terminator =
    let results = ref [] in

    Printf.printf "Main: Creating producer and consumer threads (using same shared MVar)\n%!" ;

    (* Consumer thread *)
    Mux.Fifo.fork (fun _thread_terminator ->
      Printf.printf "Consumer: Waiting to take value from shared MVar\n%!" ;
      let value = Sync.Mvar.take shared_mvar in
      Printf.printf "Consumer: Received value: %s\n%!" value ;
      results := ("consumer_received", value) :: !results
    ) ;

    (* Producer thread *)
    Mux.Fifo.fork (fun _thread_terminator ->
      Printf.printf "Producer: Putting value 'hello' into shared MVar\n%!" ;
      Sync.Mvar.put shared_mvar "hello" ;
      Printf.printf "Producer: Successfully put value\n%!" ;
      results := ("producer_sent", "hello") :: !results
    ) ;

    Printf.printf "Main: Both threads started, yielding...\n%!" ;
    Mux.Fifo.yield () ;
    Mux.Fifo.yield () ;

    Printf.printf "Main: Exchange completed. Results: %s\n%!"
      (String.concat "; " (List.map (fun (k,v) -> k ^ "=" ^ v) !results))
  in

  Mux.Fifo.run main ;
  Printf.printf "Normal exchange test completed!\n%!"let test_concurrent_terminators () =
  Printf.printf "\n=== Testing multiple independent schedulers ===\n%!" ;

  Printf.printf "Running mass cancellation test in first scheduler...\n%!" ;
  test_mass_cancellation () ;

  Printf.printf "\nRunning normal exchange test in second scheduler...\n%!" ;
  test_normal_exchange () ;

  Printf.printf "\nBoth schedulers completed independently!\n%!"

let () = test_concurrent_terminators ()
