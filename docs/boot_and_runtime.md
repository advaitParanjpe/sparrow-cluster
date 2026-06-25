# Boot and runtime

All four cores start together at zero. Each reads uncached `0x10000000`, calculates a distinct cacheable stack, and stores/loads a local stack word. Hart 0 writes initialized data and the uncached release flag at `0x308`; all other harts poll it uncached. Results and completion words use uncached apertures.

With Milestone 5, ordinary cacheable shared writable data is coherent. The existing checked-in RV32I image still uses deterministic uncached control flags because LR/SC and locks are not implemented, but cacheable data words may change ownership through MSI. The runtime contains no LR.W, SC.W, reservation tracking, or atomic lock primitive.
