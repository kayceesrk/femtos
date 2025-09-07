(** Multiplexers and Schedulers for Femtos

    This module provides different schedulers and multiplexers for managing
    concurrent execution in Femtos applications. *)

(** FIFO cooperative scheduler *)
module Fifo : sig
  include module type of Fifo
end

(** Structured concurrency scheduler with hierarchical scopes *)
module Flock : sig
  include module type of Flock
end
