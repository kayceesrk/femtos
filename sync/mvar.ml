(** MVar implementation using Trigger *)

open Femtos_core

type 'a state =
  (* TODO: Replace list with queue. Not the right semantics now. But doesn't
     matter. Assume it is a queue for now. *)
  | Empty of { takers : ('a ref * Trigger.t) list }
  | Full of { value : 'a; putters : ('a * Trigger.t) list }

type 'a t = 'a state Atomic.t

let create () = Atomic.make (Empty { takers = [] })
let create_full value = Atomic.make (Full { value; putters = [] })
let remove_trigger () = () (* TBD *)

let rec put mvar v =
  let before = Atomic.get mvar in
  match before with
  | Full { value; putters } ->
    let t = Trigger.create () in
    let after = Full { value; putters = (v, t) :: putters } in
    if Atomic.compare_and_set mvar before after then (
      match Effect.perform (Trigger.Await t) with
      | None -> () (* put succeeded *)
      | Some (exn, bt) ->
        remove_trigger () ;
        Printexc.raise_with_backtrace exn bt)
    else put mvar v
  | Empty { takers } -> (
    match takers with
    | [] ->
      let after = Full { value = v; putters = [] } in
      if Atomic.compare_and_set mvar before after then () else put mvar v
    | (hole, trigger) :: tl ->
      let after = Empty { takers = tl } in
      if Atomic.compare_and_set mvar before after then (
        (* Matched with a taker *)
        hole := v ;
        (* Give the taker the value *)
        if Trigger.signal trigger then
          (* Taker successfully signaled *)
          ()
        else
          (* Taker must have been cancelled. Try again. *)
          put mvar v)
      else
        (* CAS failed, try again! *)
        put mvar v)

let rec take mvar =
  let before = Atomic.get mvar in
  match before with
  | Empty { takers } ->
    let hole = ref (Obj.magic ()) in
    let trigger = Trigger.create () in
    let after = Empty { takers = (hole, trigger) :: takers } in
    if Atomic.compare_and_set mvar before after then (
      match Effect.perform (Trigger.Await trigger) with
      | None -> !hole
      | Some (exn, bt) ->
        remove_trigger () ;
        Printexc.raise_with_backtrace exn bt)
    else take mvar
  | Full { value; putters } -> (
    match putters with
    | [] ->
      let after = Empty { takers = [] } in
      if Atomic.compare_and_set mvar before after then value else take mvar
    | (v, trigger) :: tl ->
      let after = Full { value = v; putters = tl } in
      if Atomic.compare_and_set mvar before after then
        (* Matched with a putter *)
        if Trigger.signal trigger then
          (* Putter successfully signaled *)
          value
        else
          (* Putter must have been cancelled. Try again. *)
          take mvar
      else
        (* CAS failed, try again! *)
        take mvar)
