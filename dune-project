(lang dune 3.17)

(name femtos)

(generate_opam_files true)

(source
 (github kayceesrk/femtos))

(authors "KC Sivaramakrishnan <kc@kcsrk.info>")

(maintainers "KC Sivaramakrishnan <kc@kcsrk.info>")

(license MIT)

(documentation https://kayceesrk.github.io/femtos)

(package
 (name femtos)
 (synopsis "Experimental structured concurrency library for OCaml research")
 (description "Femtos is an experimental library for exploring structured concurrency semantics in OCaml 5.x. It provides triggers, synchronization variables (Ivar, Mvar), terminators, and schedulers (FIFO, Flock) built on effect handlers. For production use, consider Picos, JaneStreet Await, or Eio instead.")
 (depends (ocaml (>= "5.3")) dune saturn (odoc :with-doc))
 (tags
  ("concurrency" "structured-concurrency" "effects" "synchronization" "schedulers" "multicore")))

; See the complete stanza docs at https://dune.readthedocs.io/en/stable/reference/dune-project/index.html
