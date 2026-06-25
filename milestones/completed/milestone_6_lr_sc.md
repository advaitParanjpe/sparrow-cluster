# Milestone 6 — Minimal LR.W / SC.W Atomic Synchronization

## Status

READY

## Goal

Implement a minimal coherent `LR.W` / `SC.W` pair for Sparrow-Cluster.

At completion:

- each core can execute `LR.W` and `SC.W`;
- each core tracks one reservation;
- reservations use 16-byte cache-block granularity;
- `SC.W` succeeds only when the reservation remains valid;
- successful `SC.W` performs one coherent word store and returns `0`;
- failed `SC.W` performs no store and returns nonzero;
- all `SC.W` attempts clear the reservation;
- remote ownership acquisition, invalidation, eviction, and reset clear relevant reservations;
- bare-metal spinlocks, barriers, and atomic counters work across all four cores;
- all Milestone 1–5 regressions remain valid.

This milestone implements only the minimum atomic functionality required for synchronization.

Do not implement the full RV32A extension.

## Required context

Before editing, read:

- `AGENTS.md`
- `README.md`
- `docs/architecture.md`
- `docs/cache_architecture.md`
- `docs/coherence_protocol.md`
- `docs/bus_protocol.md`
- `docs/lr_sc.md`
- `docs/boot_and_runtime.md`
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
- `docs/build_reports/milestone_4_snoopy_transport.md`
- `docs/build_reports/milestone_5_msi_coherence.md`
- relevant ADRs under `docs/architecture_decisions/`
- imported Sparrow-V decoder, execute, retirement, and DMEM-interface RTL
- production coherent L1D RTL
- coherence transport RTL
- current bare-metal runtime and multicore tests

Inspect the present repository state before making changes.

Do not modify sibling repositories.

Use targeted searches and concise command output.

## Baseline atomic model

Implement only:

- `LR.W`
- `SC.W`

Each core has:

- one reservation-valid bit;
- one reserved 16-byte cache-block address.

Reservation granularity is one complete cache block, not one word.

This conservative granularity means a write to any word within the reserved block may invalidate the reservation.

That behavior is acceptable and must be documented.

## ISA and encoding

Use the standard RISC-V RV32A encodings for:

- `LR.W`
- `SC.W`

Inspect the existing Sparrow-V decoder and instruction representation before implementing.

Required behavior:

### `LR.W rd, (rs1)`

- address comes from `rs1`;
- `rs2` must be zero as required by the standard encoding;
- performs a coherent aligned 32-bit load;
- writes the loaded word to `rd`;
- creates or replaces the core’s reservation for the containing 16-byte cache block.

### `SC.W rd, rs2, (rs1)`

- address comes from `rs1`;
- store data comes from `rs2`;
- checks the reservation;
- on success:
  - performs one coherent 32-bit store;
  - writes `0` to `rd`;
- on failure:
  - performs no store;
  - writes a nonzero value, preferably `1`, to `rd`;
- clears the reservation regardless of success or failure.

Do not implement:

- `AMOSWAP`;
- `AMOADD`;
- other AMO instructions;
- `.D` variants;
- acquire/release ordering optimizations beyond the strongly ordered baseline.

The `aq` and `rl` bits may be accepted but do not require additional behavior because the system is already strongly ordered. Document this explicitly.

## Alignment and error behavior

`LR.W` and `SC.W` require naturally aligned word addresses.

Preserve Sparrow-V’s existing misalignment behavior.

Requirements:

- misaligned `LR.W` must not create a reservation;
- misaligned `SC.W` must not perform a store;
- misaligned `SC.W` must clear any existing reservation if it reaches SC execution;
- invalid or unmapped behavior must remain consistent with existing Sparrow-V and memory-interface semantics;
- do not invent a new trap model.

Document the exact observed behavior.

## Core pipeline integration

Integrate `LR.W` and `SC.W` into the existing Sparrow-V core with minimal disruption.

Required integration points include:

- decode;
- operand selection;
- memory-operation classification;
- DMEM request generation;
- response handling;
- destination-register writeback;
- retirement or trace reporting where applicable;
- existing stall and backpressure logic.

Preserve all existing scalar behavior.

Do not fork the core into a separate atomic-only implementation unless absolutely necessary.

Any imported Sparrow-V file modified in Sparrow-Cluster must remain clearly provenance-tracked.

## Core-to-L1D atomic interface

Extend the core-to-L1D request interface with explicit atomic intent.

Preferred request metadata:

- normal load;
- normal store;
- `LR.W`;
- `SC.W`.

Do not infer `SC.W` solely from ordinary store fields outside the core.

The L1D must return enough information for the core to distinguish:

- load data;
- normal store completion;
- successful `SC.W`;
- failed `SC.W`.

Keep the interface compact and documented.

## Reservation storage

Each core or its private L1D must maintain:

- `reservation_valid`;
- `reservation_block_addr`.

Preferred ownership:

- reservation tracking should live with the private coherent L1D because snoop invalidations and evictions are visible there;
- the core should issue atomic operation type and receive success/failure.

If another location is cleaner, document why and ensure all invalidation events are available there.

The reserved address must be the 16-byte-aligned cache-block address.

Only one reservation exists per core.

A new `LR.W` replaces any previous reservation.

## LR.W behavior

For a valid aligned cacheable address:

1. Perform a normal coherent word load.
2. Complete all required MSI activity.
3. Return the loaded word to the core.
4. Set:
   - reservation valid;
   - reservation block address.
5. Retire the instruction.

The reservation must be created only after the coherent load completes successfully.

`LR.W` may hit in `S` or `M`, or miss and issue `BUS_RD`.

`LR.W` must not require `M` ownership.

For uncached or MMIO addresses:

- preferred baseline is to reject atomic reservation behavior;
- do not create a reservation;
- either follow documented unsupported/error behavior or fail conservatively;
- do not claim atomicity for uncached MMIO.

Document and test the chosen behavior.

## SC.W success conditions

`SC.W` succeeds only when all of the following are true:

- reservation is valid;
- requested block address matches the reserved block address;
- address is aligned;
- target is a supported cacheable address;
- ownership required for the store is acquired coherently;
- no invalidating event clears the reservation before the atomic store commits.

A successful `SC.W` must:

1. obtain or already hold `M`;
2. perform the word store exactly once;
3. return `0`;
4. clear the reservation;
5. retire only after the store is committed locally under MSI ownership.

## SC.W failure behavior

`SC.W` must fail when:

- reservation is invalid;
- reserved block does not match;
- reservation was cleared by remote ownership acquisition;
- reservation was cleared by snoop invalidation;
- reservation was cleared by local eviction;
- address is unsupported for atomic use;
- another defined failure condition occurs.

On failure:

- do not issue a coherence ownership request solely for the failed store;
- do not change cache data;
- do not change SRAM;
- return `1` or another documented nonzero value;
- clear the reservation;
- retire normally unless existing alignment/error behavior prevents it.

A failed `SC.W` must have no memory side effect.

## Reservation-clearing events

Clear the reservation on:

1. Any `SC.W` attempt, success or failure.
2. Remote `BUS_RDX` for the reserved block.
3. Remote `BUS_UPGR` for the reserved block.
4. Any snoop event that invalidates the reserved local block.
5. Local eviction of the reserved block.
6. Local replacement of the reserved block.
7. Reset.
8. A new `LR.W`, which replaces the old reservation.
9. Misaligned or unsupported `SC.W`, if it reaches SC execution.
10. Any local event that makes the reserved block no longer resident or no longer safely reservable.

For `BUS_RD`:

- a remote read does not necessarily clear the reservation if the local block remains valid;
- preserve the reservation across `M → S` downgrade only if the design can justify that the reservation remains valid;
- otherwise clear conservatively and document the choice.

Preferred conservative baseline:

- clear the reservation on any snoop hit to the reserved block that changes local MSI state;
- do not clear on a snoop miss to another block.

## Reservation versus cache residency

Freeze and document whether the reservation requires the block to remain resident.

Preferred baseline:

- reservation is valid only while the reserved block remains resident in the local L1D;
- eviction or replacement clears it;
- invalidation clears it;
- a reservation does not survive cache loss.

This is conservative and straightforward to verify.

## Atomicity and coherence ordering

Because the system has:

- blocking caches;
- one active processor memory transaction per core;
- one globally ordered coherence transaction at a time;
- strongly ordered memory behavior;

the successful `SC.W` store must appear as one globally ordered coherent ownership operation plus one local store.

Requirements:

- no other core may obtain `M` for the same block between final reservation validation and the successful store commit;
- reservation validation and store completion must be tied to the same blocked L1D transaction;
- do not validate in the core and later perform an unrelated normal store;
- do not expose a race window between successful validation and data update.

The L1D should make the final SC success decision.

## Interaction with MSI states

### LR.W in `I`

- issue `BUS_RD`;
- install in `S`;
- return data;
- set reservation.

### LR.W in `S`

- return data;
- remain `S`;
- set reservation.

### LR.W in `M`

- return data;
- remain `M`;
- set reservation.

### SC.W with valid reservation and local `M`

- perform store locally;
- remain `M`;
- return success;
- clear reservation.

### SC.W with valid reservation and local `S`

- issue `BUS_UPGR`;
- wait for acknowledgements;
- transition to `M`;
- revalidate reservation at the defined commit point;
- perform store;
- return success;
- clear reservation.

### SC.W with valid reservation and local `I`

Preferred baseline:

- fail conservatively because reservation should have been cleared when the block became invalid.

Do not silently reacquire with `BUS_RDX` and claim success unless the reservation semantics are carefully proven and documented.

### SC.W with invalid or mismatched reservation

- fail immediately;
- no coherence transaction;
- no store;
- clear reservation.

## Snoop interaction

When a snoop targets a reserved block:

### `BUS_RD`

- service normal MSI behavior;
- if local state changes `M → S`, apply the documented conservative reservation policy;
- preferred baseline: clear reservation on the downgrade.

### `BUS_RDX`

- clear reservation;
- service invalidation/intervention;
- `SC.W` must subsequently fail.

### `BUS_UPGR`

- clear reservation;
- service invalidation;
- `SC.W` must subsequently fail.

A snoop to another block must not clear the reservation.

## Uncached and MMIO policy

Do not support atomic reservations for:

- hart-ID aperture;
- control/status registers;
- simulation completion;
- uncached synchronization apertures;
- other MMIO.

Preferred behavior:

- `LR.W` to uncached/MMIO does not establish a reservation;
- `SC.W` to uncached/MMIO fails with no store;
- normal uncached loads/stores remain unchanged.

Document and test this behavior.

## Runtime support

Add a minimal bare-metal atomic runtime providing:

- `lr.w` wrapper;
- `sc.w` wrapper;
- spinlock acquire;
- spinlock release;
- reusable barrier;
- atomic increment;
- optional compare-and-retry helper.

Use standard LR/SC loops.

Example conceptual lock acquisition:

```text
retry:
    lr.w    old, (lock)
    bnez    old, retry
    li      new, 1
    sc.w    status, new, (lock)
    bnez    status, retry
```

Lock release may use a normal coherent store of zero under the strongly ordered baseline.

Do not implement a scheduler or operating system.

## Required software tests

### Test 1 — Basic LR success

- Core 0 executes `LR.W` on a cacheable word.
- No interfering core accesses the block.
- Core 0 executes `SC.W`.
- `SC.W` returns `0`.
- Stored value is observed.

### Test 2 — SC without LR

- Execute `SC.W` without a valid reservation.
- It must return nonzero.
- Memory must remain unchanged.

### Test 3 — Address mismatch

- `LR.W` one block.
- `SC.W` a different block.
- `SC.W` fails.
- Neither target is incorrectly modified.

### Test 4 — Remote invalidation failure

- Core 0 executes `LR.W`.
- Core 1 writes the reserved block and obtains ownership.
- Core 0 executes `SC.W`.
- It must fail.
- Core 1’s value remains authoritative.

### Test 5 — Remote upgrade failure

- Core 0 and Core 1 share a block.
- Core 0 executes `LR.W`.
- Core 1 upgrades and writes.
- Core 0’s `SC.W` fails.

### Test 6 — Eviction failure

- Core executes `LR.W`.
- Force local same-set replacement of the reserved block.
- `SC.W` fails.
- No unintended write occurs.

### Test 7 — Reservation replacement

- Execute `LR.W` on block A.
- Execute `LR.W` on block B.
- `SC.W` to A fails.
- `SC.W` to B follows the new reservation semantics.

### Test 8 — SC clears reservation

- Perform successful `LR.W`/`SC.W`.
- Execute a second `SC.W` without another `LR.W`.
- The second `SC.W` fails.

Also test failed `SC.W` followed by another `SC.W`.

### Test 9 — Byte-block granularity

- Execute `LR.W` on one word.
- Another core writes a different word in the same 16-byte block.
- `SC.W` must fail.

This confirms conservative cache-block-granularity reservations.

### Test 10 — Spinlock

All four cores repeatedly acquire one shared lock, update protected shared state, and release the lock.

Verify:

- mutual exclusion;
- final shared state;
- all four cores make progress;
- no lost updates.

### Test 11 — Atomic counter

All four cores increment one shared counter using LR/SC loops.

Use a deterministic iteration count.

Verify the exact final value.

### Test 12 — Barrier

All four cores enter a reusable barrier implemented with LR/SC-protected state.

Verify:

- no core exits early;
- all cores complete;
- multiple barrier rounds work.

### Test 13 — Producer-consumer with lock

Use a lock-protected queue or shared payload.

Verify coherent data visibility and correct synchronization.

### Test 14 — Contention stress

All four cores repeatedly contend on the same lock or counter.

Record:

- LR attempts;
- SC attempts;
- SC successes;
- SC failures;
- retry counts.

## Directed RTL tests

Add focused RTL-level tests for:

- decode of `LR.W`;
- decode of `SC.W`;
- `rs2 == 0` requirement for `LR.W`;
- correct destination-register writeback;
- successful SC result `0`;
- failed SC result nonzero;
- no failed-SC memory request;
- reservation set after completed LR;
- reservation not set before LR completion;
- reservation replacement;
- reset clearing;
- remote `BUS_RDX` clearing;
- remote `BUS_UPGR` clearing;
- local eviction clearing;
- mismatched block failure;
- same-block success;
- same-block/different-word remote write failure;
- uncached LR unsupported behavior;
- uncached SC failure;
- delayed `BUS_UPGR`;
- delayed snoop invalidation;
- simultaneous SC attempts from multiple cores.

## Randomized atomic verification

Add deterministic randomized LR/SC testing.

Generate operations across four cores including:

- LR;
- matching SC;
- mismatched SC;
- ordinary loads;
- ordinary stores;
- remote conflicting stores;
- evictions;
- repeated contention;
- uncached attempts where useful.

Track a reference model containing:

- architectural memory values;
- each core’s reservation-valid state;
- each core’s reserved block;
- expected SC success or failure;
- committed stores.

Check:

- every SC result;
- no failed SC modifies memory;
- every successful SC modifies exactly one word;
- reservation clearing;
- final memory state;
- coherence ownership invariants.

Use documented deterministic seeds.

Keep default runtime practical.

## Counters

Add per-core atomic counters for:

- `LR.W` attempts;
- completed `LR.W`;
- `SC.W` attempts;
- successful `SC.W`;
- failed `SC.W`;
- failures due to no reservation;
- failures due to address mismatch;
- failures due to snoop invalidation;
- failures due to eviction;
- reservation clears;
- lock or software retry counts where practical.

At minimum verify:

```text
SC attempts = SC successes + SC failures
```

Document exact counting points.

## Assertions and invariants

Add assertions or equivalent checked invariants for:

### Reservation state

- at most one reservation per core;
- reserved address is 16-byte aligned;
- reset clears reservation;
- new LR replaces old reservation;
- SC always clears reservation;
- eviction of reserved block clears reservation;
- invalidation of reserved block clears reservation;
- snoop to unrelated block does not clear reservation.

### SC correctness

- successful SC requires valid matching reservation;
- successful SC completes only while local cache owns `M`;
- successful SC writes exactly once;
- failed SC performs no store;
- failed SC issues no unnecessary ownership transaction under the baseline policy;
- SC result is `0` on success;
- SC result is nonzero on failure;
- no second SC may succeed without a new LR.

### Coherence interaction

- remote `BUS_RDX` to reserved block prevents later SC success;
- remote `BUS_UPGR` to reserved block prevents later SC success;
- no successful SC races with peer `M` ownership;
- standard MSI global invariants remain true.

### Liveness

Under bounded fixed-latency assumptions:

- accepted LR eventually completes;
- accepted SC eventually returns success or failure;
- lock contenders eventually make progress in directed fair tests;
- no atomic transaction deadlocks the snoopy transport.

Keep assertions compatible with Icarus.

## Explicit exclusions

Do not implement:

- AMO instructions;
- full RV32A;
- 64-bit atomics;
- word-granularity reservations;
- multiple reservations per core;
- reservation sets shared between cores;
- MESI;
- non-blocking caches;
- MSHRs;
- store buffers;
- speculative atomics;
- weak-memory-model fences beyond current behavior;
- an operating system;
- interrupts for synchronization;
- L2;
- directory coherence;
- coherent DMA;
- SparrowML integration;
- FPGA deployment;
- ASIC physical evaluation.

Do not begin Milestone 7.

## Functional requirements

The implementation must demonstrate:

1. Standard RV32 `LR.W` decoding.
2. Standard RV32 `SC.W` decoding.
3. Correct register writeback.
4. One reservation per core.
5. 16-byte reservation granularity.
6. Reservation set only after completed LR.
7. Matching SC success.
8. SC-without-LR failure.
9. Mismatched-address SC failure.
10. SC clears reservation on success.
11. SC clears reservation on failure.
12. Remote `BUS_RDX` clears reservation.
13. Remote `BUS_UPGR` clears reservation.
14. Local eviction clears reservation.
15. Reset clears reservation.
16. New LR replaces old reservation.
17. Failed SC has no memory side effect.
18. Successful SC stores exactly once.
19. Successful SC owns `M`.
20. LR/SC through `S → M` upgrade works.
21. Same-block different-word remote write causes failure.
22. Uncached/MMIO atomic attempts follow the documented unsupported policy.
23. Four-core spinlock works.
24. Four-core atomic counter works.
25. Reusable barrier works.
26. Contention stress works.
27. Randomized reference-model testing passes.
28. All MSI coherence invariants remain valid.
29. All previous regressions pass.
30. Atomic counters are consistent.

## Verification requirements

Add and run:

- focused core decode tests;
- focused reservation/L1D tests;
- directed four-core LR/SC tests;
- multicore software lock tests;
- atomic counter test;
- reusable barrier test;
- contention stress;
- deterministic randomized atomic verification;
- all Milestone 1–5 regressions.

Do not weaken MSI verification.

## Documentation updates

Update:

- `README.md`
- `docs/architecture.md`
- `docs/cache_architecture.md`
- `docs/coherence_protocol.md`
- `docs/bus_protocol.md`
- `docs/lr_sc.md`
- `docs/boot_and_runtime.md`
- `docs/module_hierarchy.md`
- `docs/interface_audit.md`
- `docs/memory_map.md`
- `docs/verification_plan.md`
- `docs/performance_plan.md`
- `docs/build_roadmap.md`
- `docs/source_manifest.md`
- `docs/risks_and_open_questions.md`

Create:

- `docs/build_reports/milestone_6_lr_sc.md`

The build report must record:

- ISA encoding and decode integration;
- core/L1D atomic interface;
- reservation storage location;
- reservation granularity;
- reservation-clearing events;
- LR behavior;
- SC success/failure decision point;
- MSI interaction;
- uncached/MMIO policy;
- runtime primitives;
- directed tests;
- randomized seeds and operation counts;
- lock/counter/barrier results;
- counter definitions;
- assertions;
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
make sim-lrsc
make sim-atomic-random
make sim-cluster
make sim-multicore
make regress
git diff --check
git status --short
```

Target intent:

- `make sim-unit`: focused units through Milestone 6.
- `make sim-lrsc`: directed LR/SC decode, reservation, and multicore atomic tests.
- `make sim-atomic-random`: deterministic randomized atomic/reference-model tests.
- `make sim-multicore`: bare-metal spinlock, counter, barrier, and synchronization tests.
- `make regress`: complete regression through Milestone 6.

Do not make `make check` invoke the full regression.

## Completion gate

Milestone 6 is complete only when:

- `LR.W` and `SC.W` use the intended standard RV32 encodings;
- core decode and writeback are correct;
- each core has one reservation;
- reservations use 16-byte cache-block granularity;
- LR sets reservation only after coherent load completion;
- matching SC can succeed;
- SC without LR fails;
- mismatched SC fails;
- every SC clears reservation;
- new LR replaces old reservation;
- remote `BUS_RDX` clears reservation;
- remote `BUS_UPGR` clears reservation;
- local eviction clears reservation;
- reset clears reservation;
- failed SC performs no memory write;
- successful SC performs exactly one coherent word store;
- successful SC returns `0`;
- failed SC returns nonzero;
- successful SC commits only while owning `M`;
- LR in `I`, `S`, and `M` is verified;
- SC from local `M` is verified;
- SC requiring `S → M` upgrade is verified;
- uncached/MMIO atomic policy is tested and documented;
- cache-block-granularity conflict is verified;
- all four cores pass spinlock tests;
- atomic counter reaches its exact expected value;
- reusable barrier completes multiple rounds;
- contention stress completes;
- randomized atomic reference-model tests pass for documented seeds;
- MSI coherence invariants remain valid;
- atomic counters reconcile;
- all Milestone 1–5 regressions pass;
- required documentation matches implementation;
- `make check` passes;
- `make docs-check` passes;
- `make sim-unit` passes;
- `make sim-l1i` passes;
- `make sim-l1d` passes;
- `make sim-snoop-transport` passes;
- `make sim-msi` passes;
- `make sim-coherence-random` passes;
- `make sim-lrsc` passes;
- `make sim-atomic-random` passes;
- `make sim-cluster` passes;
- `make sim-multicore` passes;
- `make regress` passes;
- no AMO, MESI, L2, non-blocking cache, SparrowML, or Milestone 7 functionality has been added;
- `reports/current_milestone_report.md` identifies this exact milestone and contains `STATUS: COMPLETE`.

Use `STATUS: BLOCKED` only for a genuine external, architectural, or toolchain blocker that prevents further progress.

If required work remains but can still be implemented, use `STATUS: IN_PROGRESS` and continue iterating.

Do not mark complete based only on one successful LR/SC sequence. Multicore contention, failure paths, and randomized checking are required.

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

- directed LR/SC scenarios passed;
- randomized seeds and operation counts;
- LR attempts;
- SC attempts, successes, and failures;
- reservation invalidations;
- spinlock iterations;
- atomic-counter expected and observed values;
- barrier rounds;
- contention retries;
- regression commands passed;
- known Icarus warnings;
- remaining deliberate limitations.

Do not paste complete source files or documentation.