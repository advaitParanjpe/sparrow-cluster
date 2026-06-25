# Milestone 6 - Minimal LR.W / SC.W Atomic Synchronization

Milestone 6 implements standard RV32 `LR.W` and `SC.W` encodings only. The imported core decoder accepts LR/SC with ignored `aq`/`rl` bits, rejects LR with nonzero `rs2`, and continues to reject other AMOs. The core carries explicit DMEM atomic intent to the private L1D and writes back LR load data or SC status.

Reservation storage lives in `l1_data_cache`: one valid bit and one 16-byte-aligned block address per core. LR sets the reservation only after coherent load completion. SC succeeds only when the reservation is valid, matching, cacheable, resident, and committed while the local line is `M`; it returns zero and performs one word store. SC failure returns one, stores nothing, clears the reservation, and does not request ownership for invalid, mismatched, unsupported, or nonresident cases.

Reservations clear on reset, new LR replacement, every SC attempt, local eviction or replacement of the reserved block, remote `BUS_RDX`, remote `BUS_UPGR`, and conservative `BUS_RD` downgrade of a reserved modified block. Reservation granularity is the full 16-byte cache block, so same-block different-word writes can make a later SC fail.

Uncached/MMIO atomics are unsupported. LR to uncached apertures returns zero without reserving; SC returns one and performs no store. Misaligned LR/SC follows the existing Sparrow-V misalignment trap path before L1D execution.

Counters added per L1D: LR attempts/completions, SC attempts/successes/failures, no-reservation failures, mismatch failures, snoop-cleared failures, eviction-cleared failures, and reservation clears. Assertions check aligned reservations and SC counter reconciliation.

Directed verification:

- `tb_lrsc_decode`: LR.W, SC.W, LR rs2-zero rule, aq/rl acceptance, other AMO exclusion.
- `tb_lrsc_coherence`: success, SC without LR, mismatch, SC clears, remote invalidation, same-block conflict, S-to-M upgrade success, eviction clearing, uncached policy, and counters.
- `tb_atomic_random`: seed `0x5eed600d`, 72 randomized atomic/coherent operations plus seeded successful SC operations against a reference reservation/memory model.

Measured local results: `make sim-lrsc` and `make sim-atomic-random` pass. The full milestone command set is recorded in `reports/current_milestone_report.md`.

Deliberately absent functionality: other AMOs, full RV32A, `.D` atomics, multiple reservations, word-granularity reservations, MESI, non-blocking caches, L2, coherent L1I, coherent DMA, an operating system, and FPGA/ASIC work.
