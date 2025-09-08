open Femtos_core

(* Termination exception - any exception can terminate a scope *)
exception Terminated of exn

(* Effect declarations for structured concurrency *)
type _ Effect.t +=
  | Async : (unit -> unit) -> unit Effect.t
  | Yield : unit Effect.t

(* Internal state for a scope *)
type scope = {
  terminator : Femtos_sync.Terminator.t;
  mutable active_tasks : int;
  mutable exception_raised : exn option;
}

(* Global scope stack managed through effect handlers *)
let current_scope : scope option ref = ref None

(* Core primitives implementation *)

let async f =
  match !current_scope with
  | None -> failwith "async must be called within a finish scope"
  | Some scope ->
      if scope.exception_raised <> None then
        failwith "Cannot spawn task in failed scope"
      else
        Effect.perform (Async f)

let terminate () =
  raise (Terminated (Failure "Scope terminated"))

let finish f =
  (* Create a child terminator linked to parent scope *)
  let parent_terminator = match !current_scope with
    | None -> Femtos_sync.Terminator.create ()
    | Some parent -> parent.terminator
  in

  let child_terminator = Femtos_sync.Terminator.create () in
  (* Link child to parent using forward *)
  ignore (Femtos_sync.Terminator.forward ~from_terminator:parent_terminator ~to_terminator:child_terminator);

  let new_scope = {
    terminator = child_terminator;
    active_tasks = 0;
    exception_raised = None;
  } in

  (* Set up effect handlers for this scope *)
  let old_scope = !current_scope in
  current_scope := Some new_scope;

  let restore_scope () = current_scope := old_scope in

  try
    let check_and_raise_exception () =
      match new_scope.exception_raised with
      | Some exn ->
          let backtrace = Printexc.get_raw_backtrace () in
          Femtos_sync.Terminator.terminate new_scope.terminator exn backtrace;
          raise exn
      | None -> ()
    in

    let result = f () in
    (* Wait for all tasks *)
    while new_scope.active_tasks > 0 do
      check_and_raise_exception ();
      Effect.perform Yield;
    done;

    (* Final exception check after all tasks complete *)
    check_and_raise_exception ();
    restore_scope ();
    result
  with
  | exn ->
      restore_scope ();
      raise exn

let run f =
  (* Reset scope stack *)
  let old_scope = !current_scope in
  current_scope := None;

  let restore_scope () = current_scope := old_scope in

  try
    (* Implement our own self-contained scheduler *)
    let exception_ref = ref None in
    let result_ref = ref None in
    let queue = Queue.create () in

    let enqueue f = Queue.add f queue in

    let run_next () =
      if Queue.is_empty queue then ()
      else (Queue.take queue) ()
    in

    let spawn f =
      match f () with
      | () -> run_next ()
      | exception (Terminated _ as e) ->
          (* Re-raise termination exceptions *)
          exception_ref := Some e;
          run_next ()
      | exception e ->
          (* Other exceptions from fibers are logged but not propagated *)
          Printf.eprintf "Fiber raised exception: %s\n" (Printexc.to_string e) ;
          run_next ()
      | effect Yield, k ->
          enqueue (Effect.Deep.continue k) ;
          run_next ()
      | effect (Async task), k ->
          (* Handle async tasks *)
          (match !current_scope with
          | None ->
              Printf.eprintf "Async called outside of finish scope\n" ;
              Effect.Deep.continue k ()
          | Some scope ->
              (* Increment active task count *)
              scope.active_tasks <- scope.active_tasks + 1;

              (* Create the task with cleanup *)
              let task_fiber () =
                let cleanup () =
                  scope.active_tasks <- scope.active_tasks - 1;
                in

                (try task () with
                | exn ->
                    (* Task failed - record exception and terminate scope *)
                    scope.exception_raised <- Some exn;
                    let backtrace = Printexc.get_raw_backtrace () in
                    Femtos_sync.Terminator.terminate scope.terminator exn backtrace;
                    raise exn);
                cleanup ()
              in

              (* Enqueue the task first *)
              enqueue task_fiber;

              (* Then continue with the main computation *)
              Effect.Deep.continue k ()
          )
      | effect (Trigger.Await t), k ->
          let resume _trigger =
            let open Effect.Deep in
            (* Check if current scope was terminated while waiting *)
            match !current_scope with
            | None ->
                (* No current scope, return None for normal completion *)
                enqueue (fun () -> continue k None)
            | Some scope ->
                if Femtos_sync.Terminator.is_terminated scope.terminator then
                  (* Scope was terminated, return the cancellation exception *)
                  (* TODO: Get the actual termination exception *)
                  let exn = Failure "Scope was terminated" in
                  let bt = Printexc.get_callstack 10 in
                  enqueue (fun () -> continue k (Some (exn, bt)))
                else
                  (* Normal signaling, return None *)
                  enqueue (fun () -> continue k None)
          in
          if Trigger.on_signal t resume then run_next ()
          else resume t
    in

    let main () =
      let root_scope = {
        terminator = Femtos_sync.Terminator.create ();
        active_tasks = 0;
        exception_raised = None;
      } in
      current_scope := Some root_scope;

      let check_exceptions () =
        match root_scope.exception_raised with
        | Some exn -> raise exn
        | None ->
            match !exception_ref with
            | Some exn -> raise exn
            | None -> ()
      in

      try
        let result = f () in

        (* Wait for any remaining tasks in root scope *)
        while root_scope.active_tasks > 0 do
          check_exceptions ();
          Effect.perform Yield;
          check_exceptions ();
        done;

        check_exceptions ();
        result_ref := Some result
      with
      | exn ->
          result_ref := None;
          exception_ref := Some exn
    in

    spawn main;

    (* Run the scheduler until all tasks complete *)
    while not (Queue.is_empty queue) do
      run_next ()
    done;

    restore_scope ();

    match (!result_ref, !exception_ref) with
    | (Some result, None) -> result
    | (None, Some exn) -> raise exn
    | (None, None) -> failwith "Flock.run: no result produced"
    | (Some _, Some exn) -> raise exn (* Exception takes precedence *)
  with
  | exn ->
      restore_scope ();
      raise exn