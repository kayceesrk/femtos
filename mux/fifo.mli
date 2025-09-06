(** FIFO scheduler for femtos - First-In-First-Out cooperative scheduling.

    This module provides a simple cooperative scheduler that manages lightweight
    threads (fibers) using a FIFO (First-In-First-Out) queue. It implements
    effect handlers for concurrency primitives like forking and yielding.

    The scheduler maintains a queue of runnable fibers and executes them in the
    order they were added to the queue. When a fiber yields or forks, control is
    transferred to the next fiber in the queue.

    {b Example usage:}
    {[
      let main () =
        fork (fun () -> print_endline "Child fiber") ;
        print_endline "Main fiber" ;
        yield () ;
        print_endline "Main fiber continues"
      in
      run main
    ]} *)

(** [fork f] creates a new lightweight thread (fiber) that will execute function
    [f] concurrently with the current fiber. The new fiber is added to the end
    of the scheduler's run queue and will be executed when the scheduler reaches
    it.

    Note: This is a cooperative operation - the current fiber continues
    execution immediately after forking. *)
val fork : (unit -> unit) -> unit

(** [yield ()] voluntarily gives up control to allow other fibers to run. The
    current fiber is moved to the end of the run queue and will be resumed later
    when the scheduler reaches it again.

    This is useful for implementing cooperative multitasking and ensuring other
    fibers get a chance to execute. *)
val yield : unit -> unit

(** [run main] starts the FIFO scheduler with [main] as the initial fiber. The
    scheduler will continue running until all fibers have completed execution or
    are blocked on triggers.

    The scheduler handles the following effects:
    - [Fork]: Creates new concurrent fibers
    - [Yield]: Cooperative yielding between fibers
    - [Trigger.Await]: Integration with the trigger synchronization system

    Any uncaught exceptions in fibers are caught and printed to stderr, allowing
    other fibers to continue execution.

    @param main The initial function to execute *)
val run : (unit -> unit) -> unit
