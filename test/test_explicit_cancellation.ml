open Femtos

(* Simple test to demonstrate explicit cancellation handling *)
let test_explicit_await_cancellation () =
  Printf.printf "=== Testing explicit Trigger.Await cancellation handling ===\n%!";

  try
    let _result = Mux.Flock.run (fun () ->
      Mux.Flock.finish (fun () ->
        Printf.printf "Starting blocking task that will be cancelled...\n%!";

        let mvar = Sync.Mvar.create () in

        Mux.Flock.async (fun () ->
          Printf.printf "Task: About to await on empty MVar (will be cancelled)\n%!";

          (* This will explicitly return Some (exn, bt) when cancelled *)
          (match Sync.Mvar.take mvar with
          | value -> Printf.printf "Task: Got value %d (shouldn't happen)\n%!" value
          | exception exn -> Printf.printf "Task: Cancelled with exception: %s\n%!" (Printexc.to_string exn))
        );

        Mux.Flock.async (fun () ->
          Printf.printf "Terminator: About to terminate scope\n%!";
          Mux.Flock.terminate ()
        );

        "shouldn't complete"
      )
    ) in
    Printf.printf "ERROR: Should have been terminated!\n%!";
    assert false
  with
  | Mux.Flock.Terminated (Failure msg) when msg = "Scope terminated" ->
      Printf.printf "✓ Caught expected termination: %s\n%!" msg;
      Printf.printf "✓ Explicit cancellation handling works correctly\n%!"

let () = test_explicit_await_cancellation ()
