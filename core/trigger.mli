(** Trigger module for femtos - one-shot sleep and wake up mechanism.

    A trigger is a synchronization primitive that can be used to signal that an
    event has occurred. The trigger is in one of 3 states -- [Initialized],
    [Signaled], [Calcelled (exn, bt)] or [Waiting callback]. Trigger allows
    exactly one callback to be registered exactly once. This callback is called
    when the trigger is signaled. *)

(** The type of a trigger. *)
type t

(** Create a new trigger. *)
val create : unit -> t

(** Signal the trigger. If the trigger has already been signaled or canceled,
    returns [false]. Otherwise, returns [true]. *)
val signal : t -> bool

(** Cancel the trigger with an exception and a backtrace. If the trigger has
    already been signaled or canceled, returns [false]. Otherwise, returns
    [true]. *)
val cancel : t -> exn -> Printexc.raw_backtrace -> bool

(** Wait for the trigger to be signaled. Returns the value passed to signal. *)
type _ Effect.t += Await : t -> (exn * Printexc.raw_backtrace) option Effect.t

(** {1 Scheduler interface}

   This interface provides the necessary functions for the scheduler to interact
   with triggers and manage their lifecycle.

*)

(** Register a callback to be called when the trigger is signaled. Is called by
    the handler of [Await] i.e., the scheduler. Returns [true] if the callback
    was successfully registered. *)
val on_signal : t -> (t -> unit) -> bool

(** Get the current status of the trigger. *)
val status : t -> [`Signalled | `Cancelled of exn * Printexc.raw_backtrace]
