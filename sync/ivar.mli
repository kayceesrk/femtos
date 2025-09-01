(** The type of promises *)
type 'a t

(** Create an unfilled promise *)
val create : unit -> 'a t

exception Already_filled

(** Fill the promise with a value . Raises [ Already_filled ] exception if the
    promise is already filled . *)
val fill : 'a t -> 'a -> unit

(** If the promise is filled , returns the value in the promise . Otherwise ,
    blocks the calling task until the promise is filled and returns the filled
    value . *)
val await : 'a t -> 'a
