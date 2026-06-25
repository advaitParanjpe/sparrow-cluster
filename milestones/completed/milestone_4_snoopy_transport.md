# Milestone 4 — Snoopy Coherence Transport Infrastructure

## Status

READY

## Goal

Implement and verify the shared snoopy coherence transport that will support MSI in Milestone 5.

This milestone must establish:

- one globally ordered coherence transaction at a time;
- round-robin arbitration among four L1D coherence requesters;
- command broadcast to all four L1D caches;
- snoop request and response interfaces;
- shared-copy and modified-owner response collection;
- full-cache-block intervention data transfer;
- memory-versus-cache response-source selection;
- SRAM update during modified-owner intervention;
- invalidation acknowledgement transport;
- transaction completion;
- protocol counters and assertions.

The existing L1D caches must remain functionally non-coherent for processor accesses in this milestone.

Do not implement production MSI state transitions yet.

## Required context

Before editing, read:

- `AGENTS.md`
- `README.md`
- `docs/architecture.md`
- `docs/cache_architecture.md`
- `docs/coherence_protocol.md`
- `docs/bus_protocol.md`
- `docs/module_hierarchy.md`
- `docs/interface_audit.md`
- `docs/memory_map.md`
- `docs/verification_plan.md`
- `docs/performance_plan.md`
- `docs/build_roadmap.md`
- `docs/source_manifest.md`
- `docs/risks_and_open_questions.md`
- `docs/build_reports/milestone_1_uncached_cluster.md`
- `docs/build_reports/milestone_2_private_l1i.md`
- `docs/build_reports/milestone_3_private_noncoherent_l1d.md`
- relevant ADRs under `docs/architecture_decisions/`
- current L1D, shared arbiter, memory-controller, SRAM, and system-test implementations

Inspect the repository state before editing.

Do not modify sibling repositories.

Use targeted searches and concise outputs.

## Baseline transport model

The coherence transport must support exactly four L1D coherence participants in the tested system.

The transport uses:

- one active coherence transaction globally;
- round-robin requester arbitration;
- full command broadcast to all L1D caches;
- one requesting cache;
- three peer snoopers;
- block-aligned 16-byte coherence addresses;
- full 16-byte intervention data;
- four sequential 32-bit lower-level words where required;
- globally ordered transaction completion;
- no split transactions;
- no multiple outstanding coherence transactions;
- no directory;
- no NoC or crossbar.

## Important milestone boundary

Milestone 4 proves the transport separately from MSI.

The production L1D caches must not yet:

- transition between `I`, `S`, and `M`;
- invalidate lines because of real processor-generated snoops;
- perform real `BusRd`, `BusRdX`, or `BusUpgr` transitions;
- expose cacheable shared writable data as coherent.

It is acceptable to add:

- dormant or test-controlled snoop ports;
- snoop lookup helpers;
- metadata/data observation interfaces;
- test fixtures representing `shared` or `modified` ownership;
- transport adapters that Milestone 5 will connect to actual MSI controllers.

Do not partially implement MSI and hide it inside the transport milestone.

## Coherence command definitions

Define a canonical command encoding for at least:

- `BUS_RD`
- `BUS_RDX`
- `BUS_UPGR`
- `WRITEBACK`

Optional internal commands may be added only if needed for:

- intervention writeback;
- response collection;
- transaction completion.

Use a shared package or include file for canonical command and response types.

Do not duplicate encodings across modules.

## Transaction interface

Define a stable requester-side coherence interface carrying at least:

- request valid;
- request ready or accepted;
- requester ID;
- coherence command;
- block-aligned address;
- optional writeback data;
- writeback-data-valid;
- response valid;
- response data;
- shared indication;
- modified-owner indication;
- completion;
- error indication if supported.

The exact signal names may differ, but the semantics must be documented.

A requester must hold command and address stable until acceptance.

A transaction remains associated with the granted requester until completion.

## Snooper interface

Each L1D participant must receive:

- snoop valid;
- snoop command;
- block-aligned address;
- requester ID;
- indication that the snoop concerns another cache.

Each snooper must return a stable response including at least:

- response valid;
- block present or shared indication;
- modified-owner indication;
- intervention data valid;
- full 16-byte data when acting as modified owner;
- invalidation acknowledgement where applicable;
- completion or ready indication.

The requester must not snoop itself as a peer.

The transport must reject or assert against more than one modified owner.

## Transport phases

Implement a clear transaction state machine with phases equivalent to:

1. Idle
2. Request arbitration
3. Command broadcast
4. Snoop lookup
5. Snoop response collection
6. Response-source selection
7. Memory access or intervention transfer
8. Optional SRAM update
9. Requester response
10. Completion

The exact state partition may differ, but each phase must be observable and documented.

## Arbitration

Implement round-robin arbitration among four coherence requesters.

Requirements:

- only one requester granted;
- priority advances after completed transactions;
- active ownership retained through completion;
- bounded starvation under continuous requests;
- reset initializes priority deterministically;
- simultaneous requests from all four caches are tested;
- requester identity is preserved through all transaction phases.

Do not arbitrate individual refill words as independent coherence transactions.

## Command broadcast

After grant:

- broadcast one canonical command and block address;
- all non-requesting L1D participants observe the same command;
- all snoopers receive the command in the same global order;
- snoop response collection begins only after a valid broadcast;
- command and address remain stable through the defined snoop phase.

Add assertions that all snoopers observe identical command/address values for a transaction.

## Snoop response collection

Collect responses from all non-requesting caches.

The transport must determine:

- whether any peer holds a copy;
- whether any peer claims modified ownership;
- whether intervention data is available;
- whether all required snoop responses have arrived;
- whether required invalidation acknowledgements have arrived.

Requirements:

- no transaction advances before all required snoopers respond;
- requester response is not generated early;
- duplicate snoop responses are rejected or ignored safely;
- requester ID is excluded from peer-response requirements;
- missing responses lead to bounded timeout detection in verification.

## Modified-owner intervention

Freeze and implement this baseline behavior:

1. One peer cache may identify itself as modified owner.
2. That owner provides the authoritative 16-byte cache block.
3. The requester receives that block.
4. Shared SRAM is updated with the same block as part of the same coherence transaction.
5. The transaction completes only after the requester response and required SRAM update complete.

Use four sequential 32-bit SRAM writes unless a clean internal block-write helper already exists.

Requirements:

- intervention data must come from exactly one owner;
- owner data must take priority over SRAM;
- all four words must be transferred correctly;
- SRAM update uses the same data delivered to the requester;
- no stale SRAM data may be returned when a modified owner exists;
- no transaction completes before the intervention update is safely accepted.

Do not yet change the owner cache’s MSI state in production logic. That occurs in Milestone 5.

## Shared-copy behavior

If one or more peers indicate a clean shared copy but no modified owner exists:

- the transaction records `shared_seen`;
- SRAM remains the authoritative data source;
- requester receives SRAM data when data is required;
- no peer data transfer is required.

The shared indication must be returned to the requester for future MSI use.

## No-peer-copy behavior

If no snooper reports a copy:

- SRAM provides the requested block when required;
- `shared_seen` is false;
- `modified_owner_seen` is false.

This result will later allow MESI experimentation, but MESI must not be implemented now.

## `BUS_RD` behavior

Transport-only behavior:

- broadcast `BUS_RD`;
- collect peer-presence and modified-owner responses;
- if modified owner exists, use intervention data and update SRAM;
- otherwise fetch the full block from SRAM;
- return block data and `shared_seen` metadata to requester;
- complete transaction.

No production cache state change is implemented yet.

## `BUS_RDX` behavior

Transport-only behavior:

- broadcast `BUS_RDX`;
- collect peer-presence, modified-owner, and invalidation acknowledgements;
- if modified owner exists, use intervention data and update SRAM;
- otherwise fetch data from SRAM;
- return the block to requester;
- complete only after all required peer acknowledgements.

Actual peer invalidation state transitions are deferred to Milestone 5.

Test snoopers may emulate acknowledgement behavior.

## `BUS_UPGR` behavior

Transport-only behavior:

- broadcast `BUS_UPGR`;
- no data response required;
- collect all required invalidation acknowledgements;
- complete only when acknowledgements are received;
- assert if a peer claims modified ownership for the same block.

Actual state invalidation is deferred to Milestone 5.

## `WRITEBACK` behavior

Support a requester writing a full 16-byte dirty block to SRAM.

Requirements:

- block address aligned;
- four words transferred correctly;
- no snoop broadcast required unless the architecture document explicitly requires observation;
- requester receives completion only after SRAM accepts the full block;
- writeback is globally ordered against coherence transactions.

Do not conflate a normal L1D dirty eviction writeback with modified-owner intervention.

Document both paths.

## Shared SRAM interaction

The coherence transport must connect to the existing shared memory controller or a clearly factored cache-block adapter.

Requirements:

- word-sized SRAM interface remains valid;
- block reads use four ordered 32-bit reads;
- block writes use four ordered 32-bit writes;
- no burst protocol;
- only one memory-side operation active at a time;
- memory response cannot be routed to the wrong coherence transaction;
- existing uncached MMIO/control traffic remains supported.

Do not break L1I refill or L1D uncached traffic.

## Integration with existing traffic

The system currently contains:

- L1I refill traffic;
- L1D refill traffic;
- L1D dirty writebacks;
- L1D uncached bypass traffic.

Milestone 4 must introduce a clear boundary between:

- coherence-capable L1D block transactions;
- ordinary uncached/MMIO transactions;
- L1I refill transactions.

Preferred structure:

```text
L1D coherence requesters
        |
Snoopy coherence transport
        |
Memory-side block adapter
        |
Existing shared memory controller/SRAM
```

L1I and uncached traffic may continue to share the lower-level serialized path.

Do not create ambiguous ownership between the old arbiter and new transport.

Document the final arbitration hierarchy.

## Test-controlled snoop agents

Because MSI is not yet connected, create reusable verification snoop agents or fixtures able to emulate:

- no cached peer copy;
- one or more shared copies;
- one modified owner;
- invalidation acknowledgement delay;
- modified-owner data delay;
- malformed duplicate modified-owner response;
- missing acknowledgement;
- backpressure.

These test agents must use the same interfaces that production L1D caches will use in Milestone 5.

Avoid writing a transport testbench that bypasses the intended production interface.

## Counters

Add transport counters for:

- total coherence transactions;
- `BUS_RD`;
- `BUS_RDX`;
- `BUS_UPGR`;
- `WRITEBACK`;
- transactions with shared copies;
- modified-owner interventions;
- SRAM block reads;
- SRAM block writes;
- invalidation acknowledgements;
- arbitration wait cycles per requester;
- occupied transport cycles;
- protocol-error detections;
- timeout detections in verification where applicable.

Counters may remain internal or testbench-visible.

Document exact counting points.

## Explicit exclusions

Do not implement:

- production MSI stable-state transitions;
- production MSI transient-state transitions;
- actual L1D invalidation;
- cacheable shared-memory correctness;
- LR.W;
- SC.W;
- reservation tracking;
- atomics;
- MESI;
- MSHRs;
- hit-under-miss;
- multiple outstanding coherence transactions;
- directory coherence;
- L2;
- crossbar or NoC;
- bursts;
- coherent L1I;
- self-modifying code;
- SparrowML execution;
- FPGA deployment;
- ASIC physical evaluation.

Do not begin Milestone 5.

## Functional requirements

The implementation must demonstrate:

1. Four coherence requester ports.
2. One active coherence transaction globally.
3. Round-robin requester arbitration.
4. Stable command/address capture.
5. Broadcast to all non-requesting snoopers.
6. Correct snooper exclusion for requester.
7. Complete snoop-response collection.
8. Shared-copy aggregation.
9. Single modified-owner detection.
10. Modified-owner data intervention.
11. Requester receives intervention data.
12. SRAM receives the same intervention data.
13. SRAM response when no modified owner exists.
14. `BUS_RD` transport behavior.
15. `BUS_RDX` transport behavior.
16. `BUS_UPGR` acknowledgement behavior.
17. Full-block `WRITEBACK`.
18. Correct four-word block reads and writes.
19. Correct response routing.
20. Existing L1I and uncached traffic remain functional.
21. No production MSI state changes.

## Verification requirements

### Unit tests

Add focused tests for:

- idle reset behavior;
- one requester;
- simultaneous requests from all four requesters;
- grant order `0,1,2,3`;
- priority rotation after completion;
- held request stability;
- requester identity retention;
- command broadcast;
- requester excluded from snoop requirements;
- no-peer-copy `BUS_RD`;
- one shared-copy `BUS_RD`;
- multiple shared-copy `BUS_RD`;
- modified-owner `BUS_RD`;
- modified-owner intervention data integrity;
- SRAM update after intervention;
- no stale SRAM response during intervention;
- no-peer-copy `BUS_RDX`;
- shared-copy `BUS_RDX`;
- modified-owner `BUS_RDX`;
- delayed invalidation acknowledgements;
- `BUS_UPGR`;
- delayed `BUS_UPGR` acknowledgements;
- illegal modified-owner response to `BUS_UPGR`;
- full-block `WRITEBACK`;
- delayed memory responses;
- backpressure;
- duplicate snoop response;
- two modified-owner claims;
- missing acknowledgement timeout in verification;
- response to correct requester only;
- counter consistency.

### Four-core transport integration

Test:

- all four requesters continuously issuing transactions;
- deterministic rotation;
- different commands interleaved;
- one requester using intervention while others wait;
- L1I refill traffic contending below the transport;
- uncached/MMIO traffic contending below the transport;
- no cross-requester response corruption;
- no transaction overlap;
- no starvation.

### Existing-system regression

All Milestone 1–3 tests must remain valid.

The production L1D caches may remain on their existing non-coherent behavior while the transport is tested through dedicated interfaces or a test mode.

Do not weaken previous functional tests.

### Assertions

Add bounded assertions for:

- at most one active coherence transaction;
- grant is one-hot;
- active requester remains stable;
- command and address remain stable after acceptance;
- all snoopers observe identical command and address;
- requester is not counted as a snoop peer;
- response collection waits for all required peers;
- at most one modified owner;
- intervention data valid only when modified owner exists;
- SRAM data is not selected when modified owner exists;
- requester intervention data equals SRAM-update data;
- exactly four block words transferred;
- word index remains in range;
- block addresses are 16-byte aligned;
- `BUS_UPGR` returns no data;
- `BUS_RDX` and `BUS_UPGR` wait for required acknowledgements;
- completion occurs exactly once;
- no completion without active transaction;
- no response delivered to a non-requester;
- round-robin arbitration is bounded;
- transaction counters increment once per accepted command.

Use assertions compatible with Icarus.

## Documentation updates

Update:

- `README.md`
- `docs/architecture.md`
- `docs/coherence_protocol.md`
- `docs/bus_protocol.md`
- `docs/module_hierarchy.md`
- `docs/interface_audit.md`
- `docs/verification_plan.md`
- `docs/performance_plan.md`
- `docs/build_roadmap.md`
- `docs/source_manifest.md`
- `docs/risks_and_open_questions.md`

Create:

- `docs/build_reports/milestone_4_snoopy_transport.md`

The report must record:

- final requester interface;
- final snooper interface;
- transaction phases;
- arbitration behavior;
- response aggregation;
- modified-owner intervention policy;
- SRAM update sequence;
- memory-versus-cache source selection;
- acknowledgement handling;
- counter definitions;
- verification agents;
- tests and measured results;
- functionality deliberately absent.

Update:

- `reports/current_milestone_report.md`

Use this exact milestone name.

## Required commands

Provide and run:

```bash
make milestone-check
make check
make docs-check
make sim-unit
make sim-l1i
make sim-l1d
make sim-snoop-transport
make sim-cluster
make sim-multicore
make regress
git diff --check
git status --short
```

Target intent:

- `make sim-unit`: all focused units through Milestone 4.
- `make sim-snoop-transport`: transport-specific directed and adverse-condition tests.
- `make sim-cluster`: four-core hardware integration.
- `make sim-multicore`: prior valid software behavior.
- `make regress`: complete regression through Milestone 4.

Do not make `make check` run the full simulation regression.

## Completion gate

Milestone 4 is complete only when:

- four coherence requester ports exist;
- one globally ordered coherence transaction is active at a time;
- round-robin arbitration is verified;
- commands broadcast identically to all non-requesting snoopers;
- snoop responses are collected correctly;
- shared-copy aggregation works;
- at most one modified owner is accepted;
- modified-owner intervention transfers the correct 16-byte block;
- requester receives the intervention block;
- SRAM is updated with the identical intervention block;
- stale SRAM data is never selected when a modified owner exists;
- SRAM provides data when no modified owner exists;
- `BUS_RD` transport behavior is verified;
- `BUS_RDX` transport behavior is verified;
- `BUS_UPGR` acknowledgement behavior is verified;
- full-block `WRITEBACK` is verified;
- four-word reads and writes are verified;
- delayed responses and acknowledgements are handled;
- adverse responses are detected;
- no response reaches the wrong requester;
- existing L1I, L1D, uncached, and multicore regressions pass;
- production L1D caches remain non-coherent;
- no MSI state transitions are implemented;
- required assertions pass;
- required counters are tested;
- documentation matches implementation;
- `make check` passes;
- `make docs-check` passes;
- `make sim-unit` passes;
- `make sim-l1i` passes;
- `make sim-l1d` passes;
- `make sim-snoop-transport` passes;
- `make sim-cluster` passes;
- `make sim-multicore` passes;
- `make regress` passes;
- no LR/SC, MESI, L2, or Milestone 5 functionality has been added;
- `reports/current_milestone_report.md` identifies this milestone and contains `STATUS: COMPLETE`.

Use `STATUS: BLOCKED` only for a genuine external, architectural, or toolchain blocker that prevents further progress.

If required work remains but can still be implemented, use `STATUS: IN_PROGRESS` and continue iterating.

Do not mark the milestone complete based only on compilation or a single happy-path transport test.

## Completion report

Use this exact structure:

```text
STATUS:
MILESTONE:

SUMMARY:

IMPLEMENTED:

VERIFICATION:

RESULTS:

FILES CHANGED:

LIMITATIONS / OPEN ISSUES:

NEXT RECOMMENDED MILESTONE:
```

Include concrete results such as:

- transport tests passed;
- requester grant order;
- commands exercised;
- intervention transactions;
- block words transferred;
- SRAM updates;
- acknowledgement-delay scenarios;
- malformed-response detections;
- counter values;
- regression commands passed;
- known Icarus warnings;
- remaining deliberate limitations.

Do not paste complete source files or documentation.