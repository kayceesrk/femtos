(** Femtos - A lightweight synchronization library for OCaml *)

module Trigger = Femtos_core.Trigger

module Sync = struct
  module Ivar = Femtos_sync.Ivar
  module Mvar = Femtos_sync.Mvar
end
