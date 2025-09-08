(** Condition variables for femtos - synchronization primitive for waiting on conditions.

    A condition variable allows threads to wait until a particular condition becomes true.
    Condition variables must be used in conjunction with a mutex to avoid race conditions.

    Typical usage pattern:
    {v
    let mutex = Mutex.create () in
    let condition = Condition.create () in

    (* Waiter thread *)
    Mutex.lock mutex;
    while not !some_condition do
      Condition.wait condition mutex;
    done;
    (* condition is now true and mutex is held *)
    Mutex.unlock mutex;

    (* Signaler thread *)
    Mutex.lock mutex;
    some_condition := true;
    Condition.signal condition; (* or broadcast *)
    Mutex.unlock mutex;
    v} *)

(** The type of a condition variable. *)
type t

(** Create a new condition variable. *)
val create : unit -> t

(** [wait condition mutex] atomically releases the mutex and waits for the condition
    to be signaled. When the condition is signaled, the mutex is reacquired before
    returning. The mutex must be held when calling this function.
    @param condition The condition variable to wait on
    @param mutex The mutex that must be held when calling wait
    @raise Failure if the mutex is not currently locked *)
val wait : t -> Mutex.t -> unit

(** [signal condition] wakes up one thread waiting on the condition variable.
    If no threads are waiting, this is a no-op. *)
val signal : t -> unit

(** [broadcast condition] wakes up all threads waiting on the condition variable.
    If no threads are waiting, this is a no-op. *)
val broadcast : t -> unit
