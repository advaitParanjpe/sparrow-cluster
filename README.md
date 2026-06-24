# Sparrow-Cluster

Milestone 1 implements four unmodified, locally imported Sparrow-V scalar cores behind stable IMEM/DMEM adapters, a single round-robin request path, and one 256 KiB shared SRAM. There are no caches, coherence transactions, LR/SC, or L2.

The normal simulation is self-contained. `scripts/import_sparrow_v.sh ../sparrow-v` is only the explicit provenance refresh operation; it copies the reviewed scalar closure and is not required to run tests.

Run `make check`, `make docs-check`, `make sim-unit`, `make sim-cluster`, `make sim-multicore`, or `make regress`. The hand-encoded RV32I image in `sw/tests/m1_multicore.hex` deliberately avoids requiring a host RISC-V toolchain.

Read [architecture](docs/architecture.md), [memory map](docs/memory_map.md), [runtime](docs/boot_and_runtime.md), and the [Milestone 1 report](docs/build_reports/milestone_1_uncached_cluster.md).
