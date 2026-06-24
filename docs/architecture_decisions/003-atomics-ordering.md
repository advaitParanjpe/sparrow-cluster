# ADR 003: atomics and ordering

**Accepted.** Implement minimal LR.W/SC.W with one 16-byte-block reservation per core and strongly ordered memory operations. Full RV32A and speculative/weak ordering are excluded.
