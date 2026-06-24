# Milestone 2 — Private L1 Instruction Caches

Each of four real Sparrow-V cores now has a private `l1_instruction_cache`. The implemented geometry is 2 KiB, 2 ways, 64 sets, and 16-byte blocks. The audited address width is 32 bits: byte offset `[1:0]`, word offset `[3:2]`, set `[9:4]`, and 22-bit tag `[31:10]`.

L1I is blocking, read-only, non-coherent, and has one active refill. Reset clears valid and replacement bits. Invalid ways are selected before valid ways (way 0 then way 1); otherwise the per-set bit selects the victim. Hits and fills set that bit to the other way, making this deterministic one-bit pseudo-LRU/round-robin behavior.

A miss issues four aligned 32-bit reads through the existing adapter IMEM path. Each word waits for its response before issuing the next, so global arbitration may interleave other L1I refill words and uncached DMEM. Tag and valid update only after the fourth word, then the requested word is returned. No burst, bus-width, or controller protocol change was made.

Counters per L1I are accepted accesses, hits, misses, refill words, and miss-stall cycles. The counting convention is `accesses = hits + misses`; directed checks also require four refill words per miss. `tb_l1i` covers cold refill, offsets, hits, conflicts, replacement, delayed responses, reset, and counters. `tb_cluster` drives simultaneous four-core cold misses, uncached stores, and a three-block same-set bare-metal instruction loop. `tb_m1_multicore` preserves the Milestone 1 software results through L1I.

Known deliberate limitations: no L1D, write-back, coherence, snooping, instruction invalidation, self-modifying-code support, LR/SC, L2, burst, MSHR, hit-under-miss, or hardware prefetching. Icarus emits informational constant-select and `unique`-case warnings.
