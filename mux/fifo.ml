open Femtos_core

type _ Effect.t += Fork  : (unit -> unit) -> unit Effect.t
type _ Effect.t += Yield : unit Effect.t

let fork f = Effect.perform (Fork f)
let yield () = Effect.perform Yield

let run main =
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
      spawn f
    | effect (Trigger.Await t), k ->
      let resume t =
        let open Effect.Deep in
        match Trigger.status t with
        | `Signalled -> enqueue (fun () -> continue k None)
        | `Cancelled (exn, bt) -> enqueue (fun () -> discontinue_with_backtrace k exn bt)
      in
      if Trigger.on_signal t resume then run_next ()
      else resume t
  in
  spawn main