(** Femtos - A lightweight synchronization library for OCaml

    This library provides structured concurrency primitives for OCaml,
    including triggers for signaling and synchronization variables.
*)

(** Low-level trigger mechanism for synchronization *)
module Trigger : sig
  type t
  val create : unit -> t
  val signal : t -> bool
  val cancel : t -> exn -> Printexc.raw_backtrace -> bool
  type _ Effect.t += Await : t -> (exn * Printexc.raw_backtrace) option Effect.t
  val on_signal : t -> (t -> unit) -> bool
end

(** Synchronization primitives *)
module Sync : sig
  (** Single-assignment variables (write-once) *)
  module Ivar : sig
    type 'a t
    val create : unit -> 'a t
    val try_fill : 'a t -> 'a -> bool
    val read : 'a t -> 'a
  end

  (** Mutable variables with blocking semantics *)
  module Mvar : sig
    type 'a t
    val create : unit -> 'a t
    val create_full : 'a -> 'a t
    val put : 'a t -> 'a -> unit
    val take : 'a t -> 'a
  end
end
