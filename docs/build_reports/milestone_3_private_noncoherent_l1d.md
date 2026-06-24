# Milestone 3 — Private Non-Coherent L1 Data Caches

Each core has a private 2 KiB, 2-way, 64-set, 16-byte-block L1D. Addresses are 32-bit: byte `[1:0]`, word `[3:2]`, set `[9:4]`, and tag `[31:10]`. A cleared-valid reset and invalid-way-first selection are used; a hit or fill makes the other way the next victim.

The audited Sparrow-V DMEM port is decoupled and carries an aligned word address, write flag, data, and little-endian strobes. L1D captures one request and produces one response. Sparrow-V performs load sign/zero extension, so L1D returns raw words. Cacheable misses issue four sequential reads; store misses merge after refill. Dirty victims issue four aligned full-word writes before replacement. Store hits merge only enabled bytes and become dirty.

`0x200..0x20f`, `0x300..0x30f`, `0x400..0x40f`, `0x600..0x60f`, and `0x10000000` bypass L1D. These hold cluster results, release/control, completion, and hart-ID traffic. Other SRAM is cacheable only for private stacks, read-only initialized data, or block-disjoint partitions. Two cores caching the same writable block can observe stale data: this expected non-coherent limitation is not used by regressions.

Counters are internal: accepted accesses, loads/stores, hits/misses, load/store misses, refill words, dirty writeback words, dirty evictions, uncached accesses, and miss-stall cycles. The checked equation is `accesses = hits + misses + uncached_accesses`. `tb_l1d` observes 12 refill words, four dirty writeback words, one dirty eviction, and two uncached accesses while checking byte/full-word merging, delayed lower responses, reset, and no-allocation bypass. Four-core tests retain L1I operation and use uncached synchronization.

Deliberately absent: MSI/MESI, snooping, invalidation, cache-to-cache transfer, LR/SC, flush, MSHRs, hit-under-miss, store buffers, bursts, L2, and coherent instruction caches.
