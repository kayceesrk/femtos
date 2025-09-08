(** Mutex module for femtos - mutual exclusion synchronization primitive.

    A Mutex provides mutual exclusion, ensuring that only one thread can hold
    the lock at a time. It provides thread-safe operations for acquiring and
    releasing the lock, with blocking semantics when the mutex is already locked.

    {v
    State Transitions:

    Unlocked ----lock()----> Locked
        ^                      |
        |                      |
        +-----unlock()--------+

    Notes:
    - Unlocked: Mutex is available, lock succeeds immediately
    - Locked: Mutex is held, lock blocks until released
    - Operations are atomic and multicore-safe
    - Multiple concurrent lock attempts are supported through queueing
    - unlock must be called by the same thread that called lock
    v} *)

(** The type of a mutex. *)
type t

(** Create a new unlocked mutex. *)
val create : unit -> t

(** Acquire the mutex lock. Blocks if the mutex is already locked.
    The operation may be cancelled by the scheduler's terminator. *)
val lock : t -> unit

(** Release the mutex lock. The mutex must be currently locked.
    @raise Failure if the mutex is not locked. *)
val unlock : t -> unit

(** Try to acquire the mutex lock without blocking.
    @return [true] if the lock was acquired, [false] if already locked. *)
val try_lock : t -> bool

(** Check if the mutex is currently locked.
    @return [true] if locked, [false] if unlocked. *)
val is_locked : t -> bool
