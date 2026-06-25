# Milestone 5 - MSI Coherence Integration

## Summary

Milestone 5 connects all four production `l1_data_cache` instances to the verified `snoopy_coherence_transport`. Cacheable SRAM traffic now uses blocking MSI coherence; uncached/MMIO traffic still bypasses allocation and coherence through the existing adapter path.

## Production MSI encoding

`I=0`, `S=1`, and `M=2` are the authoritative resident-line metadata. `I` means invalid, `S` means valid clean shared, and `M` means valid dirty owner. There are no separate architectural valid or dirty arrays.

## Transient states

The L1D controller uses explicit transaction phases: `IDLE`, `EVICT_REQ`, `EVICT_WAIT`, `COH_REQ`, `COH_WAIT`, `UNC_REQ`, `UNC_WAIT`, and `RESP`. `COH_REQ/COH_WAIT` represent `IS`, `IM`, and `SM` based on the pending command (`BUS_RD`, `BUS_RDX`, or `BUS_UPGR`). `EVICT_REQ/EVICT_WAIT` represent modified victim writeback.

## Processor transitions

| Event | Action |
| --- | --- |
| Load hit `S` | return word, remain `S` |
| Load hit `M` | return word, remain `M` |
| Store hit `M` | merge strobed bytes, remain `M` |
| Store hit `S` | issue `BUS_UPGR`, transition to `M`, merge |
| Load miss `I` | write back `M` victim if needed, issue `BUS_RD`, install `S` |
| Store miss `I` | write back `M` victim if needed, issue `BUS_RDX`, install `M`, merge |
| Evict `S` | discard without writeback |
| Evict `M` | issue full-block `WRITEBACK` before replacement |

## Snoop transitions

| Snoop | `I` | `S` | `M` |
| --- | --- | --- | --- |
| `BUS_RD` | no copy | report shared | supply block, `M->S` |
| `BUS_RDX` | ack | invalidate | supply block, `M->I` |
| `BUS_UPGR` | ack | invalidate | protocol-error counter |

## Priority and deadlock avoidance

Local CPU requests are accepted only from `IDLE`. Stable MSI arrays always answer peer snoops. A requester is not snooped by its own transport transaction. If another granted transaction invalidates a pending local upgrade before that local request is granted, the local pending command is promoted from `BUS_UPGR` to `BUS_RDX`, avoiding completion of a store without ownership. The transport permits one global transaction at a time, so there is no MSHR or multi-transaction deadlock cycle.

## Eviction and intervention

Dirty evictions use `WRITEBACK` with all four words. Modified-owner intervention supplies the same 16-byte block to the requester and SRAM through the transport. Clean shared victims are discarded without SRAM traffic.

## Cacheable and uncached policy

Mapped SRAM is coherent and cacheable except `0x200..0x20f`, `0x300..0x30f`, `0x400..0x40f`, `0x600..0x60f`, and `0x10000000`, which remain uncached. Uncached accesses do not allocate or modify MSI metadata.

## Counters

L1D counters include accesses, loads, stores, hits, misses, load/store misses, refill words, writeback words, dirty evictions, uncached accesses, stall cycles, load hits in `S`/`M`, store hits in `M`, store upgrades, bus command requests, writebacks, snoop hits, interventions, invalidations, downgrades, ownership transfers, coherence stalls, and protocol errors. Transport counters from Milestone 4 are reused.

## Directed tests

`make sim-msi` covers cold read, two/four readers, cold write, writer-to-reader intervention, writer replacement, shared upgrade, four-reader invalidation, byte/half/word stores, dirty eviction, clean eviction, independent blocks, and concurrent four-core requests.

## Randomized test

`make sim-coherence-random` uses seed `0x5eed1234`, 96 deterministic word operations, and checked loads against a testbench reference model. The default run reported `tx=85`, `BUS_RD=29`, `BUS_RDX=49`, `BUS_UPGR=7`, and `WRITEBACK=0`.

## Software and system tests

`make sim-cluster` and `make sim-multicore` continue to run four real cores with coherent L1D present. The checked-in software still uses uncached control flags because LR/SC is absent; cacheable stack and partition activity remains covered.

## Invariant checks

Assertions check invalid hits, duplicate resident ways, upgrades without a shared copy, stores completing outside `M`, requester self-snoop, stale SRAM selection over a modified owner, and accounting consistency. Directed tests also check intervention data reaching SRAM.

## Coverage matrix

| Feature | Covered by |
| --- | --- |
| `I->S`, load hits in `S`/`M` | `sim-l1d`, `sim-msi`, random |
| `I->M`, store hit `M` | `sim-l1d`, `sim-msi`, random |
| `S->M` upgrade | `sim-l1d`, `sim-msi`, random |
| `M->S` and `M->I` intervention | `sim-msi` |
| `S->I` invalidation | `sim-msi` |
| Dirty and clean eviction | `sim-l1d`, `sim-msi` |
| Byte, halfword, word stores | `sim-msi` |
| Concurrent arbitration | `sim-msi`, `sim-cluster` |
| Uncached/coherent coexistence | `sim-l1d`, `sim-cluster`, `sim-multicore` |

## Measured results

Required milestone commands were run during completion; see `reports/current_milestone_report.md` for the final command list and status.

## Known limitations

LR.W, SC.W, reservations, atomics, MESI, non-blocking caches, L2, coherent L1I, coherent DMA, SparrowML integration, and FPGA/ASIC work remain absent by design.
