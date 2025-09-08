# Femtos

[![OCaml](https://img.shields.io/badge/OCaml-5.x-orange.svg)](https://ocaml.org/)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)

**Femtos** is an experimental structured concurrency library for OCaml 5.x, designed  
to explore the semantics of composable concurrency using effect handlers.

> **⚠️ Experimental Research Library**  
> Femtos is a research project for understanding structured concurrency semantics and is  
> **not intended for production use**. For production applications, please use these mature  
> alternatives:
>
> - **[Picos](https://github.com/ocaml-multicore/picos)** - Systematic approach to interoperable concurrency
> - **[JaneStreet Await](https://github.com/janestreet/await/tree/with-extensions)** - Production-ready structured concurrency
> - **[Eio](https://github.com/ocaml-multicore/eio)** - Full-featured effects-based I/O and concurrency

## Features

🔄 **Structured Concurrency**: Hierarchical task management with automatic cleanup
⚡ **Effect Handlers**: Built on OCaml 5.x's native effect system
🧵 **Multiple Schedulers**: FIFO cooperative scheduler and Flock structured scheduler
🔒 **Synchronization Primitives**: Ivar (promises), Mvar (channels), and Terminators
🛡️ **Exception Safety**: Proper exception propagation and resource cleanup
🚀 **Lightweight**: Minimal overhead with efficient cooperative multitasking

## Quick Start

### Installation

```bash
opam install femtos
```

Or build from source:

```bash
git clone https://github.com/kayceesrk/femtos.git
cd femtos
dune build
dune install
```

> **Note**: Femtos is experimental software for research purposes. For production  
> applications, we recommend [Picos](https://github.com/ocaml-multicore/picos),  
> [JaneStreet Await](https://github.com/janestreet/await/tree/with-extensions),  
> or [Eio](https://github.com/ocaml-multicore/eio).

### Structured Concurrency Example

```ocaml
open Femtos

let main () =
  (* Create a structured scope - all tasks will complete before returning *)
  Mux.Flock.finish (fun () ->
    (* Spawn concurrent tasks *)
    Mux.Flock.async (fun () ->
      print_endline "Task 1 running");

    Mux.Flock.async (fun () ->
      print_endline "Task 2 running");

    print_endline "Main task";
    "All tasks completed"  (* This won't return until all async tasks finish *)
  )

let () = Mux.Flock.run main |> print_endline
```

### Cooperative Multitasking Example

```ocaml
open Femtos

let main terminator =
  (* Fork a child fiber *)
  Mux.Fifo.fork (fun _ ->
    print_endline "Child fiber running");

  print_endline "Main fiber";

  (* Yield control to other fibers *)
  Mux.Fifo.yield ();

  print_endline "Main fiber continues"

let () = Mux.Fifo.run main
```

### Synchronization with Promises (Ivar)

```ocaml
open Femtos

let main () =
  Mux.Flock.finish (fun () ->
    let promise = Sync.Ivar.create () in

    (* Producer task *)
    Mux.Flock.async (fun () ->
      Unix.sleepf 0.1;
      Sync.Ivar.try_fill promise "Hello from async task!" |> ignore);

    (* Consumer task *)
    Mux.Flock.async (fun () ->
      let result = Sync.Ivar.read promise in  (* Blocks until filled *)
      print_endline ("Received: " ^ result));

    "Communication complete"
  )

let () = Mux.Flock.run main |> print_endline
```

### Producer-Consumer with MVar

```ocaml
open Femtos

let main () =
  Mux.Flock.finish (fun () ->
    let channel = Sync.Mvar.create () in

    (* Producer *)
    Mux.Flock.async (fun () ->
      for i = 1 to 3 do
        Sync.Mvar.put channel i;
        Printf.printf "Produced: %d\n%!" i
      done);

    (* Consumer *)
    Mux.Flock.async (fun () ->
      for _ = 1 to 3 do
        let value = Sync.Mvar.take channel in
        Printf.printf "Consumed: %d\n%!" value
      done);

    "Producer-consumer complete"
  )

let () = Mux.Flock.run main |> print_endline
```

## Core Concepts

### Structured Concurrency

Femtos implements structured concurrency through the **Flock** scheduler:

- **`finish`** - Creates a scope that waits for all spawned tasks
- **`async`** - Spawns a task within the current scope
- **Exception propagation** - Any task failure terminates the entire scope
- **Automatic cleanup** - Resources are cleaned up when scopes end

```ocaml
Mux.Flock.finish (fun () ->
  Mux.Flock.async (fun () -> failwith "This will terminate the entire scope");
  Mux.Flock.async (fun () -> print_endline "This might not run");
  "This won't be reached"
)
```

### Cooperative Multitasking

The **FIFO** scheduler provides cooperative multitasking:

- **`fork`** - Creates concurrent fibers
- **`yield`** - Voluntarily gives up control
- **FIFO scheduling** - First-in-first-out execution order

### Synchronization Primitives

**Ivar (Single-assignment variables)**:

- Write-once, read-many semantics
- Blocking reads until value is available
- Perfect for promises and futures

**MVar (Mutable variables)**:

- Put/take operations with blocking
- Empty ↔ Full state transitions
- Great for producer-consumer patterns

**Terminator**:

- Coordinates cancellation across multiple tasks
- Used internally by structured concurrency
- Multicore-safe cancellation propagation

## API Documentation

### Modules

- **`Femtos.Trigger`** - Low-level signaling mechanism
- **`Femtos.Sync.Ivar`** - Single-assignment variables (promises)
- **`Femtos.Sync.Mvar`** - Mutable variables with blocking
- **`Femtos.Sync.Terminator`** - Cancellation coordination
- **`Femtos.Mux.Fifo`** - FIFO cooperative scheduler
- **`Femtos.Mux.Flock`** - Structured concurrency scheduler

### Key Functions

**Structured Concurrency**:

```ocaml
val Mux.Flock.run : (unit -> 'a) -> 'a
val Mux.Flock.finish : (unit -> 'a) -> 'a
val Mux.Flock.async : (unit -> unit) -> unit
val Mux.Flock.terminate : unit -> 'a
```

**Cooperative Scheduling**:

```ocaml
val Mux.Fifo.run : (Sync.Terminator.t -> unit) -> unit
val Mux.Fifo.fork : (Sync.Terminator.t -> unit) -> unit
val Mux.Fifo.yield : unit -> unit
```

**Synchronization**:

```ocaml
val Sync.Ivar.create : unit -> 'a t
val Sync.Ivar.try_fill : 'a t -> 'a -> bool
val Sync.Ivar.read : 'a t -> 'a

val Sync.Mvar.create : unit -> 'a t
val Sync.Mvar.put : 'a t -> 'a -> unit
val Sync.Mvar.take : 'a t -> 'a
```

## Build Documentation

Generate API documentation with odoc:

```bash
dune build @doc
open _build/default/_doc/_html/index.html
```

## Examples

The repository includes comprehensive examples in the `test/` directory:

- **`test_flock.ml`** - Basic structured concurrency patterns
- **`test_flock_cancellation.ml`** - Advanced cancellation scenarios
- **`test_ivar.ml`** - Promise/future patterns
- **`test_mvar.ml`** - Producer-consumer examples
- **`test_scheduler_integration.ml`** - Scheduler interoperability

Run tests:

```bash
dune exec test/test_femtos.exe
dune exec test/test_flock_cancellation.exe
```

## Design Philosophy

### Design Principles

Femtos implements [structured concurrency](https://en.wikipedia.org/wiki/Structured_concurrency) principles:

1. **Hierarchical Task Management** - Tasks are organized in scopes
2. **Automatic Resource Cleanup** - Resources are cleaned up when scopes end
3. **Exception Safety** - Failures propagate and terminate related tasks
4. **No Orphaned Tasks** - All spawned tasks complete before scope ends

### Why Effect Handlers?

OCaml 5.x's effect handlers provide:

- **Zero-allocation** cooperative switching in many cases
- **Composable** synchronization primitives
- **Type-safe** concurrency without callback hell
- **Efficient** scheduling with minimal runtime overhead

## Comparison with Other Libraries

| Feature | Femtos | Picos | Await | Lwt | Async | Eio |
|---------|--------|-------|-------|-----|-------|-----|
| Structured Concurrency | 🧪 | ✅ | ✅ | ❌ | ❌ | ✅ |
| Effect Handlers | ✅ | ✅ | ✅ | ❌ | ❌ | ✅ |
| Production Ready | ❌ | ✅ | ✅ | ✅ | ✅ | ✅ |
| IO Integration | ❌ | ⚠️ | ✅ | ✅ | ✅ | ✅ |
| Interoperability | ❌ | ✅ | ⚠️ | ⚠️ | ❌ | ⚠️ |

**🧪 Femtos** is designed for:

- **Research and experimentation** with structured concurrency semantics
- Learning structured concurrency concepts through hands-on exploration
- Understanding effect handler composition patterns
- Academic study of concurrent programming models

**🏭 For Production Use:**

- **[Picos](https://github.com/ocaml-multicore/picos)** - Systematic approach to interoperable concurrency libraries
- **[JaneStreet Await](https://github.com/janestreet/await/tree/with-extensions)** -  
  Industrial-strength structured concurrency
- **[Eio](https://github.com/ocaml-multicore/eio)** - Full-featured effects-based I/O  
  and structured concurrency

## Requirements

- **OCaml 5.0+** (for effect handlers)
- **Dune 3.0+** (for build system)

## Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch
3. Add tests for new functionality
4. Ensure `dune build` passes
5. Submit a pull request

## License

MIT License. See [LICENSE](LICENSE) file for details.

## Related Work

- [Structured Concurrency](https://vorpus.org/blog/notes-on-structured-concurrency-or-go-statement-considered-harmful/)  
  by Nathaniel J. Smith
- [Eio](https://github.com/ocaml-multicore/eio) - OCaml structured concurrency with IO
- [OCaml 5.0 Effects](https://v2.ocaml.org/manual/effects.html) - Official effect handlers documentation

---

**Femtos** - *Small and light, but structured* 🦋
