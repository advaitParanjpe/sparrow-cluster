# Architecture

Milestone 4 retains the strongly ordered Milestone 3 production path and adds a dormant four-port snoopy transport for verification. The transport has one globally active block transaction and is not yet connected to processor-generated L1D misses; this preserves the documented non-coherent L1D behavior until Milestone 5.

```text
four rv32_core instances -> private L1I/L1D -> per-core adapter -> 4-way RR -> controller -> one SRAM
```

Each refill may release arbitration between words, so L1I refill words from different cores and uncached DMEM work can interleave. `0x10000000` is a read-only core-local hart-ID aperture: a read returns the controller-recorded source ID. SRAM and the controller are otherwise shared.

Read and write latencies are independently parameterized and default to two controller cycles. Invalid or unmapped accesses return zero because the audited Sparrow-V memory interface has no error signal; this preserves its available response-only contract and is tested at controller level.
