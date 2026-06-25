# Architecture

Milestone 7 keeps the four-core coherent production path and adds reusable bare-metal runtime/workload validation:

```text
four rv32_core instances
  -> private L1I / coherent private L1D
  -> L1I and uncached L1D through per-core adapters
  -> cacheable L1D through snoopy MSI transport
  -> one shared SRAM controller
```

Each core has a private 2 KiB, 2-way, 16-byte-block L1I and L1D. L1I remains private and non-coherent. Cacheable L1D requests use blocking MSI coherence over the Milestone 4 `snoopy_coherence_transport`; uncached apertures bypass MSI and still use the existing adapter path. The transport serializes one block transaction at a time and arbitrates among the four L1D requesters round-robin. A small memory-side mux gives coherence SRAM block transfers priority over adapter traffic while preserving the single shared SRAM controller.

The core-to-L1D request carries explicit atomic intent: normal, `LR.W`, or `SC.W`. The private L1D owns one reservation `{valid, 16-byte block address}`. `LR.W` performs a coherent word load and records the block after the load completes. `SC.W` succeeds only for a valid matching resident cacheable block and commits the store while the local line is `M`; it returns zero on success and nonzero on failure.

The SRAM controller remains byte-addressed and fixed-latency. `0x10000000` is a read-only core-local hart-ID aperture. Invalid or unmapped accesses return zero because the audited Sparrow-V memory interface has no error signal. LR/SC is unsupported for uncached/MMIO apertures.

Milestone 7 software images boot all four harts from reset, select per-hart stacks, use uncached control/status apertures for deterministic testbench observation, and place workload data at `0x1000` so normal shared state traverses the coherent L1D/MSI path. The milestone adds no new cache, bus, core, or memory microarchitecture.
