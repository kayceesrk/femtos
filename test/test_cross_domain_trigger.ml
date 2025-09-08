open Femtos

let test_cross_domain_trigger () =
  Printf.printf "\n=== Testing Cross-Domain Trigger Signaling ===\n%!" ;

  let trigger = Trigger.create () in
  let received = Atomic.make false in

  (* Domain 1: Wait for trigger *)
  let waiter_domain = Domain.spawn (fun () ->
    Printf.printf "Waiter domain: Starting scheduler\n%!" ;

    let main _terminator =
      Printf.printf "Waiter: About to await trigger\n%!" ;

      (match Effect.perform (Trigger.Await trigger) with
      | None ->
          Printf.printf "Waiter: Trigger was signaled!\n%!" ;
          Atomic.set received true
      | Some (exn, bt) ->
          Printf.printf "Waiter: Got exception: %s\n%!" (Printexc.to_string exn) ;
          Printexc.raise_with_backtrace exn bt
      ) ;

      Printf.printf "Waiter: Completed\n%!"
    in

    Mux.Fifo.run main ;
    "waiter_done"
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
    Printf.printf "✓ Cross-domain trigger signaling works!\n%!"
  else
    Printf.printf "✗ Cross-domain trigger signaling failed!\n%!"

let () =
  test_cross_domain_trigger ()
