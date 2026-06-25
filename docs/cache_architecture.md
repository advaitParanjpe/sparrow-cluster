# Cache architecture

Milestone 3 keeps the L1I and adds one L1D per core. Each is 2 KiB, 2-way, 64 sets, and 16-byte blocks: `64*2*16=2048`. The audited 32-bit address breakdown is byte `[1:0]`, word `[3:2]`, set `[9:4]`, tag `[31:10]` (22 bits). Invalid ways are selected first (way 0 then way 1); a hit or fill sets the bit to the other way.

L1D is blocking, private, non-coherent, write-back, and write-allocate. It has one active request, performs four aligned word reads for a refill, and writes all four words of a dirty victim before refill. Stores merge little-endian byte strobes and set dirty; a cacheable store miss refills then merges. Tag/valid install only after word four. `0x200..0x20f`, `0x300..0x30f`, `0x400..0x40f`, `0x600..0x60f`, and `0x10000000` are uncached; all other SRAM addresses are cacheable. No MSI, snooping, flush, LR/SC, MSHR, or hit-under-miss exists.

Milestone 4 does not change this L1D behavior. Its standalone transport uses the same 16-byte block and four 32-bit word granularity, ready for later MSI connection.

The processor side is the audited 32-bit IMEM valid/ready contract. The L1I lower side is the existing 32-bit adapter IMEM contract, not a new bus: each read carries one aligned word address and receives one word response. Per-core internal counters expose accesses, hits, misses, refill words, and miss-stall cycles; accesses are counted on accepted fetches, so `accesses = hits + misses`.
