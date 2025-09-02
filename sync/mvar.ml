(** MVar implementation using Trigger *)

open Femtos

type 'a state =
  (* TODO: Replace list with queue. Not the right semantics now. But doesn't
     matter. Assume it is a queue for now. *)
  | Empty of { takers : ('a ref * Trigger.t) list }
  | Full of { value: 'a; putters : ('a * Trigger.t) list }

type 'a t = 'a state Atomic.t

let create () =
  Atomic.make (Empty {takers = []})

let create_full value =
  Atomic.make (Full {value; putters = []})

let remove_trigger () = () (* TBD *)

let rec put mvar v =
  let before = Atomic.get mvar in
  match before with
  | Full {value; putters} ->
    let t = Trigger.create () in
    let after = Full {value; putters = (v,t)::putters} in
    if Atomic.compare_and_set mvar before after then begin
      match Effect.perform (Trigger.Await t) with
      | None -> () (* put succeeded *)
      | Some (exn, bt) ->
          (* TODO: at this point, we have been cancelled. But our trigger is
             still in the putters. Some taker may [take] the value we had
             offered.  The [take] operation has no idea whether we were
             cancelled. [Trigger.signal] does not return a result!

             Is the behaviour observably equivalent to one where the
             cancellation arrived later than take? It is possible that a single
             fiber / task / thread-of-execution does:

              Computation.cancel comp exn bt;
                (* assume [comp] is associated with the fiber that did this
                [put]. Hence, the trigger [t] is attached to [comp]. *)
              take mvar;
                (* Take the value that's in the mvar, waking up this blocked
                fiber, whose value the MVar now holds. *)
              take mvar;
                (* This [take] may take the value that was offered by this [put]
                i.e., [v], even though the computation associated with the fiber
                has been cancelled. *)
             *)
          remove_trigger ();
          Printexc.raise_with_backtrace exn bt
    end else put mvar v
  | Empty {takers} ->
    match takers with
    | [] ->
      let after = Full {value = v; putters = []} in
      if Atomic.compare_and_set mvar before after then ()
      else put mvar v
    | (hole,trigger)::tl ->
      let after = Empty {takers = tl} in
      if Atomic.compare_and_set mvar before after then begin
        hole := v;
        Trigger.signal trigger
        (* TODO: We have put a value in the [hole] but it may be that the fiber
           was long cancelled and gone but hasn't cleaned up its trigger from
           the takers list. The value [v] has been lost to the ether?

           Or, should this be classified as an acceptable behaviour where the
           cancellation of the taker fiber occurred just after the value was
           taken? But we don't have asynchronous cancellations!! So it seems
           weird that the cancellation can occur after [take] event where the
           fiber was awaiting.

           [Await] way of having the cancellation token with the operations seem
           like a better way where the sync structures have some control. *)
      end else put mvar v

let take _mvar = failwith "not implemented"