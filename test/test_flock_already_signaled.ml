open Femtos

(* Test the flock scheduler fix for already-signaled triggers *)
let test_flock_already_signaled () =
  Printf.printf "=== Testing Flock scheduler with already signaled triggers ===\n%!";

  Mux.Flock.run (fun () ->
    let trigger = Trigger.create () in
    let signaled = Trigger.signal trigger in
    assert signaled;

    Printf.printf "Trigger pre-signaled, testing flock await...\n%!";

    (* This should use the `else` branch in the flock scheduler *)
    let result = Effect.perform (Trigger.Await trigger) in
    assert (result = None);

    Printf.printf "✓ Flock scheduler handled already-signaled trigger correctly\n%!"
  );

  Printf.printf "Flock already-signaled test passed!\n%!"

let () = test_flock_already_signaled ()
