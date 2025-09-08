(** Mutex implementation using Trigger and atomic operations *)

open Femtos_core

type state =
  (* Using list as LIFO queue - no fairness guarantees *)
  | Unlocked
  | Locked of { waiters : Trigger.t list }

type t = state Atomic.t

let create () = Atomic.make Unlocked

let try_lock mutex =
  Atomic.compare_and_set mutex Unlocked (Locked { waiters = [] })

let is_locked mutex =
  match Atomic.get mutex with
  | Unlocked -> false
  | Locked _ -> true

let remove_waiter mutex trigger =
  (* Best effort removal - if we can't remove it, no big deal *)
  let rec attempt () =
    let before = Atomic.get mutex in
    match before with
    | Unlocked -> ()
    | Locked { waiters } ->
      let new_waiters = List.filter (fun t -> t != trigger) waiters in
      if new_waiters != waiters then (
        let after = Locked { waiters = new_waiters } in
        if not (Atomic.compare_and_set mutex before after) then
          attempt ())
  in
  attempt ()

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
    if Atomic.compare_and_set mutex before (Locked { waiters = trigger :: waiters }) then (
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
    | Locked { waiters = next_waiter :: remaining_waiters } ->
      (* There are waiters, wake up one *)
        if Atomic.compare_and_set mutex before (Locked { waiters = remaining_waiters }) then (
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

let protect mutex f =
  lock mutex;
  try
    let result = f () in
    unlock mutex;
    result
  with
  | exn ->
    unlock mutex;
    raise exn
