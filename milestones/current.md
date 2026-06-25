# Milestone 5 — MSI Coherence Integration

## Status

READY

## Goal

Integrate snoopy MSI coherence into the four production private L1D caches using the completed Milestone 4 coherence transport.

At completion:

- all four L1D caches participate in coherence;
- cacheable shared writable memory behaves coherently;
- loads and stores observe the latest globally ordered value;
- modified-owner intervention works through the production caches;
- peer invalidations work;
- dirty evictions use the coherence transport;
- the previous uncached-only synchronization restriction is no longer required for ordinary shared data;
- all prior valid regressions continue to pass.

This milestone is limited to MSI coherence correctness.

Do not implement `LR.W`, `SC.W`, reservations, MESI, non-blocking caches, an L2, or later functionality.

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
- `docs/boot_and_runtime.md`
- `docs/verification_plan.md`
- `docs/performance_plan.md`
- `docs/build_roadmap.md`
- `docs/source_manifest.md`
- `docs/risks_and_open_questions.md`
- `docs/build_reports/milestone_1_uncached_cluster.md`
- `docs/build_reports/milestone_2_private_l1i.md`
- `docs/build_reports/milestone_3_private_noncoherent_l1d.md`
- `docs/build_reports/milestone_4_snoopy_transport.md`
- relevant ADRs under `docs/architecture_decisions/`
- current production L1D RTL
- current coherence transport RTL and fixture tests
- current shared memory, arbitration, runtime, and multicore tests

Inspect the present repository state before changing files.

Do not modify sibling repositories.

Use targeted searches and concise command output.

## Baseline coherence model

The production system uses:

- four private coherent L1D caches;
- private non-coherent L1I caches;
- snoopy MSI coherence;
- one globally ordered coherence transaction at a time;
- one shared round-robin coherence transport;
- one shared SRAM;
- write-back and write-allocate L1D behavior;
- 16-byte cache blocks;
- blocking caches;
- one active processor/cache transaction per L1D;
- no MSHRs;
- no multiple outstanding coherence requests;
- strongly ordered memory behavior.

The stable L1D coherence states are:

- `I`: Invalid
- `S`: Shared
- `M`: Modified

The MSI state must become the authoritative representation of validity and dirtiness.

Preferred representation:

- `I` means invalid;
- `S` means valid and clean;
- `M` means valid and dirty.

Do not retain independent `valid` and `dirty` metadata as competing architectural sources of truth.

Temporary internal bits are acceptable only where required for incomplete transactions and must be documented.

## Critical integration rule

Milestone 4 transport behavior is already verified independently.

Milestone 5 must connect the real L1D caches to that transport rather than recreating coherence behavior through a second path.

The production request flow should become equivalent to:

```text
Sparrow-V DMEM request
        |
Private coherent L1D
        |
Local hit or MSI coherence request
        |
Milestone 4 snoopy coherence transport
        |
Shared SRAM / peer intervention
```

The L1D caches must use the canonical command definitions and requester/snooper interfaces already established.

Do not duplicate command encodings or create a parallel bus.

## Stable and transient states

### Stable states

Implement:

- `I`
- `S`
- `M`

### Required transient conditions

The cache is blocking but still requires explicit transient states or equivalent tracked transaction phases.

At minimum support conditions equivalent to:

- `IS`: invalid block waiting for `BUS_RD` and refill;
- `IM`: invalid block waiting for `BUS_RDX` and refill;
- `SM`: shared block waiting for `BUS_UPGR`;
- `MI_WB`: modified victim waiting for writeback;
- clean refill/installation;
- modified-owner intervention response;
- snoop invalidation acknowledgement;
- processor-response completion.

Additional transient states may be used where implementation clarity requires them.

Do not collapse partial coherence transactions into ambiguous combinational conditions.

Document the exact state machine.

## Processor-triggered MSI behavior

### Load hit in `S`

- return the requested data;
- remain in `S`;
- update replacement state;
- increment load-hit counters.

### Load hit in `M`

- return the requested data;
- remain in `M`;
- update replacement state;
- increment load-hit counters.

### Load miss in `I`

1. Capture the processor request.
2. Select an invalid way if available, otherwise select a victim.
3. If the victim is in `M`, perform a full-block coherence `WRITEBACK`.
4. Issue `BUS_RD` for the requested block.
5. Accept data from modified-owner intervention or SRAM through the transport.
6. Install the block in `S`.
7. Return the requested word.
8. Update replacement state and counters.

Under MSI, a read miss installs in `S` even when no peer copy exists.

Do not implement `E`.

### Store hit in `M`

- merge enabled bytes locally;
- remain in `M`;
- complete without a coherence transaction;
- update replacement state;
- increment store-hit counters.

### Store hit in `S`

1. Capture the store.
2. Issue `BUS_UPGR`.
3. Wait for required peer acknowledgements.
4. Transition to `M`.
5. Merge enabled bytes.
6. Complete the processor request.

No data refill is needed because the local `S` copy already contains the block.

### Store miss in `I`

1. Capture address, write data, and byte enables.
2. Select a victim.
3. If the victim is in `M`, perform full-block `WRITEBACK`.
4. Issue `BUS_RDX`.
5. Wait for peer invalidation acknowledgements.
6. Receive authoritative block data from a modified owner or SRAM.
7. Install the block in `M`.
8. Merge the pending store.
9. Complete the processor request.

This is write-allocate behavior.

## Snoop-triggered MSI behavior

Each production L1D must inspect broadcast commands for the block address and respond through the Milestone 4 snooper interface.

The requesting cache must not act as its own peer snooper.

### Snoop `BUS_RD` while local state is `I`

- report no copy;
- provide no data;
- remain in `I`.

### Snoop `BUS_RD` while local state is `S`

- report shared copy present;
- provide no intervention data;
- remain in `S`.

### Snoop `BUS_RD` while local state is `M`

- report modified ownership;
- provide the full authoritative 16-byte block;
- wait for required intervention acceptance;
- transition from `M` to `S`;
- ensure SRAM receives the same block through the transport;
- clear modified ownership only after the intervention is safely accepted.

### Snoop `BUS_RDX` while local state is `I`

- report no copy;
- acknowledge as required;
- remain in `I`.

### Snoop `BUS_RDX` while local state is `S`

- report shared copy present;
- acknowledge invalidation;
- transition to `I`.

### Snoop `BUS_RDX` while local state is `M`

- report modified ownership;
- provide the full authoritative 16-byte block;
- acknowledge invalidation;
- transition to `I` only after intervention data is accepted safely;
- ensure SRAM receives the same intervention block.

### Snoop `BUS_UPGR` while local state is `I`

- acknowledge as required;
- remain in `I`.

### Snoop `BUS_UPGR` while local state is `S`

- acknowledge invalidation;
- transition to `I`.

### Snoop `BUS_UPGR` while local state is `M`

This is an illegal protocol condition under correct operation.

Requirements:

- assert or flag a protocol error;
- do not silently corrupt state;
- document the behavior.

## Local processor request versus snoop priority

Freeze and implement a deterministic conflict policy.

Preferred baseline:

- an incoming accepted snoop has priority over starting a new processor-side cache action;
- an already active local coherence transaction remains tracked until completion;
- processor requests stall while the cache is servicing a conflicting snoop;
- snoops to unrelated blocks may be serviced only if this can be done safely without violating the blocking-cache design;
- otherwise apply backpressure or delay response through the existing snooper protocol.

Do not claim general hit-under-snoop or concurrent lookup support unless explicitly implemented and verified.

The chosen policy must avoid deadlock between:

- a cache waiting for transport completion;
- the same cache being required to respond as a snooper;
- multiple caches issuing ownership requests.

Because only one global coherence transaction is active, reason carefully about whether a requesting cache can also have a separate local transient operation.

Document the final priority and backpressure rules.

## Replacement and eviction

The cache remains 2-way set associative with one replacement bit per set.

Victim selection remains:

1. choose an invalid way if one exists;
2. otherwise use the replacement bit.

Victim behavior:

- `I`: cannot be a valid resident victim;
- `S`: replace without writeback;
- `M`: issue full-block `WRITEBACK` before replacement.

A clean shared block must not write back.

A modified block must not be discarded without successful transport writeback.

## Dirty-data authority

When a block is in `M`:

- the L1D copy is authoritative;
- SRAM may be stale;
- no other L1D may contain the block in `S` or `M`.

When the `M` owner responds to `BUS_RD` or `BUS_RDX`:

- the owner supplies the authoritative block;
- the requester receives it;
- SRAM receives the identical block;
- state transition occurs only after safe data handoff.

When a modified block is evicted:

- use coherence `WRITEBACK`;
- SRAM receives all four words;
- completion occurs before replacement proceeds.

## Shared-memory behavior after MSI

Once MSI is correctly integrated, ordinary cacheable shared writable data may be used coherently.

However:

- uncached control/status apertures remain uncached;
- hart-ID MMIO remains uncached;
- simulation completion remains uncached;
- strongly ordered control communication may remain uncached where simpler;
- normal shared arrays, locks for future LR/SC, producer-consumer data, and false-sharing tests may use cacheable memory.

Do not remove uncached support.

Update software tests so coherent shared data is exercised directly.

## Cacheable and uncached address policy

Preserve the implemented Milestone 3 address decode unless a documented correction is required.

Requirements:

- cacheable SRAM accesses use MSI;
- uncached/MMIO accesses bypass coherence and remain globally serialized;
- uncached accesses do not allocate;
- uncached accesses do not change MSI metadata;
- coherence requests are not generated for uncached addresses;
- existing hart-ID and completion behavior remains correct.

Test cacheable and uncached traffic concurrently.

## Memory ordering

Preserve the strong-ordering baseline:

- processor memory operations complete in program order;
- one active L1D processor transaction per core;
- coherence transactions are globally serialized;
- store completion reflects successful ownership acquisition and local update;
- a later load/store cannot bypass an incomplete earlier operation.

Do not claim RVWMO validation.

## Counters

Update or add per-core L1D coherence counters for:

- accesses;
- loads;
- stores;
- load hits in `S`;
- load hits in `M`;
- store hits in `M`;
- store upgrades from `S`;
- load misses;
- store misses;
- `BUS_RD` requests;
- `BUS_RDX` requests;
- `BUS_UPGR` requests;
- writebacks;
- snoop hits in `S`;
- snoop hits in `M`;
- interventions supplied;
- invalidations received;
- downgrades `M → S`;
- ownership transfers `M → I`;
- uncached accesses;
- processor stall cycles due to coherence where practical.

Reuse Milestone 4 transport counters.

Document exact counting points.

At minimum verify consistency relationships such as:

```text
processor accesses = cacheable hits + cacheable misses + uncached accesses
```

under the chosen definitions.

## Explicit exclusions

Do not implement:

- MESI or `E` state;
- MOESI or `O` state;
- `LR.W`;
- `SC.W`;
- reservation tracking;
- atomic operations;
- MSHRs;
- hit-under-miss;
- non-blocking caches;
- multiple outstanding coherence transactions;
- store buffers;
- speculative loads;
- hardware prefetching;
- an L2 cache;
- directory coherence;
- crossbar or NoC;
- coherent L1I;
- self-modifying code;
- coherent DMA;
- SparrowML multicore integration;
- FPGA deployment;
- ASIC physical evaluation.

Do not begin Milestone 6.

## Functional requirements

The production system must demonstrate:

1. Four coherent private L1D caches.
2. MSI state per resident cache block.
3. `I`, `S`, and `M` as authoritative validity/dirty state.
4. Load hits in `S`.
5. Load hits in `M`.
6. Store hits in `M`.
7. `I → S` through `BUS_RD`.
8. `I → M` through `BUS_RDX`.
9. `S → M` through `BUS_UPGR`.
10. `M → S` on remote `BUS_RD`.
11. `M → I` on remote `BUS_RDX`.
12. `S → I` on remote `BUS_RDX`.
13. `S → I` on remote `BUS_UPGR`.
14. Modified-owner intervention through production L1D.
15. SRAM update with intervention data.
16. Dirty eviction through coherence `WRITEBACK`.
17. Clean shared eviction without writeback.
18. Correct byte, halfword, and word stores.
19. Correct shared writable communication.
20. Correct simultaneous requests and arbitration.
21. Continued private L1I operation.
22. Continued uncached/MMIO operation.
23. No simultaneous `M` owners.
24. No `S` copy while another cache holds `M`.
25. No lost or stale committed writes.
26. Accurate coherence counters.

## Verification requirements

Verification is the main deliverable of this milestone.

### MSI unit tests

Add focused tests covering every stable transition.

#### Processor-side transitions

- reset to `I`;
- load miss `I → S`;
- load hit in `S`;
- store miss `I → M`;
- store hit in `M`;
- store hit `S → M` through `BUS_UPGR`;
- modified victim writeback before replacement;
- shared victim replacement without writeback;
- byte store in `M`;
- halfword store in `M`;
- word store in `M`;
- write-allocate store miss;
- delayed coherence response;
- delayed acknowledgement;
- reset invalidation.

#### Snoop transitions

- `I + BUS_RD → I`;
- `S + BUS_RD → S`;
- `M + BUS_RD → S` with intervention;
- `I + BUS_RDX → I`;
- `S + BUS_RDX → I`;
- `M + BUS_RDX → I` with intervention;
- `I + BUS_UPGR → I`;
- `S + BUS_UPGR → I`;
- illegal `M + BUS_UPGR` detection.

### Directed four-core coherence tests

Add named scenarios for:

1. Core 0 reads a cold block.
2. Core 0 and Core 1 both read the same block.
3. Four cores read the same block.
4. Core 0 writes a cold block.
5. Core 0 writes, then Core 1 reads.
6. Core 0 writes, then Core 1 writes.
7. Core 0 and Core 1 share, then Core 1 upgrades.
8. Four readers share, then one writer invalidates the others.
9. Modified owner is remotely read.
10. Modified owner is remotely replaced by a writer.
11. Two cores repeatedly alternate writes to one block.
12. Dirty owner evicts a block.
13. Shared clean block is evicted.
14. Independent blocks remain independent.
15. Byte/halfword/word writes are remotely observed.
16. Concurrent requests from all four cores.
17. L1I refill traffic contends below coherence traffic.
18. Uncached/MMIO traffic contends below coherence traffic.

For every directed test, validate:

- returned data;
- final SRAM value where expected;
- each cache’s final MSI state;
- expected transport command sequence;
- no illegal ownership combination.

### Randomized coherence test

Create a randomized four-core coherence test using a software or testbench reference model.

Generate operations such as:

- aligned loads;
- byte, halfword, and word stores;
- repeated accesses to shared blocks;
- accesses to independent blocks;
- same-set conflicts;
- forced evictions;
- ownership ping-pong;
- uncached operations where useful.

Use constrained address ranges small enough to track all cache-block states.

The reference model must check:

- each completed load value;
- final architectural memory value;
- successful store ordering;
- ownership invariants;
- absence of lost writes.

Use deterministic seeds and report them.

Run enough seeds and operations to provide meaningful coverage without making the default regression excessively slow.

### Software and litmus tests

Adapt or add bare-metal tests for coherent shared writable memory.

Required programs:

#### Shared producer-consumer

- one core writes data into a cacheable shared block;
- publishes a flag through a safe ordered mechanism;
- another core reads the updated data;
- expected value must be observed.

Until LR/SC exists, use single-writer flags and deterministic ownership.

#### Shared writable array

- multiple cores read and write assigned or communicated cacheable blocks;
- at least one block changes ownership between cores;
- final values are checked.

#### Ownership ping-pong

- two cores alternately write a cacheable word using deterministic turn-taking;
- turn variable may remain uncached if needed;
- shared data word must be cacheable;
- verify repeated `M` ownership transfer.

#### False-sharing benchmark

- two or more cores update different words in the same 16-byte block;
- compare against updates to different blocks;
- verify correctness;
- record coherence transaction counts;
- do not require performance conclusions yet.

#### Shared read-mostly data

- all cores read common cacheable data;
- verify expected shared-state behavior and low write traffic.

### Existing regression preservation

All valid Milestone 1–4 tests must continue to pass.

Update Milestone 3 tests that intentionally demonstrated incoherence:

- preserve a historical or documentation-only non-coherence demonstration if useful;
- do not retain it as expected production behavior;
- replace production expectations with coherent results.

Do not weaken previous cache, memory, transport, or software checks.

## Coherence invariants and assertions

Add assertions or equivalent checked invariants for:

### Global ownership

For every tracked block in verification:

- at most one cache may hold `M`;
- if any cache holds `M`, every other cache must hold `I`;
- multiple `S` copies are allowed;
- `S` and `M` may not coexist for the same block.

### Local state correctness

- `I` cannot satisfy a processor hit;
- `S` cannot be locally modified without successful upgrade;
- a cache may complete a store only in `M`;
- modified data cannot be discarded;
- shared clean eviction causes no writeback;
- refill installation uses a legal target way;
- only valid stable states satisfy hits.

### Transaction correctness

- `BUS_RD` is used for read miss;
- `BUS_RDX` is used for write miss;
- `BUS_UPGR` is used for store hit in `S`;
- requester state transition occurs only after transport completion;
- invalidation acknowledgement is not sent before required local action;
- intervention data equals local modified block contents;
- state `M → S` or `M → I` occurs only after safe intervention acceptance;
- no stale SRAM data is selected over modified-owner data;
- processor response occurs exactly once;
- one local processor transaction is active at most;
- no second coherence request is issued before the first completes.

### Liveness

Using bounded assumptions compatible with fixed-latency simulation:

- an accepted local request eventually completes;
- an accepted coherence request eventually completes unless a deliberate timeout test is active;
- snoop response is produced within the supported bounded interval;
- no requester is permanently starved.

### Counters

- counter increments occur once per defined event;
- accesses reconcile with hits, misses, and uncached accesses;
- intervention count matches supplied modified-owner responses in directed tests.

Keep assertions compatible with Icarus.

## Coverage expectations

Track functional coverage manually or through counters for:

- every processor-triggered stable transition;
- every snoop-triggered stable transition;
- every coherence command;
- intervention from each of the four cores;
- invalidation of each of the four cores;
- two, three, and four shared copies;
- dirty eviction;
- clean eviction;
- byte, halfword, and word writes;
- same-set conflicts;
- ownership transfer;
- arbitration grant to each core;
- false sharing;
- uncached/coherent contention.

A formal coverage tool is not required.

Provide a concise coverage matrix in the Milestone 5 build report.

## Documentation updates

Update:

- `README.md`
- `docs/architecture.md`
- `docs/cache_architecture.md`
- `docs/coherence_protocol.md`
- `docs/bus_protocol.md`
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

- `docs/build_reports/milestone_5_msi_coherence.md`

The build report must record:

- production MSI state encoding;
- transient states;
- processor transition table;
- snoop transition table;
- local-versus-snoop priority;
- deadlock-avoidance reasoning;
- eviction and intervention behavior;
- cacheable/uncached policy;
- counters;
- directed tests;
- randomized test seeds and operation counts;
- software tests;
- invariant checks;
- coverage matrix;
- measured results;
- known limitations;
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
make sim-snoop-transport
make sim-msi
make sim-coherence-random
make sim-cluster
make sim-multicore
make regress
git diff --check
git status --short
```

Target intent:

- `make sim-unit`: all focused unit tests through Milestone 5.
- `make sim-l1i`: existing L1I regression.
- `make sim-l1d`: local cache behavior and MSI L1D tests.
- `make sim-snoop-transport`: independent Milestone 4 transport regression.
- `make sim-msi`: directed production coherence tests.
- `make sim-coherence-random`: deterministic randomized coherence/model test.
- `make sim-cluster`: four-core integrated hardware test.
- `make sim-multicore`: bare-metal coherent shared-memory software tests.
- `make regress`: complete regression through Milestone 5.

Do not make `make check` invoke the full simulation regression.

## Completion gate

Milestone 5 is complete only when all of the following are true:

- all four production L1D caches connect to the snoopy coherence transport;
- each resident block uses authoritative MSI state;
- `I`, `S`, and `M` behavior is implemented;
- all required transient states or equivalent transaction tracking are implemented;
- read miss `I → S` works;
- write miss `I → M` works;
- store upgrade `S → M` works;
- local load hits in `S` and `M` work;
- local store hit in `M` works;
- remote read causes `M → S` intervention;
- remote ownership request causes `M → I` intervention;
- `S → I` invalidation works for `BUS_RDX`;
- `S → I` invalidation works for `BUS_UPGR`;
- dirty eviction uses full-block `WRITEBACK`;
- clean shared eviction does not write back;
- modified-owner data reaches requester and SRAM identically;
- stale SRAM data is never selected when an `M` owner exists;
- no block has more than one `M` owner;
- no `S` copy coexists with `M`;
- cacheable shared writable software works correctly;
- ownership ping-pong works;
- false-sharing test remains correct and records coherence traffic;
- byte, halfword, and word remote visibility is verified;
- simultaneous four-core coherence requests are verified;
- randomized coherence tests pass for documented seeds;
- reference-model load checking passes;
- all required assertions and invariants pass;
- L1I and uncached/MMIO behavior remain correct;
- all prior valid regressions pass;
- counters are tested and consistent;
- required documentation matches implementation;
- `make check` passes;
- `make docs-check` passes;
- `make sim-unit` passes;
- `make sim-l1i` passes;
- `make sim-l1d` passes;
- `make sim-snoop-transport` passes;
- `make sim-msi` passes;
- `make sim-coherence-random` passes;
- `make sim-cluster` passes;
- `make sim-multicore` passes;
- `make regress` passes;
- no LR/SC, MESI, L2, non-blocking cache, or Milestone 6 functionality has been added;
- `reports/current_milestone_report.md` identifies this exact milestone and contains `STATUS: COMPLETE`.

Use `STATUS: BLOCKED` only for a genuine external, architectural, or toolchain blocker that prevents further progress.

If required work remains but can still be implemented, use `STATUS: IN_PROGRESS` and continue iterating.

Do not mark complete based only on directed tests. Randomized reference-model verification and software-level shared-memory tests are required.

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

- directed MSI scenarios passed;
- randomized seeds and operation counts;
- cores completing;
- `BUS_RD`, `BUS_RDX`, `BUS_UPGR`, and writeback counts;
- interventions and invalidations;
- final MSI state checks;
- byte/halfword/word remote visibility;
- ownership ping-pong iterations;
- false-sharing traffic comparison;
- regression commands passed;
- known Icarus warnings;
- remaining deliberate limitations.

Do not paste complete source files or documentation into the final response.