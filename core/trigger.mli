(** Trigger module for femtos - one-shot sleep and wake up mechanism.

    A trigger is a synchronization primitive that can be used to signal that an
    event has occurred. The trigger is in one of 3 states -- [Initialized],
    [Signaled], or [Waiting callback]. Trigger allows exactly one callback to be
    registered exactly once. This callback is called when the trigger is
    signaled.

    {v
    State Transition Diagram:

                 on_signal
    Initialized -----------> Waiting(callback)
         |                        |
         | signal                 | signal
         |                        | (calls callback)
         v                        v
      Signaled <------------------+

    Notes:
    - Initialized: Fresh trigger, no callback registered
    - Waiting: Callback registered, waiting for signal
    - Signaled: Trigger has been signaled (terminal state)
    - All transitions are atomic and multicore-safe
    - Once Signaled, the trigger cannot transition to other states
    v} *)

(** The type of a trigger. *)
type t

(** Create a new trigger. *)
val create : unit -> t

(** Signal the trigger with a value. *)
val signal : t -> unit

(** Wait for the trigger to be signaled. Returns the value passed to signal. *)
type _ Effect.t += Await : t -> (exn * Printexc.raw_backtrace) option Effect.t

(** Register a callback to be called when the trigger is signaled. Is called by
    the handler of [Await] i.e., the scheduler.

    Returns [true] if the callback was successfully registered. *)
val on_signal : t -> (unit -> unit) -> bool
