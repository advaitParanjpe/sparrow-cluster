# Milestone 1 — Four-Core Uncached Shared-Memory Scaffold

## Status

READY

## Goal

Implement the first functional Sparrow-Cluster system using four real Sparrow-V cores connected through a deterministic serialized request path to one shared SRAM.

This milestone establishes the stable core-integration, arbitration, memory-controller, software-boot, and verification boundaries that later milestones will extend with private L1 caches and snoopy coherence.

At completion, all four cores must independently fetch and execute code, identify themselves, use separate stacks, access one shared SRAM, and report deterministic results.

## Required context

Before editing, read:

- `AGENTS.md`
- `README.md`
- `docs/architecture.md`
- `docs/interface_audit.md`
- `docs/reuse_plan.md`
- `docs/module_hierarchy.md`
- `docs/memory_map.md`
- `docs/boot_and_runtime.md`
- `docs/verification_plan.md`
- `docs/build_roadmap.md`
- `docs/risks_and_open_questions.md`
- relevant ADRs under `docs/architecture_decisions/`

Inspect the existing repository state before changing files.

Read the sibling `../sparrow-v` and `../sparrow-ml` repositories only as needed for source audit and reuse. Do not modify either sibling repository.

Use targeted searches and line ranges. Avoid repeatedly reading large files or emitting large command outputs.

## Implementation scope

### 1. Resolve Sparrow-V source integration

Select and implement a deterministic, repository-local integration method for the required Sparrow-V RTL and software support.

Preferred approach:

- copy only the reviewed files required by Sparrow-Cluster;
- use a deterministic import or synchronization script;
- record source paths and source Git revision where available;
- keep normal simulation independent of absolute sibling-directory paths;
- do not copy the complete Sparrow-V repository;
- do not use a Git submodule.

Document:

- imported files;
- original paths;
- purpose of each imported file;
- provenance or revision;
- future synchronization procedure;
- any intentional cluster-specific adaptations.

Preserve existing Sparrow-V behavior unless a documented cluster integration change is required.

### 2. Implement hart identification

Inspect the current Sparrow-V decoder, CSR path, parameters, and extension hooks.

Implement the smallest clean mechanism through which software can read a unique hart ID from `0` through `3`.

Preferred approach:

- a read-only `mhartid`-style CSR or compatible existing CSR hook;
- each core instance receives its hart ID as a parameter or core-local input.

If this is disproportionately invasive, use the cleanest core-local alternative and document why.

Add focused tests proving all four IDs are unique and correct.

### 3. Freeze SRAM size and memory map

Inspect:

- current Sparrow-V linker scripts;
- reset and boot addresses;
- program and data placement;
- representative binary sizes;
- relevant SparrowML package sizes.

Choose a default shared SRAM capacity with clear headroom and keep it parameterized.

A 256 KiB default may be used only if supported by the audit.

Freeze and document:

- reset/program region;
- initialized data and BSS;
- shared data;
- four non-overlapping stack regions;
- synchronization and initialization flags;
- per-core result and completion areas;
- control/status and simulation completion locations, if needed;
- invalid and unmapped address behavior.

Do not introduce address ranges that conflict with existing Sparrow-V behavior without documenting the migration.

### 4. Implement stable system boundaries

Use a structure equivalent to:

```text
Four Sparrow-V cores
        |
Per-core IMEM and DMEM adapters
        |
Per-core system request ports
        |
Shared round-robin transaction arbiter
        |
Shared memory controller
        |
Shared SRAM
```

These interfaces must be suitable for later insertion of:

- private L1I caches;
- private coherent L1D caches;
- the snoopy coherence bus.

Do not create a temporary four-way SRAM multiplexer that must be discarded in later milestones.

### 5. Per-core request handling

Preserve the actual Sparrow-V IMEM and DMEM handshake semantics established in the interface audit.

Requirements:

- request fields remain stable while stalled;
- responses are delivered only to the originating core and port;
- no request is completed more than once;
- no response is emitted without an active request;
- accepted requests are associated with their source until completion;
- address, write data, byte enables, operation type, core ID, and port ID are tracked;
- the system supports Sparrow-V’s existing instruction and data error behavior;
- only one global memory transaction is active at a time.

Freeze and document the policy for simultaneous IMEM and DMEM requests from one core.

Use a simple deterministic policy that cannot permanently prevent instruction progress. Local round-robin is preferred unless the existing pipeline semantics make another policy cleaner.

### 6. Shared arbitration

Implement deterministic round-robin arbitration across the core request sources.

Requirements:

- starvation-free under continuous requests;
- priority rotates after completed grants;
- an active transaction retains ownership until completion;
- request source is recorded explicitly;
- reset behavior is deterministic;
- simultaneous requests are tested;
- instruction and data source identity is preserved.

Do not implement split transactions or multiple global outstanding transactions.

### 7. Shared memory controller

Implement one controller supporting:

- one active request;
- fixed parameterized read latency;
- fixed parameterized write latency;
- word reads and writes;
- byte write enables;
- explicit completion;
- invalid-address response consistent with Sparrow-V semantics;
- deterministic reset behavior;
- future cache-block-compatible interface boundaries where practical.

Do not implement bursts.

### 8. Shared SRAM

Implement one shared SRAM with:

- parameterized capacity;
- byte write enables;
- deterministic simulation initialization;
- program-image loading;
- fixed-latency operation through the memory controller;
- synthesizable organization where practical;
- no duplicate simulation and synthesis sources unless needed and documented.

Use one SRAM rather than separate instruction and data memories.

### 9. Multicore boot and runtime

Use the approved all-cores-start-together model unless direct evidence shows that a Core-0-release model is materially less invasive.

Required flow:

1. All four cores start from the reset vector.
2. Each core reads its hart ID.
3. Each selects a distinct stack.
4. Exactly one core initializes shared state.
5. Secondary cores poll a single-writer release flag.
6. All cores execute the selected test workload.
7. Each writes results and completion to a distinct location.
8. Core 0 or the testbench validates aggregate completion.

Because `LR.W` and `SC.W` do not exist yet:

- do not implement spinlocks;
- do not use a racy shared read-modify-write counter;
- use single-writer flags, distinct result locations, static partitioning, and deterministic phase sequencing.

Clearly mark this as temporary pre-atomic runtime support.

### 10. Error behavior

Preserve existing Sparrow-V semantics.

Test and document:

- invalid instruction address;
- invalid data load;
- invalid data store;
- memory-controller error response;
- resulting core-visible behavior.

Do not invent a new trap or exception model.

## Explicit exclusions

Do not implement:

- L1 instruction caches;
- L1 data caches;
- cache tags, data arrays, or replacement logic;
- MSI states or transient coherence states;
- snooping;
- cache-to-cache transfer;
- invalidations;
- `LR.W` or `SC.W`;
- atomic locks or atomic counters;
- non-blocking caches;
- MSHRs;
- multiple outstanding global requests;
- an L2 cache;
- MESI;
- directory coherence;
- crossbar or NoC functionality;
- SparrowML workload execution;
- FPGA deployment;
- OpenLane or physical-design evaluation.

Do not start Milestone 2.

## Functional requirements

The implemented system must demonstrate:

1. Four actual Sparrow-V core instances.
2. Hart IDs `0`, `1`, `2`, and `3`.
3. Four non-overlapping stacks.
4. Instruction fetches from shared SRAM.
5. Data loads and stores to shared SRAM.
6. One globally serialized transaction path.
7. Deterministic arbitration.
8. Correct source tracking and response routing.
9. Program-image loading.
10. Per-core result and completion reporting.
11. Safe shared initialization without atomics.
12. Documented invalid-access behavior.
13. Stable integration interfaces suitable for later cache insertion.

The number of cores may be parameterized, but only the four-core baseline must be supported and verified.

## Required software tests

### Test 1 — Hart ID and stack isolation

Each core must:

- read its own hart ID;
- exercise local stack variables or function calls;
- write a unique signature to its result slot;
- report completion.

Verify:

- observed IDs are exactly `0`, `1`, `2`, and `3`;
- signatures are correct;
- stack ranges do not overlap;
- all four cores complete.

### Test 2 — Shared read-only data

Core 0 initializes shared values and publishes a release flag.

Each core:

- waits safely for initialization;
- reads the common data;
- computes a hart-specific checksum;
- stores the result in its own result slot.

Verify all expected checksums.

### Test 3 — Partitioned shared-memory writes

Each core writes only to a statically assigned region of a shared array.

Verify:

- every region contains the correct values;
- no core corrupts another core’s partition;
- all writes route through the shared controller.

### Test 4 — Serialized memory stress

Create deterministic instruction and data traffic from all four cores.

Exercise:

- simultaneous core requests;
- repeated arbitration;
- reads;
- full-word writes;
- partial writes where currently supported;
- long enough operation to rotate arbitration repeatedly.

Verify correct completion and final contents.

### Test 5 — Invalid access behavior

Exercise at least one invalid or unmapped request consistent with current Sparrow-V behavior.

If a software test cannot continue after the event, test it at adapter, controller, or system-testbench level.

## Verification requirements

Add focused tests for:

- local IMEM/DMEM selection;
- round-robin arbitration;
- continuous simultaneous requests;
- source capture;
- response routing;
- byte write enables;
- fixed read latency;
- fixed write latency;
- held request stability under backpressure;
- reset during idle;
- reset state of pending transaction metadata;
- no duplicate response;
- no response to the wrong core;
- no response to the wrong IMEM/DMEM port;
- unique hart IDs;
- program loading;
- multicore completion.

Add bounded assertions for:

- at most one global transaction active;
- only the selected source reaches the controller;
- recorded response source matches the accepted request;
- request metadata remains stable while waiting;
- every accepted request completes exactly once within a valid fixed bound;
- no completion occurs without an active transaction;
- arbitration priority advances correctly;
- continuously requesting sources are not starved within a valid bounded interval;
- hart IDs are unique and in range;
- response routing is one-hot;
- writes modify only enabled bytes.

Use the repository’s existing proven simulation approach, preferably Icarus Verilog where compatible.

Maintain a clear separation between:

- synthesizable RTL;
- testbench code;
- assertions;
- software;
- generated program images;
- reports.

## Documentation updates

Update canonical documentation to match implemented reality:

- `README.md`
- `docs/architecture.md`
- `docs/interface_audit.md`
- `docs/reuse_plan.md`
- `docs/module_hierarchy.md`
- `docs/memory_map.md`
- `docs/boot_and_runtime.md`
- `docs/verification_plan.md`
- `docs/build_roadmap.md`
- `docs/source_manifest.md`
- `docs/risks_and_open_questions.md`

Create:

- `docs/build_reports/milestone_1_uncached_cluster.md`

The build report must record:

- Sparrow-V source integration method and provenance;
- imported files;
- hart-ID implementation;
- default SRAM size;
- read and write latencies;
- final memory map;
- stack layout;
- local IMEM/DMEM policy;
- global arbitration structure;
- tests run;
- measured outcomes;
- known limitations;
- functionality deliberately absent.

Remove resolved high-impact issues from the open-questions list or clearly mark them resolved with links to canonical documentation.

Update the active milestone report at:

- `reports/current_milestone_report.md`

The report must identify this exact milestone and use the standard completion format.

## Required commands

Provide and run these targets:

```bash
make check
make docs-check
make sim-unit
make sim-cluster
make sim-multicore
make regress
```

Target intent:

- `make check`: fast deterministic repository checks.
- `make docs-check`: documentation validation.
- `make sim-unit`: focused arbiter, adapter, controller, SRAM, and hart-ID tests.
- `make sim-cluster`: four-core system integration test.
- `make sim-multicore`: bare-metal multicore software tests.
- `make regress`: all required Milestone 1 simulations and checks.

Follow existing Sparrow-V Make and simulation conventions where useful.

Also run:

```bash
git diff --check
git status --short
```

Run a targeted Sparrow-V compatibility regression if the imported or adapted core files could have changed existing core behavior.

## Completion gate

Milestone 1 is complete only when all of the following are true:

- Four real Sparrow-V cores are instantiated.
- All four cores fetch and execute code.
- Hart IDs `0`, `1`, `2`, and `3` are observed and tested.
- Every core uses a separate non-overlapping stack.
- IMEM and DMEM requests use documented stable adapters.
- All system requests reach one shared controller and one shared SRAM.
- Only one global transaction is active at a time.
- Arbitration is deterministic and tested under simultaneous requests.
- Responses return to the correct core and correct port.
- Byte enables and fixed SRAM latency are tested.
- Safe pre-atomic initialization and synchronization work.
- All required software tests pass.
- Invalid-access behavior is tested and documented.
- The repository is reproducible without absolute local source paths.
- Required documentation reflects the implementation.
- `make check` passes.
- `make docs-check` passes.
- `make sim-unit` passes.
- `make sim-cluster` passes.
- `make sim-multicore` passes.
- `make regress` passes.
- No cache, coherence, LR/SC, L2, or Milestone 2 functionality has been implemented.
- `reports/current_milestone_report.md` identifies this milestone and contains `STATUS: COMPLETE`.

Use `STATUS: BLOCKED` only for a genuine external, architectural, or toolchain blocker that prevents further progress. If required work remains but can still be implemented, use `STATUS: IN_PROGRESS` and continue iterating.

If a genuine architectural or toolchain blocker prevents completion, document it precisely and set the report to `STATUS: BLOCKED`.

Do not mark the milestone complete based only on compilation or partial test success.

## Completion report

Use this exact structure in `reports/current_milestone_report.md` and in the final Codex response:

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

Include concrete results:

- number of cores completing;
- hart IDs observed;
- selected SRAM size;
- configured SRAM latencies;
- arbitration scenarios tested;
- software tests passed;
- unit and system test counts where available;
- Sparrow-V source provenance;
- remaining limitations.

Do not paste complete source files or complete documentation into the final response.