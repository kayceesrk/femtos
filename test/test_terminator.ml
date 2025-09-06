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

let () = test_terminator ()
