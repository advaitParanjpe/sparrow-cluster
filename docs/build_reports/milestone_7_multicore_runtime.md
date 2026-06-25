# Milestone 7 - Multicore Runtime and Workloads

Milestone 7 adds a deterministic bare-metal runtime and workload flow. The local toolchain audit found Apple clang only, so the executable flow uses `scripts/build_runtime_sw.py`, a repository-local RV32I/LRSC assembler that emits `$readmemh` images and listings under ignored `build/sw/`.

Software ISA: RV32I plus `lr.w` and `sc.w`; no compressed instructions, multiply/divide, floating point, privileged instructions, or other AMOs. The checker scans generated listings and rejects unsupported mnemonics.

Runtime flow: reset vector jumps to text at `0x800`; each hart reads `0x10000000`, selects a 256-byte stack below `0x10000`, waits for hart-0 initialization through `0x308`, runs only if `hart_id < active_harts`, and reports status through `0x200`, `0x400`, and `0x600`. Shared workload data starts at `0x1000`.

Runtime API references are in `sw/runtime/include/sparrow_runtime.h`, `sw/runtime/atomic.S`, `sw/runtime/runtime.c`, and `sw/runtime/synchronization.c`. `sw/linker/sparrow_cluster.ld` records the intended ELF memory map and stack assertions for a later compiler-backed flow.

Workloads cover runtime smoke, atomic counter, spinlock, reusable barrier, producer-consumer, shared reduction, ownership ping-pong, false-sharing, padded comparison, read-mostly, and mixed private/shared traffic. One-, two-, and four-core variants are generated where required.

Measured results are recorded in `reports/current_milestone_report.md` after the final local gate run. Deliberately absent functionality remains SparrowML, an operating system, interrupts, full libc, full RV32A AMOs, MESI, non-blocking caches, L2, coherent L1I, FPGA deployment, and ASIC evaluation.
