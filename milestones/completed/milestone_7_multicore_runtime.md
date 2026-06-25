# Milestone 7 — Multicore Runtime and Workloads

## Status

READY

## Goal

Build the production bare-metal multicore software environment for Sparrow-Cluster and use it to validate the completed four-core coherent hardware.

At completion, Sparrow-Cluster must support:

- all-core startup;
- hart-ID-based execution;
- per-core stacks;
- shared data initialization;
- C-callable `LR.W` / `SC.W` primitives;
- spinlocks;
- atomic counters;
- reusable barriers;
- producer-consumer communication;
- shared reductions;
- ownership-transfer workloads;
- false-sharing and padded-data benchmarks;
- one-, two-, and four-core execution;
- software-visible benchmark results and hardware counter collection.

This milestone is primarily a software/runtime and system-validation milestone.

Do not add major new microarchitecture.

SparrowML integration remains Milestone 8.

## Required context

Before editing, read:

- `AGENTS.md`
- `README.md`
- `docs/architecture.md`
- `docs/boot_and_runtime.md`
- `docs/lr_sc.md`
- `docs/memory_map.md`
- `docs/coherence_protocol.md`
- `docs/bus_protocol.md`
- `docs/cache_architecture.md`
- `docs/interface_audit.md`
- `docs/module_hierarchy.md`
- `docs/verification_plan.md`
- `docs/performance_plan.md`
- `docs/build_roadmap.md`
- `docs/source_manifest.md`
- `docs/risks_and_open_questions.md`
- all build reports through `docs/build_reports/milestone_6_lr_sc.md`
- relevant ADRs
- current bare-metal images and hand-encoded software
- imported Sparrow-V ISA and runtime support
- current program-image loading flow
- current system and multicore testbenches
- current cache, coherence, LR/SC, and transport counters

Inspect the current repository state before editing.

Do not modify sibling repositories.

Use targeted searches and concise command output.

## Primary milestone objective

Replace the current mostly directed or hand-encoded multicore software validation with a reusable bare-metal runtime and workload flow suitable for later SparrowML integration.

The runtime should be small, deterministic, understandable, and reproducible.

Preferred software stack:

```text
startup assembly
    |
linker script
    |
minimal runtime
    |
atomic and synchronization primitives
    |
multicore C workloads
    |
program-image generation
    |
Sparrow-Cluster simulation
```

Do not introduce an operating system, libc dependency, or large runtime framework.

## Toolchain audit

Before implementing the runtime, inspect the local environment and current repository support for:

- RISC-V GCC;
- Clang/LLVM RISC-V target support;
- assembler;
- linker;
- `objcopy`;
- `objdump`;
- ELF parsing;
- existing Sparrow-V software build scripts;
- existing hand-encoded image generation.

Use an available standard RISC-V bare-metal toolchain if practical.

Preferred options:

- `riscv32-unknown-elf-*`;
- another documented compatible RISC-V ELF toolchain;
- Clang/LLVM with explicit RV32 target and ISA flags.

If no suitable compiler is available:

- do not block immediately;
- implement a deterministic fallback using assembly and existing image-generation tooling;
- keep the runtime interfaces suitable for later C compilation;
- document the limitation precisely.

Do not add an external package manager or automatically install system software.

## ISA baseline for software

Compile or assemble only for features actually supported by Sparrow-V and Sparrow-Cluster.

Use an ISA equivalent to:

- RV32I;
- `LR.W` and `SC.W`;
- no other RV32A AMOs;
- no compressed instructions unless already supported;
- no floating point;
- no multiplication or division unless supported and explicitly verified.

Do not accidentally compile for full RV32A and emit unsupported AMOs.

Inspect final disassembly and fail the build if unsupported instructions appear.

## Runtime architecture

Create or complete a runtime structure similar to:

```text
sw/
├── runtime/
│   ├── start.S
│   ├── runtime.c
│   ├── atomic.S or atomic.h
│   ├── synchronization.c
│   ├── include/
│   └── README.md
├── linker/
│   └── sparrow_cluster.ld
├── tests/
├── workloads/
└── common/
```

Adapt names to existing conventions.

Do not create duplicate runtime implementations.

## Startup flow

Implement a production-quality bare-metal startup sequence.

Required behavior:

1. All four harts start at the reset vector.
2. Each hart reads its hart ID using the implemented cluster mechanism.
3. Each hart selects a separate stack.
4. Core 0 initializes:
   - `.data`;
   - `.bss`;
   - shared runtime state;
   - benchmark configuration.
5. Secondary harts wait safely for initialization completion.
6. All harts enter the selected workload.
7. Each hart records completion and status.
8. Core 0 or the testbench validates global completion.
9. The program terminates through the documented simulation-completion mechanism.

Use coherent atomics or a safe single-writer release protocol.

Do not rely on uninitialized shared values or simulator scheduling coincidences.

## Linker script

Create or finalize a linker script matching the implemented memory map.

It must define:

- reset and text region;
- read-only data;
- initialized data;
- BSS;
- shared data;
- per-core stack regions;
- optional per-core local data;
- result region;
- completion/status region where applicable.

Add linker assertions for:

- program image fits in SRAM;
- stack regions do not overlap;
- shared sections do not overlap stacks;
- alignment requirements;
- cache-block alignment of selected benchmark data.

Document exact symbols exported to the runtime.

## Hart IDs and core count

Provide runtime helpers for:

- current hart ID;
- configured active-core count;
- detecting whether a hart participates in the current workload.

Support benchmark runs using:

- one active core;
- two active cores;
- four active cores.

Inactive harts must enter a safe wait or completion state without corrupting workload results.

The hardware remains four-core; active-core count is a software benchmark parameter.

## Atomic primitives

Provide C-callable wrappers or inline functions for:

- `lr.w`;
- `sc.w`;
- atomic compare-and-retry loops;
- atomic increment;
- optional atomic fetch-add implemented using LR/SC;
- spinlock acquire;
- spinlock try-acquire where useful;
- spinlock release.

Do not emit unsupported AMO instructions.

All retry loops must have deterministic test bounds or timeout diagnostics in verification.

## Spinlock implementation

Implement a simple spinlock using LR/SC.

Requirements:

- lock value `0` means unlocked;
- nonzero means locked;
- acquisition retries until successful;
- release uses a coherent store under the strongly ordered baseline;
- mutual exclusion is verified;
- every hart makes progress under directed tests;
- contention and retry counts are measurable.

The implementation does not need sophisticated backoff initially.

Optional simple backoff may be added only if deterministic and documented.

## Reusable barrier

Implement a reusable barrier for up to four harts.

Preferred implementation:

- arrival counter;
- generation or sense value;
- LR/SC-protected update;
- local sense per hart or equivalent generation tracking.

Requirements:

- no hart leaves before all active harts arrive;
- supports multiple rounds;
- supports one, two, and four active harts;
- no reuse race between consecutive rounds;
- timeout diagnostics exist in tests.

Do not implement a one-shot barrier and describe it as reusable.

## Atomic counter

Implement an atomic shared counter using LR/SC.

Required test:

- each active hart increments the same counter a fixed number of times;
- final value equals:
  `active_harts × increments_per_hart`;
- record total LR attempts, SC attempts, successes, failures, and retries where observable.

## Runtime diagnostics

Provide a small result structure in shared memory containing at least:

- magic/version;
- workload ID;
- active-core count;
- per-hart status;
- per-hart result;
- per-hart cycle count if available;
- per-hart instruction count if available;
- total failures;
- timeout or error code;
- selected hardware-counter snapshots.

Keep the format stable and documented.

The testbench should decode this structure rather than relying only on `$display` text.

## Performance-counter access

Audit how existing hardware counters are exposed.

Preferred options:

1. Existing testbench-visible counters sampled by the system testbench.
2. Memory-mapped read-only counter aperture.
3. Minimal software-visible access added only if cleanly supported.

Do not perform invasive CSR work solely for this milestone.

Capture relevant metrics for workloads where practical:

- cycles;
- retired instructions;
- L1I accesses/hits/misses;
- L1D accesses/hits/misses;
- `BUS_RD`;
- `BUS_RDX`;
- `BUS_UPGR`;
- writebacks;
- interventions;
- invalidations;
- LR attempts;
- SC attempts;
- SC failures;
- bus occupancy;
- arbitration wait cycles.

Clearly distinguish hardware-measured counters from software-maintained counters.

## Required workloads

### Workload 1 — Runtime smoke test

Validate:

- hart IDs;
- separate stacks;
- startup ordering;
- `.data`;
- `.bss`;
- function calls;
- per-hart completion;
- one-, two-, and four-hart execution.

### Workload 2 — Atomic counter

Each active hart performs a fixed number of increments on one shared counter using LR/SC.

Verify exact final value.

Run with:

- one hart;
- two harts;
- four harts.

Record:

- attempts;
- successes;
- failures;
- retries;
- cycles where available.

### Workload 3 — Spinlock-protected critical section

Each hart repeatedly:

1. acquires a shared lock;
2. checks a mutual-exclusion guard;
3. updates shared protected state;
4. clears the guard;
5. releases the lock.

Verify:

- no mutual-exclusion violation;
- exact final state;
- all harts enter the critical section;
- no starvation in the directed run.

### Workload 4 — Reusable barrier

All active harts execute multiple barrier rounds.

Between rounds, each hart writes a round-specific value.

Verify:

- no hart observes incomplete round state;
- all rounds complete;
- one-, two-, and four-hart configurations pass.

### Workload 5 — Producer-consumer

Use at least two harts.

Producer:

- writes a cacheable shared payload;
- publishes readiness using coherent synchronization.

Consumer:

- waits;
- reads payload;
- verifies exact values;
- acknowledges consumption.

Run multiple iterations to exercise ownership transfer.

### Workload 6 — Shared reduction

Partition an input array among active harts.

Each hart:

- computes a private partial sum;
- synchronizes;
- contributes to a final result using either:
  - lock-protected accumulation; or
  - per-hart partials plus Core 0 reduction.

Provide both a low-coherence and a shared-accumulation version if practical.

Verify exact result.

### Workload 7 — Ownership ping-pong

Two harts alternately update one cacheable shared word or block using coherent synchronization.

Verify:

- exact sequence;
- repeated ownership transfer;
- expected final value;
- nonzero `BUS_RDX`, `BUS_UPGR`, intervention, or invalidation activity as appropriate.

Use enough iterations to produce measurable coherence traffic without making regression slow.

### Workload 8 — False sharing versus padded data

Create two equivalent workloads:

#### False-sharing version

Different harts update different words within the same 16-byte cache block.

#### Padded version

Each hart updates data in separate cache blocks.

Requirements:

- both produce correct final values;
- use identical logical work;
- record coherence transaction counts;
- compare cycles where available;
- do not overstate performance conclusions from simulation.

Report the measured difference in:

- invalidations;
- ownership transfers;
- `BUS_RDX`;
- `BUS_UPGR`;
- interventions;
- cycles where available.

### Workload 9 — Read-mostly shared data

All active harts repeatedly read common cacheable data.

Verify:

- correct results;
- shared copies;
- low ownership-transfer traffic;
- one-, two-, and four-hart behavior.

### Workload 10 — Mixed private/shared stress

Combine:

- private stack traffic;
- private array traffic;
- shared read-only data;
- lock-protected updates;
- barriers;
- uncached completion/status writes.

Run long enough to exercise the full hierarchy deterministically.

## Workload configuration

Provide a common configuration mechanism for:

- workload selection;
- active-core count;
- iteration count;
- timeout bound;
- deterministic seed where applicable.

This may be compile-time or image-generation-time configuration.

Avoid a complex command-line runtime parser.

## Bare-metal build flow

Add deterministic Make targets such as:

```text
make sw-build
make sw-disasm
make sw-images
make sim-runtime
make sim-lock
make sim-barrier
make sim-counter
make sim-workloads
```

Adapt names to repository conventions.

The build flow must:

- compile or assemble;
- link;
- produce ELF where applicable;
- generate memory image;
- produce disassembly;
- reject unsupported instructions;
- record toolchain version;
- avoid absolute paths;
- avoid committing large generated artifacts unless explicitly approved.

Generated artifacts should go to an ignored build directory.

## Unsupported-instruction checking

Add a deterministic check that disassembly does not contain unsupported instructions.

At minimum reject:

- unsupported AMOs other than `lr.w` and `sc.w`;
- compressed instructions if unsupported;
- multiplication/division if unsupported;
- floating-point instructions;
- privileged instructions not implemented.

Do not rely only on compiler flags.

## Verification requirements

### Runtime unit/focused tests

Verify:

- stack pointer per hart;
- `.data` initialization;
- `.bss` zeroing;
- secondary-hart release;
- active-hart filtering;
- completion reporting;
- timeout/error reporting;
- linker layout;
- result-structure decoding;
- unsupported-instruction detection.

### Atomic runtime tests

Verify:

- lock correctness;
- failed and successful SC retries;
- counter exactness;
- barrier reuse;
- no critical-section overlap;
- no early barrier exit;
- all harts make progress.

### Hardware/software integration

Verify that real programs execute through:

- private L1I;
- coherent private L1D;
- snoopy MSI transport;
- shared SRAM;
- LR/SC hardware.

Do not bypass the cache or coherence path for normal workload data.

### Regression preservation

All Milestone 1–6 tests must continue to pass.

Do not weaken existing coherence or atomic tests.

## Timeouts and deadlock diagnostics

Every multicore workload must have a bounded simulation timeout.

On timeout, report at least:

- workload;
- active-core count;
- per-hart PC where visible;
- per-hart completion state;
- lock/barrier state;
- relevant coherence-transport state;
- reservation-valid state where visible;
- last observed progress point.

Do not allow a hung test to consume unbounded runner time.

## Assertions and invariants

Add or preserve checks for:

- stack regions do not overlap;
- inactive harts do not modify active workload data;
- lock guard never exceeds one owner;
- protected critical section has at most one hart;
- atomic counter never decreases;
- barrier generation advances only after all active harts arrive;
- no hart exits a barrier generation early;
- final atomic-counter value is exact;
- every active hart eventually reports completion under bounded test assumptions;
- result structure contains valid magic and workload ID;
- software completion occurs only after required memory operations complete;
- existing MSI and LR/SC invariants remain true.

## Metrics and reporting

For each required workload, report where available:

- active cores;
- workload iterations;
- cycles;
- retired instructions;
- L1I hits/misses;
- L1D hits/misses;
- coherence command counts;
- invalidations;
- interventions;
- writebacks;
- LR attempts;
- SC attempts;
- SC failures;
- software retries;
- final result;
- pass/fail.

Provide one-, two-, and four-core results for:

- atomic counter;
- barrier;
- shared reduction;
- read-mostly workload;
- mixed workload.

Do not claim ideal scaling.

## Explicit exclusions

Do not implement:

- SparrowML execution;
- scheduler;
- operating system;
- interrupts;
- virtual memory;
- full libc;
- filesystem;
- dynamic allocation unless a tiny static allocator is genuinely needed;
- full RV32A AMOs;
- MESI;
- non-blocking caches;
- MSHRs;
- L2;
- directory coherence;
- coherent DMA;
- FPGA deployment;
- ASIC physical evaluation;
- speculative or out-of-order execution.

Do not begin Milestone 8.

## Functional requirements

The repository must demonstrate:

1. Reproducible bare-metal software build.
2. Startup assembly.
3. Correct linker script.
4. Four non-overlapping stacks.
5. `.data` initialization.
6. `.bss` clearing.
7. Hart-ID discovery.
8. One-, two-, and four-hart participation.
9. C-callable or assembly-callable LR/SC primitives.
10. Spinlock.
11. Atomic counter.
12. Reusable barrier.
13. Producer-consumer communication.
14. Shared reduction.
15. Ownership ping-pong.
16. False-sharing benchmark.
17. Padded comparison benchmark.
18. Read-mostly workload.
19. Mixed private/shared workload.
20. Deterministic completion reporting.
21. Timeout diagnostics.
22. Unsupported-instruction checking.
23. Workload metrics.
24. All previous hardware regressions preserved.

## Documentation updates

Update:

- `README.md`
- `docs/architecture.md`
- `docs/boot_and_runtime.md`
- `docs/lr_sc.md`
- `docs/memory_map.md`
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

- `docs/runtime.md`
- `docs/workloads.md`
- `docs/build_reports/milestone_7_multicore_runtime.md`

The build report must include:

- detected toolchain and versions;
- software ISA flags;
- startup flow;
- linker map;
- stack layout;
- runtime API;
- LR/SC wrappers;
- lock implementation;
- barrier algorithm;
- result structure;
- program-image flow;
- unsupported-instruction checker;
- required workload definitions;
- one-, two-, and four-core results;
- counter tables;
- false-sharing comparison;
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
make sw-check
make sw-build
make sw-disasm
make sim-unit
make sim-l1i
make sim-l1d
make sim-snoop-transport
make sim-msi
make sim-coherence-random
make sim-lrsc
make sim-atomic-random
make sim-runtime
make sim-counter
make sim-lock
make sim-barrier
make sim-workloads
make sim-cluster
make sim-multicore
make regress
git diff --check
git status --short
```

Target intent:

- `make sw-check`: validate toolchain, linker layout, and unsupported instructions.
- `make sw-build`: build all required runtime/workload binaries or images.
- `make sw-disasm`: produce inspectable disassembly.
- `make sim-runtime`: startup/runtime smoke tests.
- `make sim-counter`: one-, two-, and four-core atomic-counter tests.
- `make sim-lock`: spinlock and mutual-exclusion tests.
- `make sim-barrier`: reusable barrier tests.
- `make sim-workloads`: producer-consumer, reduction, ping-pong, false-sharing, read-mostly, and mixed workloads.
- `make regress`: complete regression through Milestone 7.

Do not make `make check` or `make sw-check` launch the full simulation regression.

## Completion gate

Milestone 7 is complete only when:

- a reproducible bare-metal software flow exists;
- the selected toolchain and ISA flags are documented;
- unsupported instructions are rejected;
- startup assembly works;
- the linker map matches implemented memory;
- stack regions are non-overlapping;
- `.data` and `.bss` initialization work;
- all harts read correct IDs;
- one-, two-, and four-hart configurations work;
- inactive harts remain safe;
- LR/SC runtime wrappers work;
- spinlock mutual exclusion is verified;
- every participating hart makes progress in lock tests;
- atomic counter reaches exact expected values;
- reusable barrier works across multiple rounds;
- producer-consumer communication is correct;
- shared reduction is correct;
- ownership ping-pong is correct;
- false-sharing and padded workloads both pass;
- coherence-traffic comparison is recorded;
- read-mostly workload passes;
- mixed private/shared workload passes;
- deterministic result structures are decoded and checked;
- bounded timeout diagnostics exist;
- relevant workload and hardware counters are recorded;
- all prior hardware and coherence regressions pass;
- documentation matches implementation;
- `make check` passes;
- `make docs-check` passes;
- `make sw-check` passes;
- `make sw-build` passes;
- `make sw-disasm` passes;
- `make sim-unit` passes;
- `make sim-l1i` passes;
- `make sim-l1d` passes;
- `make sim-snoop-transport` passes;
- `make sim-msi` passes;
- `make sim-coherence-random` passes;
- `make sim-lrsc` passes;
- `make sim-atomic-random` passes;
- `make sim-runtime` passes;
- `make sim-counter` passes;
- `make sim-lock` passes;
- `make sim-barrier` passes;
- `make sim-workloads` passes;
- `make sim-cluster` passes;
- `make sim-multicore` passes;
- `make regress` passes;
- no SparrowML, MESI, L2, non-blocking cache, FPGA, ASIC, or Milestone 8 functionality has been added;
- `reports/current_milestone_report.md` identifies this exact milestone and contains `STATUS: COMPLETE`.

Use `STATUS: BLOCKED` only for a genuine external or toolchain blocker that prevents further progress.

If no suitable C compiler is available but an assembly-based deterministic fallback can satisfy the workload requirements, continue with that fallback and document the limitation.

If required work remains but can still be implemented, use `STATUS: IN_PROGRESS` and continue iterating.

Do not mark complete based only on RTL-level LR/SC tests. Real multicore software workloads are required.

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

- toolchain used;
- one-, two-, and four-core workload results;
- counter iterations and final values;
- barrier rounds;
- lock acquisitions per hart;
- producer-consumer iterations;
- reduction expected and observed values;
- ownership ping-pong iterations;
- false-sharing versus padded coherence counts;
- relevant cycle counts;
- timeout coverage;
- regression commands passed;
- remaining deliberate limitations.

Do not paste complete source files or documentation.