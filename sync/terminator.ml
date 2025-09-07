(** Internal state of a terminator *)
type state =
  | Active of Femtos_core.Trigger.t list
      (** Active with list of attached triggers *)
  | Terminated of exn * Printexc.raw_backtrace  (** Terminated with exception *)

type t = state Atomic.t

let create () = Atomic.make (Active [])

let terminate terminator exn bt =
  let rec loop () =
    let current_state = Atomic.get terminator in
    match current_state with
    | Terminated _ -> () (* Already terminated, nothing to do *)
    | Active triggers ->
      (* Try to atomically transition to terminated state *)
      if Atomic.compare_and_set terminator current_state (Terminated (exn, bt))
      then
        (* Successfully terminated, now cancel all attached triggers *)
        List.iter
          (fun trigger ->
            let _ = Femtos_core.Trigger.cancel trigger exn bt in
            ())
          triggers
      else
        (* CAS failed, state changed, retry *)
        loop ()
  in
  loop ()

let is_terminated (t : t) : bool = match Atomic.get t with
| Terminated _ -> true
| _ -> false

let attach terminator trigger =
  let rec loop () =
    let current_state = Atomic.get terminator in
    match current_state with
    | Terminated (exn, bt) ->
      (* Terminator already terminated, cancel the trigger and return false *)
      let _ = Femtos_core.Trigger.cancel trigger exn bt in
      false
    | Active triggers ->
      (* Check if trigger is already in the list to avoid duplicates *)
      if List.memq trigger triggers then true (* Already attached *)
      else
        let new_state = Active (trigger :: triggers) in
        if Atomic.compare_and_set terminator current_state new_state then
          (* Successfully attached *)
          true
        else
          (* CAS failed, retry *)
          loop ()
  in
  loop ()

let detach terminator trigger =
  let rec loop () =
    let current_state = Atomic.get terminator in
    match current_state with
    | Terminated _ ->
      (* Terminator terminated, consider it "detached" *)
      false
    | Active triggers ->
      if List.memq trigger triggers then
        (* Trigger is attached, remove it *)
        let new_triggers = List.filter (fun t -> not (t == trigger)) triggers in
        let new_state = Active new_triggers in
        if Atomic.compare_and_set terminator current_state new_state then true
          (* Successfully detached *)
        else loop () (* CAS failed, retry *)
      else
        (* Trigger not attached *)
        false
  in
  loop ()

let forward ~from_terminator ~to_terminator =
  (* Create a trigger for forwarding *)
  let forward_trigger = Femtos_core.Trigger.create () in

  (* Set up callback to forward signals/cancellations *)
  let callback _trigger =
    match Femtos_core.Trigger.status forward_trigger with
    | `Signalled ->
      (* Forward signal: terminate to_terminator with a forwarded exception *)
      let forwarded_exn = Failure "Forwarded termination" in
      terminate to_terminator forwarded_exn (Printexc.get_callstack 10)
    | `Cancelled (exn, bt) ->
      (* Forward cancellation *)
      terminate to_terminator exn bt
  in

  (* Register the callback first *)
  if Femtos_core.Trigger.on_signal forward_trigger callback then
    (* Now try to attach the configured trigger to the from_terminator *)
    attach from_terminator forward_trigger
  else
    (* Failed to register callback *)
    false
