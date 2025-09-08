open Femtos_sync

let test_protect_direct () =
  Printf.printf "=== Testing Mutex.protect directly ===\n%!";
  let mutex = Mutex.create () in
  let result = Mutex.protect mutex (fun () -> 42) in
  assert (result = 42);
  Printf.printf "✓ Direct protect test passed\n%!"

let () = test_protect_direct ()
