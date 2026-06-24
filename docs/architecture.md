# Architecture

Milestone 2 is a strongly ordered four-core system with one private blocking L1I per imported `rv32_core`. Each L1I accepts one audited IMEM request, returns hits locally, and holds a miss until four ordinary word reads complete. Its lower port is the IMEM port of the existing `core_adapter`; DMEM remains connected to the adapter unchanged. The adapter captures either one L1I refill word request or one DMEM request, then holds its metadata until exactly one response returns. Local round-robin starts with IMEM after reset and alternates after accepted work. A four-way global round-robin arbiter accepts one adapter request only when the controller is idle.

```text
four rv32_core instances -> private L1I -> per-core IMEM/DMEM adapter -> 4-way RR -> controller -> one SRAM
```

Each refill may release arbitration between words, so L1I refill words from different cores and uncached DMEM work can interleave. `0x10000000` is a read-only core-local hart-ID aperture: a read returns the controller-recorded source ID. SRAM and the controller are otherwise shared.

Read and write latencies are independently parameterized and default to two controller cycles. Invalid or unmapped accesses return zero because the audited Sparrow-V memory interface has no error signal; this preserves its available response-only contract and is tested at controller level.
