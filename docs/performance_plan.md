# Performance plan

Milestone 3 exposes per-core L1D accepted accesses, loads, stores, hits, misses, load/store misses, refill words, dirty writeback words, dirty evictions, uncached accesses, and miss-stall cycles. The enforced equation is `accesses = hits + misses + uncached_accesses`. The directed test measures 12 refill words, four dirty writeback words, one dirty eviction, and two uncached accesses; coherence traffic remains later work.
