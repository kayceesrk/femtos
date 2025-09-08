(** Multicore-safe terminators for structured concurrency

    A Terminator provides a way to coordinate cancellation across multiple
    triggers and tasks. It allows attaching triggers that will all be signalled
    when the terminator is terminated. This is essential for implementing
    structured concurrency where terminating a scope should signal all
    associated tasks to check for cancellation.

    {v
    Usage Pattern:

    1. Create a terminator for a scope
    2. Attach triggers from tasks in that scope
    3. When scope terminates, call terminate() to signal all attached triggers
    4. Tasks waiting on those triggers check the terminator status and handle cancellation

    Benefits:
    - Ensures no tasks are left running when scopes terminate
    - Provides clean cancellation propagation through signaling
    - Multicore-safe coordination
    - Separates signaling mechanism from cancellation policy
    v} *)

(** The type of a terminator *)
type t

(** Create a terminator *)
val create : unit -> t

(** Terminate the terminator, signalling all attached triggers *)
val terminate : t -> exn -> Printexc.raw_backtrace -> unit

(** Get the termination status and exception.
    Returns [None] if not terminated, [Some (exn, bt)] if terminated. *)
val get_termination : t -> (exn * Printexc.raw_backtrace) option

(** Attach a trigger to the terminator. When the terminator is terminated, all
    attached triggers are signalled. If the trigger is signalled, it is detached
    from the terminator.

    Returns [true] if the trigger was successfully attached, [false] if the
    terminator was already terminated. *)
val attach : t -> Femtos_core.Trigger.t -> bool

(** Detach a trigger from the terminator. The trigger will no longer be
    signalled when the terminator is terminated.

    Returns [true] if the trigger was successfully detached, [false] if the
    trigger was not attached to the terminator. *)
val detach : t -> Femtos_core.Trigger.t -> bool

(** Forward the state of one trigger to another. If [from_terminator] is
    signalled, [to_terminator] is signalled. If [from_terminator] is terminated,
    [to_terminator] is terminated with the same exception and backtrace.

    Returns [true] if the forward was successfully set up, [false] if
    [from_terminator] was already terminated. *)
val forward : from_terminator:t -> to_terminator:t -> bool
