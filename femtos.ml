(** Femtos - A lightweight synchronization library for OCaml *)

module Trigger = Femtos_core.Trigger

module Sync = struct
  module Ivar = Femtos_sync.Ivar
  module Mvar = Femtos_sync.Mvar
  module Mutex = Femtos_sync.Mutex
  module Terminator = Femtos_sync.Terminator
end

module Mux = struct
  module Fifo = Femtos_mux.Fifo
  module Flock = Femtos_mux.Flock
end
