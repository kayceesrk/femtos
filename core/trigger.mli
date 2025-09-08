(** Trigger module for femtos - one-shot sleep and wake up mechanism.

    A trigger is a synchronization primitive that can be used to signal that an
    event has occurred. The trigger is in one of 3 states -- [Initialized],
    [Signaled], or [Waiting callback]. Trigger allows exactly one callback to
    be registered exactly once. This callback is called when the trigger is signaled.

    Cancellation is handled by higher-level abstractions (schedulers) consulting
    terminators rather than being built into the trigger itself. *)

(** The type of a trigger. *)
type t

(** Create a new trigger. *)
val create : unit -> t

(** Signal the trigger. If the trigger has already been signaled, returns [false].
    Otherwise, returns [true]. *)
val signal : t -> bool

(** Wait for the trigger to be signaled. The scheduler is responsible for
    consulting terminators to determine if cancellation should occur.
    Returns [None] if signaled normally, [Some (exn, bt)] if cancelled. *)
type _ Effect.t += Await : t -> (exn * Printexc.raw_backtrace) option Effect.t

(** {1 Scheduler interface}

    This interface provides the necessary functions for the scheduler to
    interact with triggers and manage their lifecycle. *)

(** Register a callback to be called when the trigger is signaled. Is called by
    the handler of [Await] i.e., the scheduler. Returns [true] if the callback
    was successfully registered. *)
val on_signal : t -> (t -> unit) -> bool

(** Check if the trigger has been signaled. *)
val is_signalled : t -> bool
