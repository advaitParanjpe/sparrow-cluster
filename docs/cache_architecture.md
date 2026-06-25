# Cache architecture

L1I and L1D are 2 KiB, 2-way, 64-set, 16-byte-block caches: `64*2*16=2048`. The 32-bit address breakdown is byte `[1:0]`, word `[3:2]`, set `[9:4]`, and tag `[31:10]`.

L1D is blocking, write-back, write-allocate, and coherent for cacheable SRAM. Its resident-line metadata is authoritative MSI state:

| State | Meaning |
| --- | --- |
| `I` | invalid, cannot hit |
| `S` | valid clean shared |
| `M` | valid dirty owner |

There are no independent architectural valid or dirty bits. Victim selection still prefers invalid way 0, then invalid way 1, then the replacement bit. A clean `S` victim is replaced without writeback; an `M` victim issues a full-block coherence `WRITEBACK` before replacement.

Processor-side transient phases are explicit control states: dirty victim writeback request/wait, coherence request/wait for `BUS_RD`, `BUS_RDX`, or `BUS_UPGR`, uncached request/wait, and processor response. A load miss installs `S`; a store miss installs `M`; a store hit in `S` issues `BUS_UPGR` then merges bytes after ownership is granted. A store hit in `M` merges locally. Loads in `S` or `M` return the resident word.

LR/SC reservation tracking is stored in each private L1D as one valid bit plus one 16-byte-aligned block address. `LR.W` follows the load path and sets the reservation only when the coherent load response is produced. `SC.W` is decided in the L1D: invalid, mismatched, uncached, or nonresident reservations fail without a bus ownership request; matching resident requests obtain or keep `M`, merge exactly one word, return zero, and clear the reservation. Every `SC.W` attempt clears the reservation.

Snoops are answered through the transport snooper port. `BUS_RD` to an `M` line supplies the full 16-byte block and downgrades to `S`. `BUS_RDX` to `S` invalidates; `BUS_RDX` to `M` supplies the block and invalidates. `BUS_UPGR` to `S` invalidates; `BUS_UPGR` to `M` increments the protocol-error counter and leaves state uncorrupted. A snoop hit to the reserved block that downgrades or invalidates the local line clears the reservation.

Uncached addresses are unchanged: `0x200..0x20f`, `0x300..0x30f`, `0x400..0x40f`, `0x600..0x60f`, and `0x10000000` bypass L1D allocation and coherence.
LR to these apertures returns zero and does not reserve; SC to these apertures fails with return value one and no store.
