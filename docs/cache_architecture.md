# Cache architecture

Each L1 is 2 KiB, 2-way, 64 sets, and 16-byte blocks: `64*2*16=2048`. With observed 32-bit addresses, offset is `[3:0]`, set is `[9:4]`, tag is `[31:10]` (22 bits); formulas are `offset=log2(16)=4`, `set=log2(64)=6`, `tag=ADDR_W-10`. One replacement bit per set selects the victim; update it to the opposite way after any fill and any hit (documented pseudo-LRU/round-robin behavior).

Both caches are blocking: one core request or coherence action at a time, no MSHR. A miss selects a way; a dirty L1D victim writes back before refill; refill installs a complete block then responds. L1I is read-only in normal execution, private, and non-coherent. L1D is write-back/write-allocate: store miss obtains exclusive ownership then merges core byte strobes; store hit in S upgrades before merge.

Processor side is the audited 32-bit valid/ready IMEM or DMEM contract. Memory/bus side operates block address plus 128-bit block data, byte-write mask for writeback, command/response valid/ready, requester ID (2 bits), and error. Exact cache module ports await adapter implementation.
