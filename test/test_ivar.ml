open Sync

let test_promise_fill_and_exception () =
  let promise = Ivar.create () in

  (* Fill the promise *)
  Ivar.fill promise 42 ;
  Printf.printf "Filled promise with 42\n" ;

  (* Try to fill again - should raise Already_filled *)
  (try
     Ivar.fill promise 100 ;
     assert false (* Should not reach here *)
   with Ivar.Already_filled ->
     Printf.printf "Ivar Already_filled exception caught correctly\n") ;

  Printf.printf "Ivar fill and exception test passed\n"

let test_promise_different_types () =
  let int_promise = Ivar.create () in
  let string_promise = Ivar.create () in

  (* Fill with different types *)
  Ivar.fill int_promise 123 ;
  Ivar.fill string_promise "hello world" ;

  (* Try to fill again - both should raise Already_filled *)
  (try
     Ivar.fill int_promise 456 ;
     assert false
   with Ivar.Already_filled ->
     Printf.printf "Int promise Already_filled test passed\n") ;

  (try
     Ivar.fill string_promise "goodbye" ;
     assert false
   with Ivar.Already_filled ->
     Printf.printf "String promise Already_filled test passed\n") ;

  Printf.printf "Different types test passed\n"

let () =
  test_promise_fill_and_exception () ;
  test_promise_different_types () ;
  Printf.printf
    "All promise tests passed (without await - requires effect handler)!\n"
