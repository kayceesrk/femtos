open Femtos

let test_condition_multicore_producer_consumer () =
  Printf.printf "\n=== Testing Condition Variables Multicore Producer/Consumer ===\n%!" ;

  let mutex = Sync.Mutex.create () in
  let condition = Sync.Condition.create () in
  let buffer = ref [] in
  let max_size = 2 in
  let items_to_produce = 5 in
  let produced_count = Atomic.make 0 in
  let consumed_count = Atomic.make 0 in

  (* Producer domain *)
  let producer_domain = Domain.spawn (fun () ->
    let main _terminator =
      for i = 1 to items_to_produce do
        Sync.Mutex.lock mutex ;

        (* Wait while buffer is full *)
        while List.length !buffer >= max_size do
          Printf.printf "Producer: Buffer full, waiting...\n%!" ;
          Sync.Condition.wait condition mutex
        done ;

        (* Produce item *)
        let item = Printf.sprintf "item_%d" i in
        buffer := item :: !buffer ;
        Atomic.incr produced_count ;
        Printf.printf "Producer: Produced %s (buffer size: %d)\n%!" item (List.length !buffer) ;

        (* Signal consumers *)
        Sync.Condition.broadcast condition ;
        Sync.Mutex.unlock mutex ;

        (* Yield occasionally *)
        if i mod 2 = 0 then Mux.Fifo.yield ()
      done ;
      Printf.printf "Producer: Finished producing %d items\n%!" items_to_produce
    in

    Mux.Fifo.run main ;
    "producer_done"
  ) in

  (* Consumer domain *)
  let consumer_domain = Domain.spawn (fun () ->
    let main _terminator =
      for i = 1 to items_to_produce do
        Sync.Mutex.lock mutex ;

        (* Wait while buffer is empty *)
        while List.length !buffer = 0 do
          Printf.printf "Consumer: Buffer empty, waiting...\n%!" ;
          Sync.Condition.wait condition mutex
        done ;

        (* Consume item *)
        let item = List.hd !buffer in
        buffer := List.tl !buffer ;
        Atomic.incr consumed_count ;
        Printf.printf "Consumer: Consumed %s (buffer size: %d)\n%!" item (List.length !buffer) ;

        (* Signal producer *)
        Sync.Condition.broadcast condition ;
        Sync.Mutex.unlock mutex ;

        (* Yield occasionally *)
        if i mod 2 = 0 then Mux.Fifo.yield ()
      done ;
      Printf.printf "Consumer: Finished consuming %d items\n%!" items_to_produce
    in

    Mux.Fifo.run main ;
    "consumer_done"
  ) in

  Printf.printf "Waiting for producer and consumer to complete...\n%!" ;
  let producer_result = Domain.join producer_domain in
  let consumer_result = Domain.join consumer_domain in

  let final_produced = Atomic.get produced_count in
  let final_consumed = Atomic.get consumed_count in
  let final_buffer_size = List.length !buffer in

  Printf.printf "Results: %s, %s\n%!" producer_result consumer_result ;
  Printf.printf "Produced: %d, Consumed: %d, Buffer size: %d\n%!"
    final_produced final_consumed final_buffer_size ;

  if final_produced = items_to_produce && final_consumed = items_to_produce then
    Printf.printf "✓ Condition variables multicore producer/consumer test passed!\n%!"
  else
    Printf.printf "✗ Condition variables multicore producer/consumer test FAILED!\n%!"

let () =
  test_condition_multicore_producer_consumer ()
