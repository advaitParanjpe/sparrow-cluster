# Architecture

Milestone 1 is an uncached, strongly ordered four-core system. Each imported `rv32_core` has one `core_adapter`; an adapter captures either one IMEM or one DMEM request, then holds its captured metadata until exactly one response returns. When both local ports request, local round-robin starts with IMEM after reset and alternates after accepted work. A four-way global round-robin arbiter accepts one adapter request only when the controller is idle. The controller retains source core and port through fixed latency and returns the response only to that adapter.

```text
four rv32_core instances -> per-core IMEM/DMEM adapter -> 4-way RR -> controller -> one SRAM
```

`0x10000000` is a read-only core-local hart-ID aperture: a read returns the controller-recorded source ID. SRAM and the controller are otherwise shared. This interface is the later cache insertion boundary; it is not a cache implementation.

Read and write latencies are independently parameterized and default to two controller cycles. Invalid or unmapped accesses return zero because the audited Sparrow-V memory interface has no error signal; this preserves its available response-only contract and is tested at controller level.
