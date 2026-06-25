# Verification plan

`make sim-unit` preserves Milestone 1 adapter/controller checks. `make sim-l1i` preserves L1I refill and replacement coverage. `make sim-l1d` now drives a production L1D through a one-requester transport and checks MSI refill/hit behavior, upgrades, byte/full-word merge, write allocate, dirty writeback, clean uncached bypass, reset invalidation, and counter accounting.

`make sim-snoop-transport` preserves the independent Milestone 4 transport regression. `make sim-msi` instantiates four production L1Ds behind the real transport and covers cold/shared reads, four readers, `S->M` upgrades, `I->M` write misses, `M->S` remote reads, `M->I` ownership transfer, `S->I` invalidations, byte/half/word stores, dirty eviction, clean eviction, independent blocks, and concurrent requests. `make sim-coherence-random` runs deterministic seed `0x5eed1234` with 96 word operations against a reference model.

`make sim-cluster` runs four real cores with L1I, coherent L1D, uncached result stores, and shared SRAM contention. `make sim-multicore` validates uncached synchronization/completion plus cached private stack and partition activity. `make regress` runs all checks and simulations. Icarus constant-select warnings are informational.
