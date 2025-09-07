(** Core synchronization primitives for Femtos

    This module provides the low-level trigger mechanism that forms the
    foundation for all synchronization primitives in Femtos. *)

(** Low-level trigger mechanism for synchronization *)
module Trigger : sig
  include module type of Trigger
end
