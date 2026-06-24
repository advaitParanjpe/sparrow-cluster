# Boot and runtime

All four cores start together at zero. Each reads `0x10000000`, calculates a distinct stack, and stores/loads a local stack word. Hart 0 is the sole writer of shared data and the release flag at `0x308`; all other harts only poll it. After release, every hart reads shared data, writes its own result and statically assigned 16-byte partition, then writes only its own completion word.

This is temporary pre-atomic runtime support: it contains no lock, counter, LR.W, or SC.W. The checked-in hand-encoded RV32I image exercises this flow without requiring an external toolchain.
