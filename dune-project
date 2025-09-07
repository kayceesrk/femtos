(lang dune 3.17)

(name femtos)

(generate_opam_files true)

(source
 (github kayceesrk/femtos))

(authors "KC Sivaramakrishnan <sk826@cl.cam.ac.uk>")

(maintainers "KC Sivaramakrishnan <sk826@cl.cam.ac.uk>")

(license MIT)

(documentation https://kayceesrk.github.io/femtos)

(package
 (name femtos)
 (synopsis "Lightweight structured concurrency library for OCaml")
 (description "Femtos provides structured concurrency primitives for OCaml 5.x including triggers, synchronization variables (Ivar, Mvar), terminators, and schedulers (FIFO, Flock). Built on OCaml's effect handlers for efficient cooperative multitasking and structured concurrency patterns.")
 (depends ocaml dune (odoc :with-doc))
 (tags
  ("concurrency" "structured-concurrency" "effects" "synchronization" "schedulers" "multicore")))

; See the complete stanza docs at https://dune.readthedocs.io/en/stable/reference/dune-project/index.html
