/* Hand-encoded RV32I Milestone 1 image in m1_multicore.hex.
 * All harts start at reset; hart 0 publishes one release flag.  Each hart
 * records its ID through its private stack, checks shared read-only data,
 * writes a statically partitioned region, and sets its own completion word.
 * The repository intentionally has no required external RISC-V toolchain.
 */
