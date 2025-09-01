(** MVar module for femtos - mutable variable synchronization primitive.

    An MVar is a mutable location that can be either empty or contain a value.
    It provides thread-safe operations for putting and taking values, with
    blocking semantics when the MVar is in the wrong state.

    {v
    State Transitions:

    Empty ----put(value)----> Full(value)
      ^                          |
      |                          |
      +-------take()-------------+

    Notes:
    - Empty: MVar contains no value, put succeeds, take blocks
    - Full: MVar contains a value, take succeeds, put blocks
    - Operations are atomic and multicore-safe
    - Multiple concurrent operations are supported through queueing
    v} *)

(** The type of an MVar containing values of type 'a. *)
type 'a t

(** Create a new empty MVar. *)
val create : unit -> 'a t

(** Create a new MVar with an initial value. *)
val create_full : 'a -> 'a t

(** Put a value into the MVar. If the MVar is full, blocks until it becomes
    empty. *)
val put : 'a t -> 'a -> unit

(** Take a value from the MVar. If the MVar is empty, blocks until a value is
    available. *)
val take : 'a t -> 'a

(** Try to put a value without blocking. Returns true if successful, false if
    MVar is full. *)
val try_put : 'a t -> 'a -> bool

(** Try to take a value without blocking. Returns Some value if successful, None
    if MVar is empty. *)
val try_take : 'a t -> 'a option

(** Check if the MVar is empty. *)
val is_empty : 'a t -> bool

(** Check if the MVar is full. *)
val is_full : 'a t -> bool
