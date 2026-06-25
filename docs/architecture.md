# Architecture

Milestone 5 implements the four-core coherent production path:

```text
four rv32_core instances
  -> private L1I / coherent private L1D
  -> L1I and uncached L1D through per-core adapters
  -> cacheable L1D through snoopy MSI transport
  -> one shared SRAM controller
```

Each core has a private 2 KiB, 2-way, 16-byte-block L1I and L1D. L1I remains private and non-coherent. Cacheable L1D requests use blocking MSI coherence over the Milestone 4 `snoopy_coherence_transport`; uncached apertures bypass MSI and still use the existing adapter path. The transport serializes one block transaction at a time and arbitrates among the four L1D requesters round-robin. A small memory-side mux gives coherence SRAM block transfers priority over adapter traffic while preserving the single shared SRAM controller.

The SRAM controller remains byte-addressed and fixed-latency. `0x10000000` is a read-only core-local hart-ID aperture. Invalid or unmapped accesses return zero because the audited Sparrow-V memory interface has no error signal.
