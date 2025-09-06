open Femtos

let test_terminator () =
  Printf.printf "Testing Terminator module...\n%!" ;
  let terminator = Sync.Terminator.create () in
  let trigger = Trigger.create () in

  (* Test attaching a trigger *)
  let attached = Sync.Terminator.attach terminator trigger in
  Printf.printf "Attach result: %b\n%!" attached ;

  (* Test detaching the trigger *)
  let detached = Sync.Terminator.detach terminator trigger in
  Printf.printf "Detach result: %b\n%!" detached ;

  Printf.printf "Terminator test passed!\n%!"

let test_terminator_with_scheduler () =
  Printf.printf "\nTesting Terminator integration with scheduler...\n%!" ;

  let main _terminator =
    Printf.printf "Main: Started with terminator\n%!" ;
    let ivar = Sync.Ivar.create () in

    (* Fork a fiber that will block on the ivar *)
    Mux.Fifo.fork (fun _fiber_terminator ->
      Printf.printf "Fiber: Starting, will block on IVar\n%!" ;
      let value = Sync.Ivar.read ivar in
      Printf.printf "Fiber: Got value %d from IVar\n%!" value
    ) ;

    (* Yield to let the forked fiber start and block *)
    Mux.Fifo.yield () ;
    Printf.printf "Main: Other fiber should now be blocked\n%!" ;

    (* Fill the ivar to wake up the blocked fiber *)
    let _ = Sync.Ivar.try_fill ivar 123 in
    Printf.printf "Main: Filled IVar, fiber should wake up\n%!" ;

    (* Yield to let the fiber complete *)
    Mux.Fifo.yield () ;
    Printf.printf "Main: Test completed\n%!"
  in

  Mux.Fifo.run main ;
  Printf.printf "Terminator integration test passed!\n%!"

let () =
  test_terminator () ;
  test_terminator_with_scheduler ()
