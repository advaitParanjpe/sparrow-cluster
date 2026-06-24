# Milestone 2 — Private L1 Instruction Caches

## Status

READY

## Goal

Add one private blocking L1 instruction cache to each of the four Sparrow-V cores while preserving all Milestone 1 functionality.

Each L1I must be:

- 2 KiB;
- 2-way set associative;
- 16-byte cache blocks;
- 64 sets;
- blocking;
- non-coherent;
- read-only during normal execution;
- connected through the existing shared request path and shared SRAM.

This milestone must establish a correct and reusable instruction-cache implementation without adding L1D, coherence, MSI, LR/SC, or later-milestone functionality.

## Required context

Before editing, read:

- `AGENTS.md`
- `README.md`
- `docs/architecture.md`
- `docs/cache_architecture.md`
- `docs/interface_audit.md`
- `docs/module_hierarchy.md`
- `docs/memory_map.md`
- `docs/verification_plan.md`
- `docs/performance_plan.md`
- `docs/build_roadmap.md`
- `docs/source_manifest.md`
- `docs/risks_and_open_questions.md`
- `docs/build_reports/milestone_1_uncached_cluster.md`
- relevant ADRs under `docs/architecture_decisions/`
- the current Milestone 1 RTL and testbench interfaces

Inspect the current repository state before making changes.

Do not modify sibling repositories.

Use targeted searches and concise command output. Avoid rereading large files unnecessarily.

## Baseline architecture

The frozen L1I configuration is:

- one private L1I per core;
- capacity: 2 KiB;
- associativity: 2 ways;
- cache-block size: 16 bytes;
- sets: 64;
- words per cache block: 4;
- processor fetch width: 32 bits;
- blocking miss handling;
- one refill active per L1I;
- no write path;
- no coherence;
- no invalidation after reset;
- no self-modifying code support;
- one replacement bit per set;
- shared lower-level memory path remains globally serialized.

Assuming a 32-bit byte address:

- byte offset: bits `[1:0]`;
- word offset within block: bits `[3:2]`;
- set index: bits `[9:4]`;
- tag: bits `[31:10]`.

Verify these widths against the implemented system address width and document the exact result.

## Implementation scope

### 1. Implement a reusable L1I cache module

Create a synthesizable private instruction-cache module with:

- processor-side request/response interface compatible with the existing Sparrow-V IMEM adapter boundary;
- lower-level request/response interface compatible with the shared system request path;
- 2-way tag array;
- 2-way data array;
- valid metadata;
- one replacement bit per set;
- blocking refill controller;
- reset invalidation;
- aligned 16-byte cache-block refill;
- 32-bit instruction-word selection from the returned block.

The module should be parameterized where useful for:

- address width;
- data width;
- number of sets;
- number of ways;
- cache-block bytes.

Do not over-generalize beyond the tested 2-way, 16-byte-block baseline.

### 2. Preserve Sparrow-V fetch semantics

The L1I must preserve the existing core-side handshake exactly.

Requirements:

- fetch requests remain stable while stalled;
- a hit returns exactly one response;
- a miss stalls the core until refill completion;
- no stale or duplicate response;
- no response to a request that was not accepted;
- instruction address alignment behavior remains unchanged;
- reset behavior remains compatible with the core;
- existing control-flow redirect and stale-fetch behavior in imported Sparrow-V must not be broken.

Pay particular attention to whether Sparrow-V may change or cancel an instruction request during redirect or backpressure. Use the actual audited interface rather than assuming a simple always-stable request.

### 3. Refill behavior

On an L1I miss:

1. Capture the requested instruction address.
2. Derive the 16-byte aligned cache-block address.
3. Select a victim way.
4. Issue four lower-level 32-bit reads, or one internal block refill transaction if the existing lower-level interface is deliberately extended.
5. Store the full cache block.
6. Update tag and valid metadata.
7. Update replacement state.
8. Return the requested instruction word.
9. Resume normal hit operation.

Preferred baseline:

- retain the current 32-bit shared-memory transaction path;
- implement refill as four ordered word reads;
- do not add bursts;
- do not widen the global bus merely for this milestone.

If a small cache-facing refill interface is introduced, it must adapt cleanly onto the existing word-sized controller and remain compatible with later L1D use.

### 4. Replacement policy

Use one replacement bit per set.

Required semantics:

- on reset, replacement state is deterministic;
- when both ways are invalid, choose a deterministic invalid way;
- when one way is invalid, choose that way;
- when both are valid, choose the way indicated by the replacement bit;
- after a hit or refill, update the bit so the other way becomes the next victim.

Document the exact convention.

Do not claim true LRU if the implementation is only a one-bit pseudo-LRU approximation.

### 5. Four-core integration

Instantiate one L1I per core.

The architecture should become:

```text
Sparrow-V core IMEM
        |
Private L1I
        |
Per-core lower-level instruction request
        |
Existing local/global arbitration
        |
Shared memory controller
        |
Shared SRAM
```

DMEM must remain uncached and continue to use the Milestone 1 path unchanged.

The current shared arbitration and source tracking must continue to distinguish:

- four L1I refill requesters;
- four uncached DMEM requesters.

Do not collapse or rewrite working Milestone 1 boundaries unnecessarily.

### 6. Lower-level arbitration interaction

A cache miss may generate four sequential lower-level reads.

Requirements:

- each refill word is associated with the correct core and cache;
- no refill word is delivered to another core;
- the cache may release global arbitration between refill words if that matches the existing interface;
- no assumption of bus locking across all four refill words unless explicitly implemented and documented;
- interleaved refills from different cores must remain correct;
- DMEM traffic may contend with L1I refill traffic;
- fairness must remain bounded and tested.

A whole refill must not monopolize the global path unless there is a clear documented reason.

### 7. Cache maintenance and reset

Baseline behavior:

- all valid bits clear on reset;
- data and tag contents need not be zeroed if valid bits are clear;
- no software invalidate instruction;
- no runtime flush;
- no instruction/data coherence;
- no self-modifying code;
- program memory is treated as immutable after execution begins.

Document these limitations clearly.

### 8. Performance counters

Add per-core L1I counters for:

- accesses;
- hits;
- misses;
- refill words requested;
- refill cycles or miss-stall cycles where practical.

Counters may be internal RTL/testbench-visible signals in this milestone.

Do not require software-visible CSRs unless that infrastructure already exists cleanly.

The tests must validate counter consistency:

```text
accesses = hits + misses
```

for completed fetch accesses under the chosen counting convention.

## Explicit exclusions

Do not implement:

- L1D caches;
- write-back or write-allocate data behavior;
- MSI;
- coherence;
- snooping;
- cache-to-cache transfer;
- invalidations;
- LR.W or SC.W;
- atomics;
- MSHRs;
- hit-under-miss;
- multiple outstanding L1I misses;
- hardware prefetching;
- victim caches;
- instruction cache coherence;
- self-modifying code support;
- an L2 cache;
- burst transactions;
- multiple outstanding global requests;
- MESI;
- SparrowML execution;
- FPGA or ASIC physical evaluation.

Do not begin Milestone 3.

## Functional requirements

The implementation must demonstrate:

1. Four private L1I caches.
2. 2 KiB capacity per cache.
3. Two ways and 64 sets.
4. 16-byte cache blocks.
5. Correct hit behavior.
6. Correct four-word refill behavior.
7. Correct word selection within a cache block.
8. Correct tag comparison.
9. Correct conflict handling between two ways.
10. Deterministic replacement.
11. Correct reset invalidation.
12. Concurrent misses from multiple cores.
13. Interleaved L1I refills and uncached DMEM traffic.
14. Correct response routing.
15. No regression to Milestone 1 multicore software behavior.
16. Accurate L1I counters.

## Verification requirements

### Unit tests

Add focused L1I tests for:

- cold miss and refill;
- hit after refill;
- all four word offsets in one cache block;
- same-set different-tag access;
- both ways occupied;
- deterministic victim selection;
- replacement-bit update;
- invalid-way preference;
- reset invalidation;
- backpressure during refill;
- delayed lower-level responses;
- lower-level response stability;
- repeated access to one block;
- alternating access between two ways;
- third conflicting block causing replacement;
- no false hit on matching index but different tag;
- no response before full required data is available;
- counter correctness.

### Four-core integration tests

Test:

- simultaneous cold instruction-cache misses from all four cores;
- interleaved refill words;
- all four cores completing;
- one core repeatedly hitting while another refills;
- DMEM requests contending with L1I refill requests;
- correct per-core instruction stream;
- no cross-core refill corruption.

### Software/system tests

Run all Milestone 1 software tests through the new L1I path:

- hart ID and stack isolation;
- shared read-only data;
- partitioned shared writes;
- serialized memory stress;
- completion reporting.

Add at least one instruction-cache-focused bare-metal program with:

- loops that repeatedly execute from the same cache block;
- code spanning multiple cache blocks;
- two code regions mapping to the same set;
- function calls sufficient to exercise multiple instruction blocks.

The program must produce a deterministic result that proves correct execution after misses and replacements.

### Assertions

Add bounded assertions for:

- no cache hit from an invalid way;
- at most one hit way for a request;
- a returned hit word comes from the matched way and requested offset;
- refill address is cache-block aligned;
- refill word index remains within range;
- tag/valid update occurs only after successful refill completion;
- no processor response is emitted twice;
- no processor response occurs without a tracked request;
- one cache has at most one miss/refill active;
- lower-level responses are consumed only by the requesting cache;
- replacement chooses a valid legal way;
- reset clears all valid metadata before serving hits;
- accesses equal hits plus misses under the documented counting convention.

Use assertions compatible with the current Icarus-based flow.

### Regression preservation

All Milestone 1 tests must continue to pass.

## Documentation updates

Update:

- `README.md`
- `docs/architecture.md`
- `docs/cache_architecture.md`
- `docs/module_hierarchy.md`
- `docs/interface_audit.md`
- `docs/verification_plan.md`
- `docs/performance_plan.md`
- `docs/build_roadmap.md`
- `docs/source_manifest.md`
- `docs/risks_and_open_questions.md`

Create:

- `docs/build_reports/milestone_2_private_l1i.md`

The report must record:

- implemented cache geometry;
- address decomposition;
- replacement convention;
- refill sequence;
- lower-level interface behavior;
- arbitration interaction;
- counters;
- tests;
- measured hit/miss/refill results;
- known limitations;
- functionality deliberately absent.

Update:

- `reports/current_milestone_report.md`

Use this exact milestone name.

## Required commands

Provide and run:

```bash
make check
make docs-check
make sim-unit
make sim-l1i
make sim-cluster
make sim-multicore
make regress
git diff --check
git status --short
```

Target intent:

- `make sim-unit`: all focused unit tests, including Milestone 1 units.
- `make sim-l1i`: instruction-cache-specific unit and integration tests.
- `make sim-cluster`: four-core hardware integration.
- `make sim-multicore`: bare-metal multicore software tests through L1I.
- `make regress`: all Milestone 1 and Milestone 2 required tests.

Do not make `make check` run the full simulation regression.

## Completion gate

Milestone 2 is complete only when:

- each of the four cores has a private L1I;
- each L1I is 2 KiB, 2-way, 64-set, and uses 16-byte cache blocks;
- all caches are blocking and permit only one active refill each;
- all valid bits clear on reset;
- cold misses refill correctly;
- later accesses hit correctly;
- all four word offsets are verified;
- set conflicts and replacement are verified;
- simultaneous misses from all four cores are verified;
- interleaved refill traffic is correct;
- uncached DMEM traffic still works during L1I activity;
- all four real cores execute and complete;
- all Milestone 1 tests still pass;
- instruction-cache-focused software executes correctly;
- L1I counters are tested and internally consistent;
- all required assertions pass;
- required documentation matches implemented behavior;
- `make check` passes;
- `make docs-check` passes;
- `make sim-unit` passes;
- `make sim-l1i` passes;
- `make sim-cluster` passes;
- `make sim-multicore` passes;
- `make regress` passes;
- no L1D, coherence, LR/SC, L2, or Milestone 3 functionality has been added;
- `reports/current_milestone_report.md` identifies this milestone and contains `STATUS: COMPLETE`.

Use `STATUS: BLOCKED` only for a genuine external, architectural, or toolchain blocker that prevents further progress. If required work remains but can still be implemented, use `STATUS: IN_PROGRESS` and continue iterating.

Do not mark the milestone complete based only on compilation or one passing system test.

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

- number of L1I unit tests passed;
- number of cores completing;
- observed cache hits and misses;
- refill-word count;
- replacement scenarios tested;
- arbitration/contention scenarios tested;
- regression commands passed;
- any known Icarus warnings;
- remaining deliberate limitations.

Do not paste full source files or documentation into the final response.