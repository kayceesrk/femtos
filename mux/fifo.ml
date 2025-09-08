open Femtos_core

type _ Effect.t += Fork  : (Femtos_sync.Terminator.t -> unit) -> unit Effect.t
type _ Effect.t += Yield : unit Effect.t

let fork f = Effect.perform (Fork f)
let yield () = Effect.perform Yield

let run main =
  (* Create a single terminator for the entire scheduler *)
  let terminator = Femtos_sync.Terminator.create () in
  (* Use Saturn's lock-free multiproducer single consumer queue for multicore safety *)
  let queue = Saturn.Single_consumer_queue.create () in
  let blocked_count = Atomic.make 0 in  (* Track blocked threads atomically *)

  (* Condition variable for blocking the scheduler when no work is available *)
  let scheduler_mutex = Mutex.create () in
  let scheduler_condition = Condition.create () in

  let enqueue f =
    Saturn.Single_consumer_queue.push queue f;
    (* Wake up the scheduler if it's waiting *)
    Mutex.lock scheduler_mutex;
    Condition.signal scheduler_condition;
    Mutex.unlock scheduler_mutex
  in

  let rec run_next () =
    match Saturn.Single_consumer_queue.pop_opt queue with
    | Some f -> f ()
    | None ->
        (* Queue is empty - check if we have blocked threads *)
        if Atomic.get blocked_count > 0 then (
          (* There are blocked threads that might be woken up by other domains.
             Block on condition variable until work arrives. *)
          Mutex.lock scheduler_mutex;
          (* Double-check the queue after acquiring the mutex *)
          (match Saturn.Single_consumer_queue.pop_opt queue with
          | Some f ->
              Mutex.unlock scheduler_mutex;
              f ()
          | None ->
              (* Still no work - wait for signal *)
              Condition.wait scheduler_condition scheduler_mutex;
              Mutex.unlock scheduler_mutex;
              run_next ()
          )
        ) else (
          (* No runnable threads and no blocked threads - we can exit *)
          ()
        )
  in
  let rec spawn f =
    match f () with
    | () -> run_next ()
    | exception e ->
      Printf.eprintf "Fiber error: %s\n%!" (Printexc.to_string e);
      run_next ()
    | effect Yield, k ->
      enqueue (Effect.Deep.continue k);
      run_next ()
    | effect (Fork f), k ->
      enqueue (Effect.Deep.continue k);
      spawn (fun () -> f terminator)
    | effect (Trigger.Await t), k ->
      (* Attach the trigger to the terminator when blocking *)
      let attached = Femtos_sync.Terminator.attach terminator t in
      let resume () =
        let open Effect.Deep in
        (* Detach the trigger when waking up *)
        if attached then ignore (Femtos_sync.Terminator.detach terminator t);

        (* Decrement blocked count atomically when resuming *)
        Atomic.decr blocked_count;

        (* Check if terminator was terminated while waiting *)
        match Femtos_sync.Terminator.get_termination terminator with
        | Some (exn, bt) ->
            (* Terminator was terminated, return the actual termination exception *)
            enqueue (fun () -> continue k (Some (exn, bt)))
        | None ->
            (* Not terminated, return None for normal completion *)
            enqueue (fun () -> continue k None)
      in
      if Trigger.on_signal t resume then (
        (* Callback registered, trigger not yet signaled - increment blocked count *)
        Atomic.incr blocked_count;
        run_next ()
      ) else (
        (* Trigger already signaled, resume immediately *)
        resume ();
        run_next ()
      )
  in
  spawn (fun () -> main terminator)