type state = Initialized | Signaled | Waiting of (unit -> unit)
type t = state Atomic.t

(** A trigger is a synchronization primitive that can be used to signal events.
*)

let create () = Atomic.make Initialized

let rec signal trigger =
  let old_state = Atomic.get trigger in
  match old_state with
  | Signaled -> () (* Already signaled *)
  | Initialized ->
    if Atomic.compare_and_set trigger Initialized Signaled then ()
    else signal trigger
  | Waiting callback ->
    if Atomic.compare_and_set trigger old_state Signaled then
      callback () (* Successfully signaled and called callback *)
    else () (* CAS failed, but that's okay - someone else signaled *)

(* Effect declaration for awaiting *)
type _ Effect.t += Await : t -> (exn * Printexc.raw_backtrace) option Effect.t

let rec on_signal trigger callback =
  match Atomic.get trigger with
  | Signaled -> false (* Already signaled, callback will not be called *)
  | Waiting _ ->
    failwith "Trigger.on_signal: already waiting"
    (* Already has a waiter, can't add another *)
  | Initialized ->
    if
      (* Try to set up the callback to be called when signaled *)
      Atomic.compare_and_set trigger Initialized (Waiting callback)
    then true (* Successfully registered as waiting *)
    else on_signal trigger callback (* Retry if state changed *)
