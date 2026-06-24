# Boot and runtime

All four cores start together at zero. Each reads uncached `0x10000000`, calculates a distinct cacheable stack, and stores/loads a local stack word. Hart 0 writes initialized data and the uncached release flag at `0x308`; all other harts poll it uncached. Results and completion words use uncached apertures. Each statically assigned cacheable partition is 16-byte aligned and is written only by its owner.

This is temporary pre-atomic runtime support: it contains no lock, counter, LR.W, or SC.W. The checked-in hand-encoded RV32I image exercises this flow without requiring an external toolchain.
