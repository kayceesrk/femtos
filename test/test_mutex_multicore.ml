open Femtos

let test_mutex_multicore_exclusion () =
  Printf.printf "\n=== Testing Mutex Multicore Mutual Exclusion ===\n%!" ;

  let mutex = Sync.Mutex.create () in
  let shared_counter = ref 0 in
  let iterations = 100 in
  let num_domains = 3 in

  Printf.printf "Starting %d domains, each incrementing counter %d times\n%!" num_domains iterations ;

  let domains = Array.init num_domains (fun domain_id ->
    Domain.spawn (fun () ->
      Printf.printf "Domain %d: Starting\n%!" domain_id ;

      let main _terminator =
        for i = 1 to iterations do
          (* Use mutex to protect the shared counter *)
          Sync.Mutex.lock mutex ;
          let current = !shared_counter in
          (* Simulate some work inside critical section to increase contention *)
          for _ = 1 to 10 do
            (* Busy work *)
            ignore (current + 1)
          done ;
          shared_counter := current + 1 ;
          Sync.Mutex.unlock mutex ;

          (* Occasionally yield to allow other fibers to run *)
          if i mod 100 = 0 then Mux.Fifo.yield ()
        done ;
        Printf.printf "Domain %d: Completed %d increments\n%!" domain_id iterations
      in

      Mux.Fifo.run main ;
      domain_id
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
    Printf.printf "✓ Mutex multicore exclusion test passed!\n%!"
  else
    Printf.printf "✗ Mutex multicore exclusion test FAILED!\n%!"

let () =
  test_mutex_multicore_exclusion ()
