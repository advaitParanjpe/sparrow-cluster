# LR.W / SC.W

Milestone 6 adds decoder/execute hooks for LR/SC while retaining the core adapter contract. LR.W performs a coherent read and records `{valid, block_address}` per core after completion. SC.W succeeds only when that reservation remains valid, then performs an exclusive coherent write and returns zero; it otherwise performs no write and returns nonzero. Reservations are 16-byte-block granular and clear on local conflicting store/SC, local eviction, snooped BusRdX/BusUpgr ownership acquisition, reset, and implementation-defined trap/flush (to be made explicit in code).

The audited Sparrow-V decoder has no RV32A extension hook or LR/SC decode. Extension must therefore be a deliberate decoder/core integration decision, not an adapter-only feature. Required tests: success, failure after remote write/upgrade, false sharing within block, eviction, reset, and contention spinlock. Successful SC requires a valid matching reservation.
