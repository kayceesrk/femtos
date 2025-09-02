(** The type of promises *)
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
