open Femtos_core

type _ Effect.t += Fork  : (Femtos_sync.Terminator.t -> unit) -> unit Effect.t
type _ Effect.t += Yield : unit Effect.t

let fork f = Effect.perform (Fork f)
let yield () = Effect.perform Yield

let run main =
  (* Create a single terminator for the entire scheduler *)
  let terminator = Femtos_sync.Terminator.create () in
  let queue = Queue.create () in
  let enqueue f = Queue.add f queue in
  let run_next () =
    if Queue.is_empty queue then ()
    else (Queue.take queue) ()
  in
  let rec spawn f =
    match f () with
    | () -> run_next ()
    | exception e ->
      Printf.eprintf "Fiber raised exception: %s\n" (Printexc.to_string e) ;
      run_next ()
    | effect Yield, k ->
      enqueue (Effect.Deep.continue k) ;
      run_next ()
    | effect (Fork f), k ->
      enqueue (Effect.Deep.continue k);
      spawn (fun () -> f terminator)
    | effect (Trigger.Await t), k ->
      (* Attach the trigger to the terminator when blocking *)
      let attached = Femtos_sync.Terminator.attach terminator t in
      let resume trigger =
        let open Effect.Deep in
        (* Detach the trigger when waking up *)
        if attached then ignore (Femtos_sync.Terminator.detach terminator trigger);

        (* Check if terminator was terminated while waiting *)
        if Femtos_sync.Terminator.is_terminated terminator then
          (* Terminator was terminated, return the cancellation exception *)
          (* TODO: Get the actual termination exception *)
          let exn = Failure "Terminator was terminated" in
          let bt = Printexc.get_callstack 10 in
          enqueue (fun () -> continue k (Some (exn, bt)))
        else
          (* Normal signaling, return None *)
          enqueue (fun () -> continue k None)
      in
      if Trigger.on_signal t resume then run_next ()
      else resume t
  in
  spawn (fun () -> main terminator)