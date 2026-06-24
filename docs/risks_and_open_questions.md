# Risks and open questions

1. **Resolved in Milestone 1 — hart ID:** `0x10000000` returns the request source core ID without modifying Sparrow-V. See [interface audit](interface_audit.md).
2. **Resolved in Milestone 1 — source integration:** the reviewed scalar closure is locally copied at revision `995ea0f9cada63688c9e21e739bd41d6b1c118af`; normal simulation has no absolute sibling path. See [reuse plan](reuse_plan.md).
3. **Resolved for this interface — memory error:** the audited core has no error channel, so invalid accesses return zero. A future core contract change would require a new audit rather than silently changing this behavior.
4. **Resolved in Milestone 2 — L1I insertion:** private L1I refills use four ordinary word transactions through the existing adapters and can interleave with other cores and DMEM. L1I is intentionally non-coherent; L1D and snooping remain later work.
5. **Open for later runtime work — toolchain/startup ABI:** the current test image is hand-encoded RV32I. A production linker/startup ABI requires an approved toolchain decision.
