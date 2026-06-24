# Milestone 3 — Private Non-Coherent L1 Data Caches

## Status

READY

## Goal

Add one private blocking L1 data cache to each of the four Sparrow-V cores while preserving all completed Milestone 1 and Milestone 2 behavior.

Each L1D must be:

- 2 KiB;
- 2-way set associative;
- 16-byte cache blocks;
- 64 sets;
- blocking;
- write-back;
- write-allocate;
- capable of byte, halfword, and word accesses supported by Sparrow-V;
- non-coherent during this milestone;
- connected to the existing shared word-sized memory path.

This milestone must establish correct private data-cache behavior, including refill, store merging, dirty eviction, and uncached-address bypass, without implementing MSI, snooping, LR/SC, or other later functionality.

## Required context

Before editing, read:

- `AGENTS.md`
- `README.md`
- `docs/architecture.md`
- `docs/cache_architecture.md`
- `docs/interface_audit.md`
- `docs/module_hierarchy.md`
- `docs/memory_map.md`
- `docs/boot_and_runtime.md`
- `docs/verification_plan.md`
- `docs/performance_plan.md`
- `docs/build_roadmap.md`
- `docs/source_manifest.md`
- `docs/risks_and_open_questions.md`
- `docs/build_reports/milestone_1_uncached_cluster.md`
- `docs/build_reports/milestone_2_private_l1i.md`
- relevant ADRs under `docs/architecture_decisions/`
- current L1I, adapter, arbiter, memory-controller, SRAM, and multicore test implementations

Inspect the present repository state before editing.

Do not modify sibling repositories.

Use targeted searches and concise command output. Avoid repeatedly reading large source files.

## Baseline architecture

The frozen L1D configuration is:

- one private L1D per core;
- capacity: 2 KiB;
- associativity: 2 ways;
- cache-block size: 16 bytes;
- sets: 64;
- words per cache block: 4;
- processor data width: 32 bits;
- blocking miss handling;
- one active L1D transaction per core;
- write-back;
- write-allocate;
- one replacement bit per set;
- no coherence;
- no snooping;
- no cache-to-cache transfers;
- no LR/SC;
- no MSHRs;
- shared lower-level memory remains globally serialized.

For a 32-bit byte address:

- byte offset: bits `[1:0]`;
- word offset: bits `[3:2]`;
- set index: bits `[9:4]`;
- tag: bits `[31:10]`.

Verify these widths against the implemented address width and document the actual values.

## Critical non-coherent-system rule

Private L1D caches are not yet coherent.

Therefore, this milestone must not allow ordinary shared synchronization or shared writable communication to rely on cached copies.

Implement and document an explicit address policy:

### Cacheable region

Normal SRAM data intended for:

- private per-core stacks;
- private data;
- read-only shared data after initialization;
- statically partitioned writable arrays where no cache block is accessed by more than one core.

### Uncached region

Use an uncached region for:

- hart-ID reads;
- release flags;
- per-core completion words;
- control/status registers;
- simulation completion;
- temporary pre-coherence synchronization;
- any shared writable location observed by multiple cores.

The uncached region must bypass L1D and use the existing shared-memory/MMIO path directly.

Prefer preserving the current control/status map where practical.

Do not use software cache flushes as a substitute for coherence.

Do not claim shared-memory coherence during this milestone.

## Implementation scope

### 1. Implement a reusable L1D module

Create a synthesizable private data-cache module with:

- processor-side request/response interface compatible with the current Sparrow-V DMEM boundary;
- lower-level word request/response interface compatible with the existing shared system path;
- two tag ways;
- two 16-byte data ways;
- valid metadata;
- dirty metadata;
- one replacement bit per set;
- blocking controller;
- four-word refill;
- four-word dirty writeback;
- byte-enable-aware store updates;
- uncached bypass path;
- reset invalidation.

Parameterize only where useful:

- address width;
- data width;
- sets;
- ways;
- cache-block bytes;
- cacheable address range or decode parameters.

Do not over-generalize beyond the tested baseline.

### 2. Preserve Sparrow-V DMEM semantics

Audit and preserve the actual DMEM handshake.

Requirements:

- request address, write data, byte enables, and operation remain stable while stalled;
- each accepted core request receives exactly one response;
- no response is returned without a tracked request;
- load result formatting remains compatible with the existing core;
- store completion semantics remain unchanged;
- existing alignment and trap behavior remain unchanged;
- byte, halfword, and word write masks are preserved;
- no duplicate store or repeated side effect occurs under backpressure.

Determine whether sign and zero extension happen inside Sparrow-V or the memory subsystem. Preserve the existing split of responsibility.

### 3. Load hit behavior

For a cacheable load hit:

1. Match tag and valid state.
2. Select the matching way.
3. Select the requested word from the cache block.
4. Return the 32-bit word expected by Sparrow-V.
5. Update replacement state.
6. Increment relevant counters.

The cache must not respond from an invalid way.

At most one way may match.

### 4. Store hit behavior

For a cacheable store hit:

1. Match the cache block.
2. Update only bytes enabled by the request byte mask.
3. Preserve all non-enabled bytes.
4. Mark the block dirty.
5. Update replacement state.
6. Complete the processor request without immediately writing SRAM.

Support the byte masks produced for:

- `SB`;
- `SH`;
- `SW`.

Preserve existing misalignment behavior.

### 5. Read miss behavior

For a cacheable load miss:

1. Capture the processor request.
2. Select an invalid way if available.
3. Otherwise select the replacement victim.
4. If the victim is valid and dirty, write back all four words.
5. Refill all four words of the requested block.
6. Install tag, valid, and clean metadata.
7. Return the requested word.
8. Update replacement state and counters.

### 6. Write miss behavior

Use write-allocate.

For a cacheable store miss:

1. Capture the store address, data, and byte enables.
2. Select a victim.
3. Write back a dirty victim if necessary.
4. Refill the requested cache block.
5. Install the new block.
6. Merge the pending store into the correct word and bytes.
7. Mark the block dirty.
8. Complete the processor request.

Do not issue a direct write-around for cacheable store misses.

### 7. Dirty eviction

A valid dirty victim must be written back before replacement.

Requirements:

- four sequential 32-bit write transactions;
- block-aligned victim base address;
- correct word order;
- correct data;
- full-word byte enables for writeback;
- no victim metadata destroyed before writeback completes;
- no processor completion before required writeback and refill finish;
- dirty bit clears only when the old block is safely written back or replaced;
- writeback traffic remains associated with the correct core/cache.

A clean victim must not generate writeback traffic.

### 8. Refill behavior

Use four sequential 32-bit reads.

Requirements:

- block-aligned refill base;
- word indices 0 through 3;
- correct ordering or explicit per-word placement;
- delayed-response tolerance;
- interleaving with traffic from other cores is allowed;
- no requirement to lock the shared path for a whole cache-block operation;
- each word response reaches the correct cache;
- cache installation occurs only after the complete refill;
- the pending load or store completes only after the required block contents are available.

Do not add burst support.

### 9. Uncached bypass

Addresses in the uncached region must:

- bypass tag lookup for functional purposes;
- not allocate into L1D;
- not update L1D replacement state;
- not alter valid or dirty metadata;
- issue one lower-level word transaction through the existing shared path;
- preserve original byte enables for stores;
- return the lower-level response to the requesting core;
- remain globally visible according to Milestone 1 serialization.

The uncached decode must be deterministic and documented.

Add tests proving uncached writes are immediately observable by another core and do not enter the cache.

### 10. Reset behavior

On reset:

- all valid bits clear;
- all dirty bits clear;
- controller returns to idle;
- no stale processor or lower-level response may be emitted;
- tag/data arrays need not be zeroed if invalid metadata is correctly cleared;
- replacement bits initialize deterministically;
- performance counters reset.

### 11. Four-core integration

Instantiate one private L1D per core.

The architecture becomes:

```text
Sparrow-V Core
   ├── private L1I
   └── private L1D
          ├── cacheable path
          └── uncached bypass
                   |
          per-core system request source
                   |
          existing local/global arbitration
                   |
          shared memory controller
                   |
          shared SRAM
```

L1I behavior must remain unchanged.

The global system must arbitrate among:

- L1I refill traffic;
- L1D refill reads;
- L1D dirty writebacks;
- L1D uncached loads and stores.

Preserve explicit source and port tracking.

### 12. Performance counters

Add per-core L1D counters for:

- accesses;
- load accesses;
- store accesses;
- hits;
- misses;
- load misses;
- store misses;
- refill words;
- dirty writeback words;
- dirty evictions;
- uncached accesses;
- miss-stall cycles where practical.

Use a clear counting convention.

At minimum verify:

```text
accesses = hits + misses + uncached_accesses
```

if uncached accesses are excluded from hit/miss lookup counts.

Alternatively, if all processor requests count as accesses and uncached requests are treated separately, document and test the chosen equation precisely.

Do not add software-visible performance CSRs unless this is already easy and consistent with the current implementation.

## Explicit exclusions

Do not implement:

- MSI;
- MESI;
- coherence state bits;
- snooping;
- invalidation;
- cache-to-cache transfers;
- LR.W;
- SC.W;
- reservations;
- atomic locks;
- MSHRs;
- hit-under-miss;
- multiple outstanding L1D misses;
- write combining;
- store buffers;
- hardware prefetching;
- victim caches;
- an L2 cache;
- bursts;
- multiple global outstanding transactions;
- coherent instruction caches;
- self-modifying code support;
- SparrowML execution;
- FPGA deployment;
- ASIC physical-design evaluation.

Do not begin Milestone 4.

## Functional requirements

The implementation must demonstrate:

1. Four private L1D caches.
2. 2 KiB per cache.
3. Two ways and 64 sets.
4. 16-byte cache blocks.
5. Blocking behavior.
6. Load hits.
7. Store hits.
8. Byte, halfword, and word updates.
9. Write-allocate store misses.
10. Four-word refills.
11. Four-word dirty writebacks.
12. Clean evictions without writeback.
13. Dirty evictions with correct writeback.
14. Deterministic replacement.
15. Reset invalidation.
16. Correct uncached bypass.
17. Interleaved traffic from multiple cores.
18. Continued L1I correctness.
19. Continued Milestone 1 and Milestone 2 behavior.
20. Accurate L1D counters.
21. No claim or accidental dependency on coherence.

## Verification requirements

### Unit tests

Add focused L1D tests for:

- cold load miss and refill;
- load hit after refill;
- all four word offsets;
- store hit;
- byte store to each byte lane;
- halfword store to legal lanes;
- full-word store;
- preservation of non-enabled bytes;
- store miss with write allocate;
- clean victim replacement;
- dirty victim writeback;
- correct four-word writeback order;
- writeback followed by refill;
- same-set two-way occupancy;
- third conflicting block replacement;
- invalid-way preference;
- deterministic pseudo-LRU update;
- delayed lower-level responses;
- backpressure;
- reset invalidation;
- reset during idle;
- uncached load;
- uncached store;
- uncached no-allocation behavior;
- counter correctness;
- invalid access behavior consistent with Milestone 1.

### Four-core integration tests

Test:

- simultaneous cold L1D misses from all four cores;
- interleaved refills;
- interleaved dirty writebacks;
- L1I and L1D contention;
- uncached completion flags;
- private per-core cached stacks;
- statically partitioned cached arrays;
- no cross-core response corruption;
- repeated arbitration rotation.

### Non-coherence demonstration

Add a deliberate verification-only demonstration showing why shared writable cacheable data is unsafe before MSI.

This must not be a passing functional requirement based on incoherent behavior.

Preferred approach:

- document or simulate two cores caching the same block;
- show that one core’s write is not automatically visible to the other;
- mark the scenario as an expected non-coherent limitation;
- ensure normal regressions use the uncached region or non-overlapping cache blocks for communication.

Do not make the regression depend on nondeterministic stale-data outcomes.

### Software/system tests

Adapt the existing multicore software tests so they remain valid with non-coherent L1D caches.

Required policies:

- release flags and completion words use uncached addresses;
- shared writable communication uses uncached addresses unless statically partitioned and never read by another core during execution;
- per-core stacks are cacheable and disjoint;
- shared read-only data may be cacheable only after initialization and release through the uncached flag;
- partitioned arrays must be aligned or padded to prevent two cores writing the same cache block.

Required programs:

1. Existing hart-ID and stack-isolation test through private L1D stacks.
2. Shared read-only data test using uncached release synchronization.
3. Partitioned cached-array writes with cache-block-disjoint ownership.
4. Uncached communication test proving immediate cross-core visibility.
5. Dirty eviction test that validates final SRAM contents after replacement.
6. Byte/halfword/word store test through the real core.
7. Combined L1I/L1D stress test.

If final SRAM validation requires explicit eviction because dirty data may remain resident, construct the test to force eviction rather than adding a flush instruction.

### Assertions

Add bounded assertions for:

- no hit from an invalid way;
- at most one matching way;
- load-hit data comes from the matched way and correct offset;
- store-hit changes only enabled bytes;
- dirty bit is set on cacheable store completion;
- clean victim does not produce writeback;
- dirty victim produces exactly four writeback words;
- writeback base address is block-aligned;
- refill base address is block-aligned;
- refill and writeback word indices remain in range;
- replacement selects a legal way;
- metadata is not overwritten before dirty writeback completes;
- installation occurs only after full refill;
- processor completion occurs exactly once;
- lower-level completion is consumed only by the owning cache;
- one L1D has at most one active transaction;
- uncached accesses do not allocate;
- uncached accesses do not modify replacement or dirty metadata;
- reset clears valid and dirty state;
- counters obey the documented consistency equations.

Use assertions compatible with the existing Icarus flow.

### Regression preservation

All Milestone 1 and Milestone 2 tests must continue to pass, adapted only where the new explicit cacheable/uncached policy requires valid software address changes.

Do not weaken existing checks merely to make the new cache pass.

## Documentation updates

Update:

- `README.md`
- `docs/architecture.md`
- `docs/cache_architecture.md`
- `docs/module_hierarchy.md`
- `docs/interface_audit.md`
- `docs/memory_map.md`
- `docs/boot_and_runtime.md`
- `docs/verification_plan.md`
- `docs/performance_plan.md`
- `docs/build_roadmap.md`
- `docs/source_manifest.md`
- `docs/risks_and_open_questions.md`

Create:

- `docs/build_reports/milestone_3_private_noncoherent_l1d.md`

The report must record:

- implemented cache geometry;
- address decomposition;
- cacheable and uncached address regions;
- replacement convention;
- processor-side semantics;
- refill sequence;
- writeback sequence;
- store-merge behavior;
- dirty eviction behavior;
- counter definitions;
- software-test adaptations;
- non-coherence limitation;
- tests and measured outcomes;
- deliberately absent functionality.

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
make sim-cluster
make sim-multicore
make regress
git diff --check
git status --short
```

Target intent:

- `make sim-unit`: all focused unit tests from Milestones 1–3.
- `make sim-l1i`: existing L1I tests.
- `make sim-l1d`: L1D-specific unit and integration tests.
- `make sim-cluster`: four-core hardware integration.
- `make sim-multicore`: valid bare-metal multicore software through private L1I/L1D.
- `make regress`: all required tests through Milestone 3.

Do not make `make check` run the full simulation regression.

## Completion gate

Milestone 3 is complete only when:

- each core has one private L1D;
- each L1D is 2 KiB, 2-way, 64-set, and uses 16-byte cache blocks;
- each cache is blocking with one active transaction;
- write-back and write-allocate are implemented;
- load hits are correct;
- store hits are correct;
- byte, halfword, and word store masks are verified;
- cold load misses refill correctly;
- store misses allocate and merge correctly;
- clean replacement is verified;
- dirty replacement performs exactly four correct writeback words;
- writeback followed by refill is verified;
- all four word offsets are verified;
- two-way conflicts and deterministic replacement are verified;
- reset clears valid and dirty metadata;
- an explicit uncached region bypasses L1D;
- synchronization and completion use valid uncached communication;
- uncached accesses are cross-core visible and do not allocate;
- four-core simultaneous and interleaved L1D traffic is verified;
- L1I functionality remains correct;
- all four cores complete valid software tests;
- cached writable sharing is not used as though coherence exists;
- the non-coherence limitation is explicitly demonstrated and documented;
- L1D counters are tested and consistent;
- all required assertions pass;
- all prior valid regressions pass;
- required documentation matches implementation;
- `make check` passes;
- `make docs-check` passes;
- `make sim-unit` passes;
- `make sim-l1i` passes;
- `make sim-l1d` passes;
- `make sim-cluster` passes;
- `make sim-multicore` passes;
- `make regress` passes;
- no MSI, snooping, LR/SC, L2, or Milestone 4 functionality has been added;
- `reports/current_milestone_report.md` identifies this milestone and contains `STATUS: COMPLETE`.

Use `STATUS: BLOCKED` only for a genuine external, architectural, or toolchain blocker that prevents further progress.

If required work remains but can still be implemented, use `STATUS: IN_PROGRESS` and continue iterating.

Do not mark the milestone complete based only on cache compilation or one passing directed test.

## Completion report

Use this exact structure in `reports/current_milestone_report.md` and the final Codex response:

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

- L1D unit scenarios passed;
- cores completing;
- accesses, hits, misses, refill words, and writeback words;
- dirty eviction scenarios;
- byte/halfword/word store results;
- uncached-bypass results;
- arbitration and contention scenarios;
- regression commands passed;
- any known Icarus warnings;
- remaining deliberate limitations.

Do not paste complete source files or complete documentation into the final response.