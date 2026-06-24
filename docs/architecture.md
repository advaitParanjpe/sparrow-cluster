# Architecture

Milestone 3 is a strongly ordered four-core system with private blocking L1I and L1D caches per imported `rv32_core`. L1D accepts one audited DMEM request, performs write-back/write-allocate cacheable accesses, and bypasses documented control apertures. Its lower port is the DMEM port of the existing `core_adapter`; the adapter serializes either L1I refill or L1D traffic and holds metadata until one response returns.

```text
four rv32_core instances -> private L1I/L1D -> per-core adapter -> 4-way RR -> controller -> one SRAM
```

Each refill may release arbitration between words, so L1I refill words from different cores and uncached DMEM work can interleave. `0x10000000` is a read-only core-local hart-ID aperture: a read returns the controller-recorded source ID. SRAM and the controller are otherwise shared.

Read and write latencies are independently parameterized and default to two controller cycles. Invalid or unmapped accesses return zero because the audited Sparrow-V memory interface has no error signal; this preserves its available response-only contract and is tested at controller level.
