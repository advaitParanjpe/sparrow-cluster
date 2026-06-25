# Sparrow-Cluster

Milestone 6 adds minimal RV32 `LR.W`/`SC.W` synchronization to the four production coherent L1D caches. The system remains four Sparrow-V cores with private L1I, private coherent write-back/write-allocate L1D, one serialized snoopy transport, and one shared SRAM. Atomics are limited to one 16-byte-block reservation per core and do not include other RV32A AMOs.

The normal simulation is self-contained. `scripts/import_sparrow_v.sh ../sparrow-v` is only the explicit provenance refresh operation; it copies the reviewed scalar closure and is not required to run tests.

Run `make check`, `make docs-check`, `make sim-unit`, `make sim-l1i`, `make sim-l1d`, `make sim-snoop-transport`, `make sim-msi`, `make sim-coherence-random`, `make sim-lrsc`, `make sim-atomic-random`, `make sim-cluster`, `make sim-multicore`, or `make regress`. The hand-encoded RV32I image in `sw/tests/m1_multicore.hex` deliberately avoids requiring a host RISC-V toolchain.

Read [architecture](docs/architecture.md), [cache architecture](docs/cache_architecture.md), [coherence protocol](docs/coherence_protocol.md), [bus protocol](docs/bus_protocol.md), [LR/SC](docs/lr_sc.md), and the [Milestone 6 report](docs/build_reports/milestone_6_lr_sc.md).
