(** Structured Concurrency Scheduler with Hierarchical Scopes

    The Flock scheduler implements structured concurrency with three core primitives:

    1. {!finish} - Creates a new scope and waits for all async tasks within it to complete
    2. {!async} - Spawns a new task in the current scope
    3. {!terminate} - Terminates the current scope (raises exception)

    Key features:
    - Self-contained scheduler (no dependency on other schedulers)
    - Exception-based termination (any exception terminates the scope)
    - Proper exception propagation from async tasks
    - Hierarchical cancellation: terminating a scope cancels all nested scopes
    - Structured concurrency guarantees: finish waits for all spawned tasks
*)

(** Exception raised to terminate a scope *)
exception Terminated of exn

(** {1 Core Structured Concurrency Primitives} *)

val finish : (unit -> 'a) -> 'a
(** [finish f] creates a new structured concurrency scope and executes [f] within it.
    The function [f] is executed in a new scope that:
    - Waits for all tasks spawned with [async] within [f] to complete before returning
    - Propagates any exceptions from async tasks to terminate the entire scope
    - Links cancellation from parent to all child tasks

    If any async task raises an exception, the entire scope is terminated and the
    exception is propagated.
*)

val async : (unit -> unit) -> unit
(** [async f] spawns a new concurrent task [f] in the current scope.
    The task:
    - Executes concurrently with other tasks in the same scope
    - Must complete before the enclosing [finish] scope can return
    - Any exception raised by the task will terminate the entire scope

    Note: [async] must be called within a [finish] scope.
*)

val terminate : unit -> 'a
(** [terminate ()] terminates the current scope by raising a [Terminated] exception.
    This will:
    - Cancel all running async tasks in the current scope
    - Propagate cancellation to all nested scopes
    - Never return (always raises an exception)

    Note: Any exception can be used to terminate a scope, [terminate] is just
    a convenience function.
*)

(** {1 Main Entry Point} *)

val run : (unit -> 'a) -> 'a
(** [run f] executes a structured concurrent program with a self-contained scheduler.
    This is the main entry point that:
    1. Sets up the necessary effect handlers for structured concurrency
    2. Creates a root scope with its own terminator
    3. Executes [f] within this root scope
    4. Returns the final result

    The scheduler is completely self-contained and does not depend on other schedulers.
*)