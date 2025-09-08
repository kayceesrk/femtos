(** Condition variables implementation using Trigger and atomic operations *)

open Femtos_core

type t = {
  waiters : Trigger.t list Atomic.t; (* Simple list of waiting triggers *)
}

let create () = { waiters = Atomic.make [] }

let wait condition mutex =
  (* Verify mutex is locked *)
  if not (Mutex.is_locked mutex) then
    failwith "Condition.wait: mutex must be locked";

  (* Create our trigger *)
  let trigger = Trigger.create () in

  (* Atomically add trigger to list of waiters *)
  let rec add_waiter () =
    let current_waiters = Atomic.get condition.waiters in
    let new_waiters = trigger :: current_waiters in
    if not (Atomic.compare_and_set condition.waiters current_waiters new_waiters) then
      add_waiter ()
  in
  add_waiter ();

  (* Release mutex and wait *)
  Mutex.unlock mutex;

  (* Wait for the condition to be signaled *)
  (match Effect.perform (Trigger.Await trigger) with
  | None ->
      (* We were signaled normally *)
      ()
  | Some (exn, bt) ->
      (* Cancellation occurred - no cleanup needed, triggers are GC'd *)
      Printexc.raise_with_backtrace exn bt
  );

  (* Reacquire the mutex before returning *)
  Mutex.lock mutex

let signal condition =
  (* Atomically remove one waiter from the list *)
  let rec try_signal () =
    let current_waiters = Atomic.get condition.waiters in
    match current_waiters with
    | [] ->
        (* No waiters *)
        ()
    | trigger :: rest ->
        (* Try to atomically remove this trigger from the list *)
        if Atomic.compare_and_set condition.waiters current_waiters rest then
          (* Successfully removed trigger from list, now signal it *)
          ignore (Trigger.signal trigger)
        else
          (* List was modified by another domain, try again *)
          try_signal ()
  in
  try_signal ()

let broadcast condition =
  (* Atomically take all waiters *)
  let rec take_all_waiters () =
    let current_waiters = Atomic.get condition.waiters in
    if Atomic.compare_and_set condition.waiters current_waiters [] then
      current_waiters
    else
      take_all_waiters ()
  in

  (* Signal all waiters *)
  let waiters = take_all_waiters () in
  List.iter (fun trigger -> ignore (Trigger.signal trigger)) waiters
