(** Promise implementation using Trigger *)

open Femtos

type 'a state = Unfilled of Trigger.t list | Filled of 'a
type 'a t = 'a state Atomic.t

let create () = Atomic.make (Unfilled [])

let rec try_fill promise value =
  let old_state = Atomic.get promise in
  match old_state with
  | Filled _ -> false
  | Unfilled trigger ->
    if Atomic.compare_and_set promise old_state (Filled value) then begin
      List.iter Trigger.signal trigger;
      true
    end else
      (* If CAS failed, state must have changed to Filled by another thread *)
      try_fill promise value

let rec read promise =
  match Atomic.get promise with
  | Filled value -> value
  | Unfilled l as before ->
    let trigger = Trigger.create () in
    let after = Unfilled (trigger :: l) in
    if Atomic.compare_and_set promise before after then (
      match Effect.perform (Trigger.Await trigger) with
      | None -> read promise
      | Some (exn, backtrace) ->
        Printexc.raise_with_backtrace exn backtrace)
    else read promise
