(** MVar implementation using Trigger *)

open Femtos

type 'a state =
  | Empty of Trigger.t  (* Trigger for when a value becomes available *)
  | Full of 'a * Trigger.t  (* Value and trigger for when MVar becomes empty *)

type 'a t = 'a state Atomic.t

let create () =
  let trigger = Trigger.create () in
  Atomic.make (Empty trigger)

let create_full value =
  let trigger = Trigger.create () in
  Atomic.make (Full (value, trigger))

let try_put mvar value =
  let old_state = Atomic.get mvar in
  match old_state with
  | Full _ -> false (* MVar is full, can't put *)
  | Empty trigger ->
    let new_trigger = Trigger.create () in
    if Atomic.compare_and_set mvar old_state (Full (value, new_trigger)) then (
      Trigger.signal trigger; (* Signal that a value is now available *)
      true
    ) else
      false (* CAS failed, try again or return false *)

let try_take mvar =
  let old_state = Atomic.get mvar in
  match old_state with
  | Empty _ -> None (* MVar is empty, can't take *)
  | Full (value, trigger) ->
    let new_trigger = Trigger.create () in
    if Atomic.compare_and_set mvar old_state (Empty new_trigger) then (
      Trigger.signal trigger; (* Signal that MVar is now empty *)
      Some value
    ) else
      None (* CAS failed, try again or return None *)

let put mvar value =
  let rec loop () =
    if not (try_put mvar value) then (
      (* MVar is full, wait for it to become empty *)
      match Atomic.get mvar with
      | Empty _ -> loop () (* Retry immediately if now empty *)
      | Full (_, trigger) ->
        ignore @@ Effect.perform (Trigger.Await trigger);
        loop () (* Retry after being signaled *)
    )
  in
  loop ()

let take mvar =
  let rec loop () =
    match try_take mvar with
    | Some value -> value
    | None ->
      (* MVar is empty, wait for a value *)
      (match Atomic.get mvar with
      | Full _ -> loop () (* Retry immediately if now full *)
      | Empty trigger ->
        ignore @@ Effect.perform (Trigger.Await trigger);
        loop ()) (* Retry after being signaled *)
  in
  loop ()

let is_empty mvar =
  match Atomic.get mvar with
  | Empty _ -> true
  | Full _ -> false

let is_full mvar =
  match Atomic.get mvar with
  | Empty _ -> false
  | Full _ -> true
