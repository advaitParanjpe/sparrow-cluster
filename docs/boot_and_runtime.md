# Boot and runtime

All four cores start together at zero. Each reads uncached `0x10000000`, calculates a distinct cacheable stack, and stores/loads a local stack word. Hart 0 writes initialized data and the uncached release flag at `0x308`; all other harts poll it uncached. Results and completion words use uncached apertures.

With Milestone 6, ordinary cacheable shared writable data is coherent and the hardware supports minimal LR.W/SC.W. The existing checked-in RV32I image still uses deterministic uncached control flags because this repository keeps the software image hand-encoded and toolchain-free. RTL tests directly exercise LR/SC lock-style, counter-style, barrier-style, and contention sequences through the core/L1D interface; a future toolchain milestone can replace those directed sequences with assembled runtime wrappers.
