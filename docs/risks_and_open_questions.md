# Risks and open questions

1. **Resolved in Milestone 1 - hart ID:** `0x10000000` returns the request source core ID without modifying Sparrow-V. See [interface audit](interface_audit.md).
2. **Resolved in Milestone 1 - source integration:** the reviewed scalar closure is locally copied at revision `995ea0f9cada63688c9e21e739bd41d6b1c118af`; normal simulation has no absolute sibling path. See [reuse plan](reuse_plan.md).
3. **Resolved for this interface - memory error:** the audited core has no error channel, so invalid accesses return zero. A future core contract change would require a new audit rather than silently changing this behavior.
4. **Resolved in Milestone 5 - shared writable cacheable data:** production L1Ds use snoopy MSI for ordinary cacheable SRAM. Explicit control/status apertures remain uncached.
5. **Open for later runtime work - toolchain/startup ABI:** the current test image is hand-encoded RV32I. A production linker/startup ABI requires an approved toolchain decision.
6. **Resolved in Milestone 6 - atomics:** minimal LR.W/SC.W is implemented with one 16-byte-block reservation per L1D. Full RV32A AMOs and assembled runtime libraries remain outside scope.
7. **Open for later runtime work - assembled synchronization library:** hardware LR/SC is verified through RTL sequences; replacing hand-encoded RV32I images with assembled spinlock/barrier/counter workloads needs the approved toolchain/startup ABI.
8. **Deliberate limitation - coherent instruction/data interaction:** L1I remains non-coherent; self-modifying code and coherent DMA are outside scope.
