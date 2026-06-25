# Performance plan

Per-core L1D counters expose accepted accesses, loads, stores, hits, misses, load/store misses, refill words, writeback words, dirty evictions, uncached accesses, miss-stall cycles, load hits in `S`, load hits in `M`, store hits in `M`, store upgrades, `BUS_RD`, `BUS_RDX`, `BUS_UPGR`, writebacks, snoop hits in `S`, snoop hits in `M`, interventions, invalidations, downgrades, ownership transfers, coherence stall cycles, and protocol errors. The enforced equation is `accesses = hits + misses + uncached_accesses`.

Milestone 6 adds per-core LR/SC counters: LR attempts, LR completions, SC attempts, SC successes, SC failures, no-reservation failures, address-mismatch failures, snoop-cleared failures, eviction-cleared failures, and reservation clears. The enforced atomic equation is `SC attempts = SC successes + SC failures` once the cache returns to idle.

The transport also counts accepted transactions by command, shared observations, interventions, SRAM block reads/writes, invalidation acknowledgements, occupied cycles, protocol errors, timeouts, and per-requester arbitration wait cycles. Counts increment on command acceptance, snoop response, invalidation, or completed four-word SRAM block operation as named. Milestone 5 reports correctness counts only; it does not claim performance speedup.
