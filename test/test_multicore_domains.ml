open Femtos

(* Create a shared MVar for cross-domain communication *)
let shared_mvar = Sync.Mvar.create ()

let test_multicore_domains () =
  Printf.printf "\n=== Testing FIFO schedulers on different domains ===\n%!" ;

  (* Use a simple ref for coordination instead of IVars *)
  let domain1_ready = ref false in
  let domain2_ready = ref false in
  let coordination_mutex = Mutex.create () in

  Printf.printf "Main: Spawning two domains...\n%!" ;

  (* Domain 1: Producer scheduler *)
  let domain1 = Domain.spawn (fun () ->
    Printf.printf "Domain1: Starting FIFO scheduler (Producer)\n%!" ;

    let main _terminator =
      Printf.printf "Domain1: Scheduler started\n%!" ;

      (* Signal that this domain is ready *)
      Mutex.lock coordination_mutex ;
      domain1_ready := true ;
      Mutex.unlock coordination_mutex ;

      (* Wait for Domain2 to be ready *)
      Printf.printf "Domain1: Waiting for Domain2 to be ready...\n%!" ;
      let rec wait_for_domain2 () =
        Mutex.lock coordination_mutex ;
        let ready = !domain2_ready in
        Mutex.unlock coordination_mutex ;
        if not ready then (
          Mux.Fifo.yield () ;
          wait_for_domain2 ()
        )
      in
      wait_for_domain2 () ;
      Printf.printf "Domain1: Domain2 is ready, starting producer work\n%!" ;

      (* Fork multiple producers *)
      for i = 1 to 3 do
        Mux.Fifo.fork (fun _thread_terminator ->
          let value = Printf.sprintf "message_%d_from_domain1" i in
          Printf.printf "Domain1-Producer%d: Putting '%s' into shared MVar\n%!" i value ;
          Sync.Mvar.put shared_mvar value ;
          Printf.printf "Domain1-Producer%d: Successfully put value\n%!" i
        )
      done ;

      Printf.printf "Domain1: All producers started, yielding...\n%!" ;
      for _ = 1 to 15 do Mux.Fifo.yield () done ;

      Printf.printf "Domain1: Scheduler completed\n%!"
    in

    Mux.Fifo.run main ;
    "Domain1 completed"
  ) in

  (* Domain 2: Consumer scheduler *)
  let domain2 = Domain.spawn (fun () ->
    Printf.printf "Domain2: Starting FIFO scheduler (Consumer)\n%!" ;

    let main _terminator =
      Printf.printf "Domain2: Scheduler started\n%!" ;

      (* Signal that this domain is ready *)
      Mutex.lock coordination_mutex ;
      domain2_ready := true ;
      Mutex.unlock coordination_mutex ;

      (* Wait for Domain1 to be ready *)
      Printf.printf "Domain2: Waiting for Domain1 to be ready...\n%!" ;
      let rec wait_for_domain1 () =
        Mutex.lock coordination_mutex ;
        let ready = !domain1_ready in
        Mutex.unlock coordination_mutex ;
        if not ready then (
          Mux.Fifo.yield () ;
          wait_for_domain1 ()
        )
      in
      wait_for_domain1 () ;
      Printf.printf "Domain2: Domain1 is ready, starting consumer work\n%!" ;

      (* Fork multiple consumers *)
      for i = 1 to 3 do
        Mux.Fifo.fork (fun _thread_terminator ->
          Printf.printf "Domain2-Consumer%d: Waiting to take from shared MVar\n%!" i ;
          let value = Sync.Mvar.take shared_mvar in
          Printf.printf "Domain2-Consumer%d: Received '%s'\n%!" i value
        )
      done ;

      Printf.printf "Domain2: All consumers started, yielding...\n%!" ;
      for _ = 1 to 15 do Mux.Fifo.yield () done ;

      Printf.printf "Domain2: Scheduler completed\n%!"
    in

    Mux.Fifo.run main ;
    "Domain2 completed"
  ) in

  (* Wait for both domains to complete *)
  Printf.printf "Main: Waiting for both domains to complete...\n%!" ;
  let result1 = Domain.join domain1 in
  let result2 = Domain.join domain2 in

  Printf.printf "Main: Domain results: %s, %s\n%!" result1 result2 ;

  Printf.printf "Multicore domains test completed!\n%!"

let () =
  test_multicore_domains ()
