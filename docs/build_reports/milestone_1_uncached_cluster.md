# Milestone 1 — Four-Core Uncached Shared-Memory Scaffold

Sparrow-V scalar RTL was imported as an unmodified six-file closure from revision `995ea0f9cada63688c9e21e739bd41d6b1c118af`; `scripts/import_sparrow_v.sh` records the reproducible refresh procedure. Four real cores connect to stable one-request adapters, a deterministic four-way round-robin arbiter, and one controller/SRAM. Hart IDs are source-recorded reads at `0x10000000`.

The default SRAM size is 256 KiB. Read and write latency defaults are two cycles and are parameters. The controller accepts one request, retains core and IMEM/DMEM source until completion, applies little-endian byte enables, and returns zero for an unmapped request because Sparrow-V has no memory-error input. The final low-address runtime map, production stack region, and directed-test stack addresses are in [memory map](../memory_map.md).

The local policy alternates IMEM/DMEM after accepted work, starting with IMEM. The global arbiter rotates after accepted controller grants and retains controller ownership through response. `make sim-unit` passes arbiter, adapter, controller latency, byte-enable, and invalid-address tests. `make sim-cluster` passes four-core fetch/ID/store integration. `make sim-multicore` passes four hart IDs, four stack words, release synchronization, checksums, partition word/byte writes, and completions. `make regress` is the combined gate.

Known limitations are deliberate: no L1 caches, tags, MSI, snooping, cache transfer, LR/SC, atomic lock/counter, L2, burst, multiple outstanding request, SparrowML workload, FPGA, or physical-design flow. Icarus emits known informational constant-select warnings when compiling the imported core.
