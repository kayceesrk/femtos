let test_basic_flock () =
  Printf.printf "\n=== Testing basic Flock structured concurrency ===\n%!" ;

  let result = Femtos_mux.Flock.run (fun () ->
    Printf.printf "Main: Starting structured concurrency test\n%!" ;

    Femtos_mux.Flock.finish (fun () ->
      Printf.printf "Finish: Starting concurrent tasks\n%!" ;

      Femtos_mux.Flock.async (fun () ->
        Printf.printf "Task 1: Starting work\n%!" ;
        Printf.printf "Task 1: Completed work\n%!"
      ) ;

      Femtos_mux.Flock.async (fun () ->
        Printf.printf "Task 2: Starting work\n%!" ;
        Printf.printf "Task 2: Completed work\n%!"
      ) ;

      Printf.printf "Finish: All tasks spawned, waiting for completion\n%!" ;
      "all tasks completed"
    )
  ) in

  Printf.printf "Main: Result = %s\n%!" result ;
  Printf.printf "Basic flock test completed!\n%!"

let test_nested_flock () =
  Printf.printf "\n=== Testing nested Flock scopes ===\n%!" ;

  let result = Femtos_mux.Flock.run (fun () ->
    Printf.printf "Main: Starting nested test\n%!" ;

    Femtos_mux.Flock.finish (fun () ->
      Printf.printf "Outer: Starting outer scope\n%!" ;

      Femtos_mux.Flock.async (fun () ->
        Printf.printf "Outer-Task: Starting work\n%!" ;
        Printf.printf "Outer-Task: Completed work\n%!"
      ) ;

      let nested_result = Femtos_mux.Flock.finish (fun () ->
        Printf.printf "Inner: Starting inner scope\n%!" ;

        Femtos_mux.Flock.async (fun () ->
          Printf.printf "Inner-Task1: Starting work\n%!" ;
          Printf.printf "Inner-Task1: Completed work\n%!"
        ) ;

        Femtos_mux.Flock.async (fun () ->
          Printf.printf "Inner-Task2: Starting work\n%!" ;
          Printf.printf "Inner-Task2: Completed work\n%!"
        ) ;

        Printf.printf "Inner: All inner tasks spawned\n%!" ;
        "inner completed"
      ) in

      Printf.printf "Outer: Inner result = %s\n%!" nested_result ;
      "outer completed"
    )
  ) in

  Printf.printf "Main: Final result = %s\n%!" result ;
  Printf.printf "Nested flock test completed!\n%!"

let test_exception_propagation () =
  Printf.printf "\n=== Testing exception propagation ===\n%!" ;

  try
    let _result = Femtos_mux.Flock.run (fun () ->
      Printf.printf "Main: Starting exception test\n%!" ;

      Femtos_mux.Flock.finish (fun () ->
        Printf.printf "Finish: Starting task\n%!" ;

        Femtos_mux.Flock.async (fun () ->
          Printf.printf "Task: Starting work\n%!" ;
          Printf.printf "Task: About to fail\n%!" ;
          failwith "Task failed"
        ) ;

        Printf.printf "Finish: Task spawned, waiting\n%!" ;
        "should not reach here"
      )
    ) in
    Printf.printf "ERROR: Should not have succeeded!\n%!"
  with
  | Failure msg when msg = "Task failed" ->
      Printf.printf "Main: Caught expected exception: %s\n%!" msg ;
      Printf.printf "Exception propagation test completed!\n%!"
  | Failure msg ->
      Printf.printf "Main: Caught different failure: %s\n%!" msg ;
      Printf.printf "Exception propagation test completed!\n%!"
  | exn ->
      Printf.printf "Main: Caught unexpected exception: %s\n%!" (Printexc.to_string exn) ;
      Printf.printf "Exception propagation test completed!\n%!"

let test_terminate () =
  Printf.printf "\n=== Testing explicit termination ===\n%!" ;

  try
    let _result = Femtos_mux.Flock.run (fun () ->
      Printf.printf "Main: Starting termination test\n%!" ;

      Femtos_mux.Flock.finish (fun () ->
        Printf.printf "Finish: Starting task\n%!" ;

        Femtos_mux.Flock.async (fun () ->
          Printf.printf "Task: Starting work\n%!" ;
          Printf.printf "Task: About to terminate scope\n%!" ;
          Femtos_mux.Flock.terminate ()
        ) ;

        Printf.printf "Finish: Task spawned, waiting\n%!" ;
        "should not reach here"
      )
    ) in
    Printf.printf "ERROR: Should not have succeeded!\n%!"
  with
  | Femtos_mux.Flock.Terminated (Failure msg) ->
      Printf.printf "Main: Caught expected termination: %s\n%!" msg ;
      Printf.printf "Explicit termination test completed!\n%!"
  | Failure msg ->
      Printf.printf "Main: Caught failure: %s\n%!" msg ;
      Printf.printf "Explicit termination test completed!\n%!"
  | exn ->
      Printf.printf "Main: Caught unexpected exception: %s\n%!" (Printexc.to_string exn) ;
      Printf.printf "Explicit termination test completed!\n%!"

let () =
  test_basic_flock () ;
  test_nested_flock () ;
  test_exception_propagation () ;
  test_terminate ()
