type state =
  | Initialized
  | Signalled
  | Cancelled of exn * Printexc.raw_backtrace
  | Waiting of (t -> unit)

and t = state Atomic.t

(** A trigger is a synchronization primitive that can be used to signal events.
*)

let create () = Atomic.make Initialized

let rec set trigger v =
  let old_state = Atomic.get trigger in
  match old_state with
  | Initialized ->
    if Atomic.compare_and_set trigger Initialized v then true else set trigger v
  | Signalled | Cancelled _ -> false (* Already signalled *)
  | Waiting callback ->
    if Atomic.compare_and_set trigger old_state v then (
      callback trigger ;
      (* Successfully signalled and called callback *)
      true)
    else false (* CAS failed, but that's okay - someone else signalled *)

let signal trigger = set trigger Signalled
let cancel trigger exn bt = set trigger (Cancelled (exn, bt))

(* Effect declaration for awaiting *)
type _ Effect.t += Await : t -> (exn * Printexc.raw_backtrace) option Effect.t

let rec on_signal trigger callback =
  match Atomic.get trigger with
  | Signalled | Cancelled _ ->
    false (* Already signaled, callback will not be called *)
  | Waiting _ ->
    failwith "Trigger.on_signal: already waiting"
    (* Already has a waiter, can't add another *)
  | Initialized ->
    if
      (* Try to set up the callback to be called when signaled *)
      Atomic.compare_and_set trigger Initialized (Waiting callback)
    then true (* Successfully registered as waiting *)
    else on_signal trigger callback (* Retry if state changed *)

let status trigger =
  match Atomic.get trigger with
  | Signalled -> `Signalled
  | Cancelled (exn, bt) -> `Cancelled (exn, bt)
  | Initialized | Waiting _ -> failwith "Trigger.status: not signaled"
