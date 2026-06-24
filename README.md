# Sparrow-Cluster

Milestone 2 implements four unmodified, locally imported Sparrow-V scalar cores, each with a private blocking 2 KiB, 2-way, 16-byte-block L1 instruction cache. L1I refills use four ordinary reads through the existing per-core adapter, shared round-robin path, and 256 KiB SRAM. DMEM remains uncached. There is no L1D, coherence, LR/SC, or L2.

The normal simulation is self-contained. `scripts/import_sparrow_v.sh ../sparrow-v` is only the explicit provenance refresh operation; it copies the reviewed scalar closure and is not required to run tests.

Run `make check`, `make docs-check`, `make sim-unit`, `make sim-l1i`, `make sim-cluster`, `make sim-multicore`, or `make regress`. The hand-encoded RV32I image in `sw/tests/m1_multicore.hex` deliberately avoids requiring a host RISC-V toolchain.

Read [architecture](docs/architecture.md), [cache architecture](docs/cache_architecture.md), [memory map](docs/memory_map.md), and the [Milestone 2 report](docs/build_reports/milestone_2_private_l1i.md).
