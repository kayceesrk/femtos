(** Promise implementation using Trigger *)

open Femtos

type 'a state = Unfilled of Trigger.t list | Filled of 'a
type 'a t = 'a state Atomic.t

exception Already_filled

let create () = Atomic.make (Unfilled [])

let rec fill promise value =
  let old_state = Atomic.get promise in
  match old_state with
  | Filled _ -> raise Already_filled
  | Unfilled trigger ->
    if Atomic.compare_and_set promise old_state (Filled value) then
      List.iter Trigger.signal trigger
    else
      (* If CAS failed, state must have changed to Filled by another thread *)
      fill promise value

let rec await promise =
  match Atomic.get promise with
  | Filled value -> value
  | Unfilled l as before ->
    let trigger = Trigger.create () in
    let after = Unfilled (trigger :: l) in
    if Atomic.compare_and_set promise before after then (
      match Effect.perform (Trigger.Await trigger) with
      | None -> await promise
      | Some (exn, backtrace) ->
        Printexc.raise_with_backtrace exn backtrace)
    else await promise
