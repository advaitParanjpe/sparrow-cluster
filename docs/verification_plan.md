# Verification plan

`make sim-unit` preserves Milestone 1 adapter/controller checks. `make sim-l1i` preserves L1I refill and replacement coverage. `make sim-l1d` covers cold four-word refill, all word offsets, delayed responses, byte and full-word merge, write allocate, two-way conflict replacement, one four-word dirty writeback, uncached bypass/no allocation, reset, and counter consistency. Assertions cover valid-way hits, one matching way, aligned refill/writeback, legal victim, and accounting.

`make sim-cluster` runs four-core L1I/L1D contention with uncached result stores. `make sim-multicore` validates uncached synchronization/completion, cached private stacks and block-disjoint partitions, and L1I accounting. Dirty final-SRAM behavior is validated by forced eviction in `tb_l1d`; cached writable sharing is deliberately not treated as coherent. `make regress` runs all checks and simulations. Icarus constant-select warnings are informational.
