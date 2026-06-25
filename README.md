# Sparrow-Cluster

Milestone 4 adds a separately verified four-requester snoopy coherence transport for the future MSI L1D connection. It serializes block transactions, broadcasts commands, collects peer responses, performs modified-owner intervention with a coupled SRAM update, and leaves production L1D non-coherent.

The normal simulation is self-contained. `scripts/import_sparrow_v.sh ../sparrow-v` is only the explicit provenance refresh operation; it copies the reviewed scalar closure and is not required to run tests.

Run `make check`, `make docs-check`, `make sim-unit`, `make sim-l1i`, `make sim-l1d`, `make sim-snoop-transport`, `make sim-cluster`, `make sim-multicore`, or `make regress`. The hand-encoded RV32I image in `sw/tests/m1_multicore.hex` deliberately avoids requiring a host RISC-V toolchain.

Read [architecture](docs/architecture.md), [cache architecture](docs/cache_architecture.md), [memory map](docs/memory_map.md), and the [Milestone 2 report](docs/build_reports/milestone_2_private_l1i.md).
