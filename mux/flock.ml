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


  let result =
    try
      Effect.Deep.match_with f ()
        { retc = (fun result ->
            (* Wait for all tasks *)
            while new_scope.active_tasks > 0 do
              (* Check for exceptions before each yield *)
              match new_scope.exception_raised with
              | Some exn ->
                  let backtrace = Printexc.get_raw_backtrace () in
                  Femtos_sync.Terminator.terminate new_scope.terminator exn backtrace;
                  raise exn
              | None ->
                  (* Yield to let other tasks run *)
                  Effect.perform Yield;
                  (* Check again after yield in case an exception was raised *)
                  match new_scope.exception_raised with
                  | Some exn ->
                      let backtrace = Printexc.get_raw_backtrace () in
                      Femtos_sync.Terminator.terminate new_scope.terminator exn backtrace;
                      raise exn
                  | None -> ()
            done;

            (* Check for exceptions one more time after all tasks complete *)
            match new_scope.exception_raised with
            | Some exn -> raise exn
            | None -> result
          );
          exnc = (fun exn ->
            (* On exception, terminate the scope and propagate *)
            let backtrace = Printexc.get_raw_backtrace () in
            Femtos_sync.Terminator.terminate new_scope.terminator exn backtrace;
            raise exn
          );
          effc = (fun (type a) (eff : a Effect.t) : ((a, _) Effect.Deep.continuation -> _) option ->
            match eff with
            | Async _ ->
                (* Just forward the effect to scheduler without tracking here *)
                None
            | _ ->
                (* Forward all other effects to parent handler (scheduler) *)
                None
          )
        }
    with
    | exn ->
        (* Restore scope and re-raise *)
        current_scope := old_scope;
        raise exn
  in

  (* Restore previous scope *)
  current_scope := old_scope;
  result

let run f =
  (* Reset scope stack *)
  let old_scope = !current_scope in
  current_scope := None;

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
                (* Set up terminator trigger for this task *)
                let trigger = Trigger.create () in
                let attached = Femtos_sync.Terminator.attach scope.terminator trigger in

                let cleanup_and_decrement () =
                  if attached then ignore (Femtos_sync.Terminator.detach scope.terminator trigger);
                  scope.active_tasks <- scope.active_tasks - 1;
                in

                try
                  (* Execute the task *)
                  task ();
                  cleanup_and_decrement ();
                with
                | exn ->
                    (* Task failed - record exception and terminate scope *)
                    cleanup_and_decrement ();
                    scope.exception_raised <- Some exn;
                    let backtrace = Printexc.get_raw_backtrace () in
                    Femtos_sync.Terminator.terminate scope.terminator exn backtrace;
              in

              (* Enqueue the task first *)
              enqueue task_fiber;

              (* Then continue with the main computation *)
              Effect.Deep.continue k ()
          )
      | effect (Trigger.Await t), k ->
          let resume trigger =
            let open Effect.Deep in
            match Trigger.status trigger with
            | `Signalled -> enqueue (fun () -> continue k None)
            | `Cancelled (exn, bt) -> enqueue (fun () -> discontinue_with_backtrace k exn bt)
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

      try
        let result = f () in

        (* Wait for any remaining tasks in root scope *)
        while root_scope.active_tasks > 0 do
          match root_scope.exception_raised with
          | Some exn -> raise exn
          | None ->
              Effect.perform Yield;
              (* Check if scheduler captured an exception *)
              match !exception_ref with
              | Some exn -> raise exn
              | None -> ()
        done;

        match root_scope.exception_raised with
        | Some exn -> raise exn
        | None ->
            match !exception_ref with
            | Some exn -> raise exn
            | None -> result_ref := Some result
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

    current_scope := old_scope;

    match (!result_ref, !exception_ref) with
    | (Some result, None) -> result
    | (None, Some exn) -> raise exn
    | (None, None) -> failwith "Flock.run: no result produced"
    | (Some _, Some exn) -> raise exn (* Exception takes precedence *)
  with
  | exn ->
      current_scope := old_scope;
      raise exn