(** Single-assignment variables (promises) for femtos

    An Ivar (incremental variable) is a write-once variable that can be filled
    with a value exactly once. Once filled, any number of readers can read the
    value. If readers attempt to read before the Ivar is filled, they will block
    until a value becomes available.

    {v
    State Transitions:

    Empty ----try_fill(value)----> Filled(value)
      |                               |
      +-------read() blocks-----------+-------read() returns value

    Notes:
    - Empty: Ivar contains no value, try_fill succeeds, read blocks
    - Filled: Ivar contains a value, try_fill fails, read returns immediately
    - Multiple readers are supported (broadcast semantics)
    - Only the first try_fill succeeds, subsequent attempts return false
    v} *)

(** The type of promises containing values of type 'a *)
type 'a t

(** Create an unfilled promise *)
val create : unit -> 'a t

(** Fill the promise with a value. Returns [true] if the promise was
    successfully filled, [false] if it was already filled. *)
val try_fill : 'a t -> 'a -> bool

(** If the promise is filled, returns the value in the promise. Otherwise,
    blocks the calling task until the promise is filled and returns the filled
    value. *)
val read : 'a t -> 'a
