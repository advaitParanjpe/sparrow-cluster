# LR.W / SC.W

Milestone 6 adds standard RV32 `LR.W` and `SC.W` encodings while retaining the core adapter contract outside the private core-to-L1D metadata. The decoded DMEM request carries explicit atomic intent: normal, LR, or SC. The `aq` and `rl` bits are accepted with no additional behavior because the baseline is already strongly ordered.

The private L1D stores one reservation per core: valid plus a 16-byte-aligned block address. LR performs a coherent aligned word load and records the containing block only after the load completes. SC succeeds only for a valid matching resident cacheable block, obtains or keeps `M`, performs one word store, returns zero, and clears the reservation. SC failure returns one, performs no store, issues no ownership request for invalid/mismatched/nonresident/unsupported cases, and clears the reservation.

Reservations are conservative 16-byte cache-block reservations. Any write or ownership acquisition for another word in the same block may invalidate the reservation. The reservation also clears on reset, new LR replacement, every SC attempt, local eviction or replacement of the reserved line, remote `BUS_RDX`, remote `BUS_UPGR`, and remote `BUS_RD` that downgrades a reserved modified line.

Misaligned LR/SC follows the imported Sparrow-V misalignment trap path and does not reach L1D execution. Uncached/MMIO LR returns zero and does not reserve; uncached/MMIO SC returns one and stores nothing. Other AMOs, `.D` variants, word-granularity reservations, and full RV32A are deliberately absent.

Milestone 7 exposes LR/SC through the generated runtime and through the reference wrappers in `sw/runtime/atomic.S`. The software build checker rejects AMOs other than `lr.w` and `sc.w`, compressed instructions, multiply/divide, floating point, and privileged instructions in generated listings.

Milestone 8 does not change LR/SC. Existing LR/SC regressions remain the authority for atomics, while SparrowML shared-work synchronization uses per-core cacheable completion slots and core-0 reduction to avoid adding locks inside the package-reference compute path.
