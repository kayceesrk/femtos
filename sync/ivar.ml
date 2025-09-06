(** Promise implementation using Trigger *)

open Femtos_core

type 'a state = Unfilled of Trigger.t list | Filled of 'a
type 'a t = 'a state Atomic.t

let create () = Atomic.make (Unfilled [])

let rec try_fill promise value =
  let old_state = Atomic.get promise in
  match old_state with
  | Filled _ -> false
  | Unfilled trigger ->
    if Atomic.compare_and_set promise old_state (Filled value) then (
      List.iter (fun trigger -> Trigger.signal trigger |> ignore) trigger ;
      true)
    else
      (* If CAS failed, state must have changed to Filled by another thread *)
      try_fill promise value

(* TODO: Naive O(n) implementation. Make it amortised O(1). *)
let rec remove_trigger promise trigger =
  let old_state = Atomic.get promise in
  match old_state with
  | Unfilled triggers ->
    let new_triggers = List.filter (fun t -> t != trigger) triggers in
    if Atomic.compare_and_set promise old_state (Unfilled new_triggers) then ()
    else remove_trigger promise trigger
  | Filled _ -> ()

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
        remove_trigger promise trigger ;
        Printexc.raise_with_backtrace exn backtrace)
    else read promise
