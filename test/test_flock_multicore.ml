open Femtos

let test_flock_cross_domain_trigger () =
  Printf.printf "\n=== Testing Flock Cross-Domain Trigger Signaling ===\n%!" ;

  let trigger = Trigger.create () in
  let received = Atomic.make false in

  (* Domain 1: Wait for trigger using Flock scheduler *)
  let waiter_domain = Domain.spawn (fun () ->
    Printf.printf "Waiter domain: Starting Flock scheduler\n%!" ;

    let main () =
      Printf.printf "Waiter: About to await trigger\n%!" ;

      (match Effect.perform (Trigger.Await trigger) with
      | None ->
          Printf.printf "Waiter: Trigger was signaled!\n%!" ;
          Atomic.set received true
      | Some (exn, bt) ->
          Printf.printf "Waiter: Got exception: %s\n%!" (Printexc.to_string exn) ;
          Printexc.raise_with_backtrace exn bt
      ) ;

      Printf.printf "Waiter: Completed\n%!" ;
      "waiter_result"
    in

    Mux.Flock.run main
  ) in

  (* Give waiter time to start *)
  Unix.sleepf 0.1 ;

  (* Domain 2: Signal the trigger *)
  let signaler_domain = Domain.spawn (fun () ->
    Printf.printf "Signaler domain: About to signal trigger\n%!" ;
    let result = Trigger.signal trigger in
    Printf.printf "Signaler domain: Signal result = %b\n%!" result ;
    result
  ) in

  Printf.printf "Main: Waiting for domains to complete...\n%!" ;
  let waiter_result = Domain.join waiter_domain in
  let signaler_result = Domain.join signaler_domain in

  let was_received = Atomic.get received in

  Printf.printf "Waiter result: %s, Signaler result: %b, Received: %b\n%!"
    waiter_result signaler_result was_received ;

  if was_received then
    Printf.printf "✓ Flock cross-domain trigger signaling works!\n%!"
  else
    Printf.printf "✗ Flock cross-domain trigger signaling failed!\n%!"

let test_flock_multicore_mutex () =
  Printf.printf "\n=== Testing Flock Multicore Mutex ===\n%!" ;

  let mutex = Sync.Mutex.create () in
  let shared_counter = ref 0 in
  let iterations = 50 in
  let num_domains = 3 in

  Printf.printf "Starting %d domains with Flock schedulers, each incrementing counter %d times\n%!" num_domains iterations ;

  let domains = Array.init num_domains (fun domain_id ->
    Domain.spawn (fun () ->
      Printf.printf "Domain %d: Starting Flock scheduler\n%!" domain_id ;

      let main () =
        for _ = 1 to iterations do
          (* Use mutex to protect the shared counter *)
          Sync.Mutex.lock mutex ;
          let current = !shared_counter in
          (* Simulate some work inside critical section *)
          for _ = 1 to 5 do
            ignore (current + 1)
          done ;
          shared_counter := current + 1 ;
          Sync.Mutex.unlock mutex
        done ;
        Printf.printf "Domain %d: Completed %d increments\n%!" domain_id iterations ;
        domain_id
      in

      Mux.Flock.run main
    )
  ) in

  Printf.printf "Waiting for all domains to complete...\n%!" ;
  let results = Array.map Domain.join domains in
  let final_value = !shared_counter in
  let expected_value = num_domains * iterations in

  Printf.printf "Domain results: [%s]\n%!"
    (String.concat "; " (Array.to_list (Array.map string_of_int results))) ;
  Printf.printf "Final counter value: %d (expected: %d)\n%!" final_value expected_value ;

  if final_value = expected_value then
    Printf.printf "✓ Flock multicore mutex test passed!\n%!"
  else
    Printf.printf "✗ Flock multicore mutex test FAILED!\n%!"

let () =
  test_flock_cross_domain_trigger () ;
  test_flock_multicore_mutex ()
