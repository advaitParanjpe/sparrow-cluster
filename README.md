# Sparrow-Cluster

Milestone 3 implements four unmodified, locally imported Sparrow-V scalar cores, each with private blocking 2 KiB, 2-way, 16-byte-block L1I and write-back/write-allocate L1D caches. L1D uses four ordinary reads for refill and four writes for dirty eviction through the existing adapter and shared SRAM. It is explicitly non-coherent: control, release, result, and completion words use the documented uncached apertures.

The normal simulation is self-contained. `scripts/import_sparrow_v.sh ../sparrow-v` is only the explicit provenance refresh operation; it copies the reviewed scalar closure and is not required to run tests.

Run `make check`, `make docs-check`, `make sim-unit`, `make sim-l1i`, `make sim-l1d`, `make sim-cluster`, `make sim-multicore`, or `make regress`. The hand-encoded RV32I image in `sw/tests/m1_multicore.hex` deliberately avoids requiring a host RISC-V toolchain.

Read [architecture](docs/architecture.md), [cache architecture](docs/cache_architecture.md), [memory map](docs/memory_map.md), and the [Milestone 2 report](docs/build_reports/milestone_2_private_l1i.md).
