# Risks and open questions

1. **Resolved in Milestone 1 - hart ID:** `0x10000000` returns the request source core ID without modifying Sparrow-V. See [interface audit](interface_audit.md).
2. **Resolved in Milestone 1 - source integration:** the reviewed scalar closure is locally copied at revision `995ea0f9cada63688c9e21e739bd41d6b1c118af`; normal simulation has no absolute sibling path. See [reuse plan](reuse_plan.md).
3. **Resolved for this interface - memory error:** the audited core has no error channel, so invalid accesses return zero. A future core contract change would require a new audit rather than silently changing this behavior.
4. **Resolved in Milestone 5 - shared writable cacheable data:** production L1Ds use snoopy MSI for ordinary cacheable SRAM. Explicit control/status apertures remain uncached.
5. **Resolved in Milestone 7 - runtime flow:** the local environment lacked a complete RISC-V ELF toolchain, so Milestone 7 uses a deterministic RV32I/LRSC assembler/image generator and records the intended C/linker ABI under `sw/runtime` and `sw/linker`.
6. **Resolved in Milestone 6 - atomics:** minimal LR.W/SC.W is implemented with one 16-byte-block reservation per L1D. Full RV32A AMOs and assembled runtime libraries remain outside scope.
7. **Resolved in Milestone 7 - synchronization workloads:** generated runtime images now exercise LR/SC-backed spinlock, counter, barrier, producer-consumer, reduction, ownership-transfer, false-sharing, padded, read-mostly, and mixed workloads through real cores.
8. **Deliberate limitation - coherent instruction/data interaction:** L1I remains non-coherent; self-modifying code and coherent DMA are outside scope.
9. **Resolved in Milestone 8 - SparrowML package provenance:** the frozen Phase 8 WISDM package is imported under `third_party/sparrowml/` with source revision, source paths, file sizes, and checksums. Normal regression does not depend on `../sparrow-ml`.
10. **Deliberate limitation - SparrowML sparse path:** the imported package and Sparrow-Cluster generated images execute the dense package-reference path only. Sparse-aware SparrowML evidence remains documented as source-package context unless a real Sparrow-V/Sparrow-Cluster sparse execution path is added in a later milestone.
