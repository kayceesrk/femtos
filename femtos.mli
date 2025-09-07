(** Femtos - Lightweight structured concurrency library for OCaml

    Femtos provides structured concurrency primitives for OCaml 5.x, built on
    effect handlers for efficient cooperative multitasking. The library includes:

    - {!Trigger}: Low-level signaling mechanism
    - {!Sync}: High-level synchronization primitives (Ivar, Mvar, Terminator)
    - {!Mux}: Schedulers and multiplexers (FIFO, Flock)

    {1 Quick Start}

    For structured concurrency with automatic cleanup:
    {[
      open Femtos

      let main () =
        Mux.Flock.finish (fun () ->
          Mux.Flock.async (fun () -> print_endline "Task 1");
          Mux.Flock.async (fun () -> print_endline "Task 2");
          "All tasks completed"
        )

      let () = Mux.Flock.run main |> print_endline
    ]}

    For cooperative multitasking:
    {[
      open Femtos

      let main terminator =
        Mux.Fifo.fork (fun _ -> print_endline "Child fiber");
        print_endline "Main fiber";
        Mux.Fifo.yield ();
        print_endline "Main continues"

      let () = Mux.Fifo.run main
    ]}
*)

(** Low-level trigger mechanism for synchronization *)
module Trigger : sig
  type t

  val create : unit -> t
  val signal : t -> bool
  val cancel : t -> exn -> Printexc.raw_backtrace -> bool

  type _ Effect.t += Await : t -> (exn * Printexc.raw_backtrace) option Effect.t

  val on_signal : t -> (t -> unit) -> bool
end

(** Synchronization primitives *)
module Sync : sig
  (** Single-assignment variables (write-once) *)
  module Ivar : sig
    type 'a t

    val create : unit -> 'a t
    val try_fill : 'a t -> 'a -> bool
    val read : 'a t -> 'a
  end

  (** Mutable variables with blocking semantics *)
  module Mvar : sig
    type 'a t

    val create : unit -> 'a t
    val create_full : 'a -> 'a t
    val put : 'a t -> 'a -> unit
    val take : 'a t -> 'a
  end

  (** Multicore-safe terminators for structured concurrency *)
  module Terminator : sig
    type t

    (** Create a terminator *)
    val create : unit -> t

    (** Terminate the terminator, cancelling all attached triggers *)
    val terminate : t -> exn -> Printexc.raw_backtrace -> unit

    (** Attach a trigger to the terminator. When the terminator is terminated,
        all attached triggers are cancelled. If the trigger is signalled, it is
        detached from the terminator.

        Returns [true] if the trigger was successfully attached, [false] if the
        terminator was already terminated. *)
    val attach : t -> Trigger.t -> bool

    (** Detach a trigger from the terminator. The trigger will no longer be
        cancelled when the terminator is terminated.

        Returns [true] if the trigger was successfully detached, [false] if the
        trigger was not attached to the terminator. *)
    val detach : t -> Trigger.t -> bool

    (** Forward the state of one trigger to another. If [from_terminator] is
        signalled, [to_terminator] is signalled. If [from_terminator] is
        cancelled, [to_terminator] is cancelled with the same exception and
        backtrace.

        Returns [true] if the forward was successfully set up, [false] if
        [from_terminator] was already cancelled. *)
    val forward : from_terminator:t -> to_terminator:t -> bool
  end
end

(** Cooperative schedulers and multiplexers *)
module Mux : sig
  (** FIFO scheduler for cooperative multitasking.

      This module provides a simple cooperative scheduler that manages
      lightweight threads (fibers) using a FIFO (First-In-First-Out) queue. It
      implements effect handlers for concurrency primitives like forking and
      yielding. *)
  module Fifo : sig
    (** [fork f] creates a new lightweight thread (fiber) that will execute
        function [f] concurrently with the current fiber. The new fiber is added
        to the end of the scheduler's run queue and will be executed when the
        scheduler reaches it.

        Note: This is a cooperative operation - the current fiber continues
        execution immediately after forking. *)
    val fork : (Sync.Terminator.t -> unit) -> unit

    (** [yield ()] voluntarily gives up control to allow other fibers to run.
        The current fiber is moved to the end of the run queue and will be
        resumed later when the scheduler reaches it again.

        This is useful for implementing cooperative multitasking and ensuring
        other fibers get a chance to execute. *)
    val yield : unit -> unit

    (** [run main] starts the FIFO scheduler with [main] as the initial fiber.
        The scheduler will continue running until all fibers have completed
        execution or are blocked on triggers.

        The scheduler handles the following effects:
        - [Fork]: Creates new concurrent fibers
        - [Yield]: Cooperative yielding between fibers
        - [Trigger.Await]: Integration with the trigger synchronization system

        Any uncaught exceptions in fibers are caught and printed to stderr,
        allowing other fibers to continue execution.

        @param main The initial function to execute *)
    val run : (Sync.Terminator.t -> unit) -> unit
  end
end
