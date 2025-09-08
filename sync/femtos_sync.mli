(** Synchronization primitives for Femtos

    This module provides high-level synchronization primitives built on top of
    the core trigger mechanism. These primitives include single-assignment
    variables (Ivar), mutable variables with blocking semantics (Mvar), and
    terminators for structured concurrency. *)

(** Single-assignment variables (write-once promises) *)
module Ivar : sig
  include module type of Ivar
end

(** Mutable variables with blocking semantics *)
module Mvar : sig
  include module type of Mvar
end

(** Multicore-safe terminators for structured concurrency *)
module Terminator : sig
  type t

  (** Create a terminator *)
  val create : unit -> t

  (** Terminate the terminator, signalling all attached triggers *)
  val terminate : t -> exn -> Printexc.raw_backtrace -> unit

  (** Get the termination status and exception.
      Returns [None] if not terminated, [Some (exn, bt)] if terminated. *)
  val get_termination : t -> (exn * Printexc.raw_backtrace) option

  (** Attach a trigger to the terminator. When the terminator is terminated, all
      attached triggers are signalled. If the trigger is signalled, it is
      detached from the terminator.

      Returns [true] if the trigger was successfully attached, [false] if the
      terminator was already terminated. *)
  val attach : t -> Femtos_core.Trigger.t -> bool

  (** Detach a trigger from the terminator. The trigger will no longer be
      signalled when the terminator is terminated.

      Returns [true] if the trigger was successfully detached, [false] if the
      trigger was not attached to the terminator. *)
  val detach : t -> Femtos_core.Trigger.t -> bool

  (** Forward the state of one trigger to another. If [from_terminator] is
      signalled, [to_terminator] is signalled. If [from_terminator] is
      terminated, [to_terminator] is terminated with the same exception and
      backtrace.

      Returns [true] if the forward was successfully set up, [false] if
      [from_terminator] was already terminated. *)
  val forward : from_terminator:t -> to_terminator:t -> bool
end
