(** Mutex implementation using Trigger and atomic operations *)

open Femtos_core

type state =
  (* TODO: Replace list with proper queue for better fairness.
     For now, using list as LIFO queue. *)
  | Unlocked
  | Locked of { waiters : Trigger.t list }

type t = state Atomic.t

let create () = Atomic.make Unlocked

let try_lock mutex =
  let before = Atomic.get mutex in
  match before with
  | Unlocked ->
    (* Try to acquire the lock *)
    Atomic.compare_and_set mutex Unlocked (Locked { waiters = [] })
  | Locked _ ->
    (* Already locked *)
    false

let is_locked mutex =
  match Atomic.get mutex with
  | Unlocked -> false
  | Locked _ -> true

let rec lock mutex =
  let before = Atomic.get mutex in
  match before with
  | Unlocked ->
    (* Try to acquire the lock *)
    if Atomic.compare_and_set mutex Unlocked (Locked { waiters = [] }) then
      (* Successfully acquired *)
      ()
    else
      (* Someone else got it first, try again *)
      lock mutex
  | Locked { waiters } ->
    (* Mutex is locked, need to wait *)
    let trigger = Trigger.create () in
    let after = Locked { waiters = trigger :: waiters } in
    if Atomic.compare_and_set mutex before after then (
      (* Successfully added to wait queue *)
      match Effect.perform (Trigger.Await trigger) with
      | None ->
        (* We were signaled, lock should now be ours *)
        ()
      | Some (exn, bt) ->
        (* Cancellation from scheduler - remove ourselves from queue if possible *)
        remove_waiter mutex trigger ;
        Printexc.raise_with_backtrace exn bt)
    else
      (* CAS failed, state changed, try again *)
      lock mutex

and remove_waiter mutex trigger =
  (* Best effort removal - if we can't remove it, no big deal *)
  let rec attempt () =
    let before = Atomic.get mutex in
    match before with
    | Unlocked -> ()
    | Locked { waiters } ->
      let new_waiters = List.filter (fun t -> not (t == trigger)) waiters in
      if new_waiters != waiters then (
        let after = Locked { waiters = new_waiters } in
        if not (Atomic.compare_and_set mutex before after) then
          attempt ())
  in
  attempt ()

let unlock mutex =
  let rec attempt () =
    let before = Atomic.get mutex in
    match before with
    | Unlocked ->
      failwith "Mutex.unlock: mutex is not locked"
    | Locked { waiters = [] } ->
      (* No waiters, just unlock *)
      if Atomic.compare_and_set mutex before Unlocked then
        ()
      else
        attempt ()
    | Locked { waiters } ->
      (* There are waiters, wake up one *)
      match List.rev waiters with  (* FIFO fairness *)
      | [] ->
        (* Edge case: waiters became empty between observation and here *)
        attempt ()
      | next_waiter :: remaining_waiters ->
        let new_waiters = List.rev remaining_waiters in
        let after =
          if new_waiters = [] then
            Locked { waiters = [] }  (* Will be unlocked when waiter wakes up *)
          else
            Locked { waiters = new_waiters }
        in
        if Atomic.compare_and_set mutex before after then (
          (* Successfully updated state, now signal the next waiter *)
          if Trigger.signal next_waiter then
            (* Waiter was successfully signaled and will now own the lock *)
            ()
          else
            (* Waiter was cancelled/already signaled, try with next waiter *)
            attempt ())
        else
          (* CAS failed, try again *)
          attempt ()
  in
  attempt ()
