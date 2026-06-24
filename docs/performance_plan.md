# Performance plan

Milestone 2 exposes per-core L1I access, hit, miss, refill-word, and miss-stall-cycle counters as internal RTL signals. Accesses are accepted fetches, therefore accesses equal hits plus misses. The directed L1I test measures one cold miss/four refill words followed by three hits across a block, then conflict replacements. Later counters remain L1D dirty evictions, coherence traffic, bus occupancy, arbitration wait, and LR/SC attempts/failures.
