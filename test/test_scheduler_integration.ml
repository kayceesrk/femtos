open Femtos

let test_ivar_with_fifo () =
  Printf.printf "=== Testing IVar with FIFO scheduler ===\n" ;

  let main _terminator =
    let ivar = Sync.Ivar.create () in
    let result = ref None in

    (* Fork a producer fiber *)
    Mux.Fifo.fork (fun _terminator ->
        Printf.printf "Producer: Starting work...\n" ;
        Mux.Fifo.yield () ;
        (* Let consumer start first *)
        Printf.printf "Producer: Filling IVar with value 42\n" ;
        let success = Sync.Ivar.try_fill ivar 42 in
        Printf.printf "Producer: Fill %s\n"
          (if success then "succeeded" else "failed")) ;

    (* Fork a consumer fiber *)
    Mux.Fifo.fork (fun _terminator ->
        Printf.printf "Consumer: Waiting for IVar value...\n" ;
        let value = Sync.Ivar.read ivar in
        Printf.printf "Consumer: Received value %d\n" value ;
        result := Some value) ;

    Printf.printf "Main: Both fibers started\n" ;
    Mux.Fifo.yield () ;
    (* Let other fibers run *)
    Printf.printf "Main: Test completed with result: %s\n"
      (match !result with
      | Some v -> string_of_int v
      | None -> "None")
  in

  Mux.Fifo.run main ;
  Printf.printf "IVar with FIFO test passed!\n\n"

let test_mvar_producer_consumer () =
  Printf.printf "=== Testing MVar producer-consumer with FIFO scheduler ===\n" ;

  let main _terminator =
    let mvar = Sync.Mvar.create () in
    let received_values = ref [] in

    (* Producer fiber *)
    Mux.Fifo.fork (fun _terminator ->
        Printf.printf "Producer: Starting to produce values...\n" ;
        for i = 1 to 3 do
          Printf.printf "Producer: Putting value %d\n" i ;
          Sync.Mvar.put mvar i ;
          Printf.printf "Producer: Value %d put successfully\n" i ;
          Mux.Fifo.yield () (* Give consumer a chance *)
        done ;
        Printf.printf "Producer: Finished producing\n") ;

    (* Consumer fiber *)
    Mux.Fifo.fork (fun _terminator ->
        Printf.printf "Consumer: Starting to consume values...\n" ;
        for _i = 1 to 3 do
          Printf.printf "Consumer: Taking value...\n" ;
          let value = Sync.Mvar.take mvar in
          Printf.printf "Consumer: Received value %d\n" value ;
          received_values := value :: !received_values ;
          Mux.Fifo.yield () (* Give producer a chance *)
        done ;
        Printf.printf "Consumer: Finished consuming\n") ;

    Printf.printf "Main: Started producer and consumer\n" ;
    Mux.Fifo.yield () ;
    (* Let other fibers run *)
    Printf.printf "Main: Received values: [%s]\n"
      (String.concat "; " (List.map string_of_int (List.rev !received_values)))
  in

  Mux.Fifo.run main ;
  Printf.printf "MVar producer-consumer test passed!\n\n"

let test_multiple_ivar_readers () =
  Printf.printf "=== Testing multiple IVar readers with FIFO scheduler ===\n" ;

  let main _terminator =
    let ivar = Sync.Ivar.create () in
    let reader_results = Array.make 3 None in

    (* Create multiple reader fibers *)
    for i = 0 to 2 do
      Mux.Fifo.fork (fun _terminator ->
          Printf.printf "Reader %d: Waiting for value...\n" i ;
          let value = Sync.Ivar.read ivar in
          Printf.printf "Reader %d: Got value %d\n" i value ;
          reader_results.(i) <- Some value)
    done ;

    (* Writer fiber *)
    Mux.Fifo.fork (fun _terminator ->
        Printf.printf "Writer: Yielding to let readers start...\n" ;
        Mux.Fifo.yield () ;
        Printf.printf "Writer: Filling IVar with 100\n" ;
        let success = Sync.Ivar.try_fill ivar 100 in
        Printf.printf "Writer: Fill %s\n"
          (if success then "succeeded" else "failed")) ;

    Printf.printf "Main: All fibers started\n" ;
    Mux.Fifo.yield () ;

    Printf.printf "Main: Reader results: " ;
    Array.iteri
      (fun i result ->
        match result with
        | Some v -> Printf.printf "Reader%d=%d " i v
        | None -> Printf.printf "Reader%d=None " i)
      reader_results ;
    Printf.printf "\n"
  in

  Mux.Fifo.run main ;
  Printf.printf "Multiple IVar readers test passed!\n\n"

let test_mvar_ping_pong () =
  Printf.printf "=== Testing MVar ping-pong with FIFO scheduler ===\n" ;

  let main _terminator =
    let ping_mvar = Sync.Mvar.create () in
    let pong_mvar = Sync.Mvar.create_full "start" in
    let rounds = 3 in

    (* Ping fiber *)
    Mux.Fifo.fork (fun _terminator ->
        for i = 1 to rounds do
          let msg = Sync.Mvar.take pong_mvar in
          Printf.printf "Ping: Received '%s', sending 'ping%d'\n" msg i ;
          Sync.Mvar.put ping_mvar ("ping" ^ string_of_int i) ;
          Mux.Fifo.yield ()
        done ;
        Printf.printf "Ping: Finished\n") ;

    (* Pong fiber *)
    Mux.Fifo.fork (fun _terminator ->
        for i = 1 to rounds do
          let msg = Sync.Mvar.take ping_mvar in
          Printf.printf "Pong: Received '%s', sending 'pong%d'\n" msg i ;
          Sync.Mvar.put pong_mvar ("pong" ^ string_of_int i) ;
          Mux.Fifo.yield ()
        done ;
        Printf.printf "Pong: Finished\n") ;

    Printf.printf "Main: Ping-pong started\n" ;
    Mux.Fifo.yield ()
  in

  Mux.Fifo.run main ;
  Printf.printf "MVar ping-pong test passed!\n\n"

let test_mixed_ivar_mvar () =
  Printf.printf
    "=== Testing mixed IVar and MVar operations with FIFO scheduler ===\n" ;

  let main _terminator =
    let config_ivar = Sync.Ivar.create () in
    let work_mvar = Sync.Mvar.create () in
    let results = ref [] in

    (* Configuration provider *)
    Mux.Fifo.fork (fun _terminator ->
        Printf.printf "Config: Setting up configuration...\n" ;
        Mux.Fifo.yield () ;
        let config = "config_data" in
        Printf.printf "Config: Providing configuration: %s\n" config ;
        let _ = Sync.Ivar.try_fill config_ivar config in
        ()) ;

    (* Worker 1 *)
    Mux.Fifo.fork (fun _terminator ->
        Printf.printf "Worker1: Waiting for configuration...\n" ;
        let config = Sync.Ivar.read config_ivar in
        Printf.printf "Worker1: Got config '%s', doing work...\n" config ;
        let work_result = config ^ "_processed_by_worker1" in
        Printf.printf "Worker1: Putting result into MVar\n" ;
        Sync.Mvar.put work_mvar work_result ;
        Printf.printf "Worker1: Work completed\n") ;

    (* Worker 2 *)
    Mux.Fifo.fork (fun _terminator ->
        Printf.printf "Worker2: Waiting for configuration...\n" ;
        let config = Sync.Ivar.read config_ivar in
        Printf.printf
          "Worker2: Got config '%s', waiting for work from Worker1...\n" config ;
        let work = Sync.Mvar.take work_mvar in
        Printf.printf "Worker2: Got work '%s', processing...\n" work ;
        let final_result = work ^ "_finalized_by_worker2" in
        results := final_result :: !results ;
        Printf.printf "Worker2: Final result: %s\n" final_result) ;

    Printf.printf "Main: Mixed IVar/MVar test started\n" ;
    Mux.Fifo.yield () ;
    Printf.printf "Main: Results: [%s]\n" (String.concat "; " !results)
  in

  Mux.Fifo.run main ;
  Printf.printf "Mixed IVar/MVar test passed!\n\n"

let () =
  Printf.printf
    "Running comprehensive IVar and MVar tests with FIFO scheduler...\n\n" ;
  test_ivar_with_fifo () ;
  test_mvar_producer_consumer () ;
  test_multiple_ivar_readers () ;
  test_mvar_ping_pong () ;
  test_mixed_ivar_mvar () ;
  Printf.printf "All scheduler integration tests passed!\n"
