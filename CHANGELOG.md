# Changelog

All notable changes to Femtos will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Initial release of Femtos structured concurrency library
- Core synchronization primitives (Trigger, Ivar, Mvar, Terminator)
- Two schedulers: FIFO cooperative scheduler and Flock structured concurrency scheduler
- Comprehensive test suite with cancellation scenarios
- Complete API documentation with odoc
- Support for OCaml 5.x effect handlers

### Features
- **Structured Concurrency**: Hierarchical task management with automatic cleanup
- **Effect Handlers**: Built on OCaml 5.x's native effect system
- **Multiple Schedulers**: FIFO cooperative scheduler and Flock structured scheduler
- **Synchronization Primitives**: Ivar (promises), Mvar (channels), and Terminators
- **Exception Safety**: Proper exception propagation and resource cleanup
- **Lightweight**: Minimal overhead with efficient cooperative multitasking

### Documentation
- Comprehensive README with examples and API overview
- Complete interface documentation for all modules
- Quick start guide with structured concurrency and cooperative multitasking examples
- Comparison with other OCaml concurrency libraries
- Design philosophy and principles explanation

### Examples
- Basic structured concurrency patterns
- Advanced cancellation scenarios
- Promise/future patterns with Ivar
- Producer-consumer examples with Mvar
- Scheduler interoperability demonstrations

## [0.1.0] - 2025-09-07

### Added
- Initial project structure
- Core effect handlers implementation
- Basic synchronization primitives
- First working schedulers
