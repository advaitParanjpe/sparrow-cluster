# Milestone 8 — SparrowML Multicore Integration

## Status

READY

## Goal

Integrate a frozen SparrowML deployment package into Sparrow-Cluster and use it as the project’s primary end-to-end multicore application workload.

At completion, Sparrow-Cluster must:

- import a documented SparrowML deployment package with provenance;
- reproduce a known single-core SparrowML inference result;
- execute inference using one, two, and four active Sparrow-V cores;
- verify predictions and selected intermediate outputs against trusted SparrowML reference data;
- evaluate sample-level parallelism;
- evaluate at least one shared-work partitioning strategy;
- measure cycles, cache behavior, coherence traffic, synchronization cost, and scaling;
- compare memory-layout and output-placement choices;
- preserve all Milestone 1–7 regressions.

This milestone is an application integration and hardware-software evaluation milestone.

Do not retrain models, redesign SparrowML, or add major Sparrow-Cluster microarchitecture.

## Required context

Before editing, read:

- `AGENTS.md`
- `README.md`
- `docs/architecture.md`
- `docs/runtime.md`
- `docs/workloads.md`
- `docs/boot_and_runtime.md`
- `docs/performance_plan.md`
- `docs/verification_plan.md`
- `docs/memory_map.md`
- `docs/cache_architecture.md`
- `docs/coherence_protocol.md`
- `docs/bus_protocol.md`
- `docs/lr_sc.md`
- `docs/module_hierarchy.md`
- `docs/interface_audit.md`
- `docs/reuse_plan.md`
- `docs/source_manifest.md`
- `docs/build_roadmap.md`
- `docs/risks_and_open_questions.md`
- all build reports through `docs/build_reports/milestone_7_multicore_runtime.md`
- relevant ADRs
- current bare-metal runtime and workload flow
- current generated-image tooling
- current hardware counters and result-structure decoding
- current SparrowML repository and its canonical deployment/package outputs

Inspect the current repository state before making changes.

Read the sibling `../sparrow-ml` repository only as needed for audit, package selection, provenance, and deterministic import.

Do not modify `../sparrow-ml` or any other sibling repository.

Use targeted searches and concise command output.

## Milestone boundary

SparrowML remains the source of truth for:

- model training;
- architecture selection;
- quantization;
- pruning;
- sparsity;
- compiler/export logic;
- golden inference behavior;
- package metadata.

Sparrow-Cluster is responsible for:

- importing a frozen deployable package;
- executing the packaged workload;
- validating outputs;
- partitioning work across cores;
- measuring cache, coherence, synchronization, and multicore behavior.

Do not duplicate SparrowML research or training pipelines inside Sparrow-Cluster.

## First task: audit SparrowML deployment assets

Inspect `../sparrow-ml` and identify the canonical deployable package.

Audit:

- model and workload name;
- input shape;
- layer structure;
- quantization format;
- weight and activation widths;
- dense and sparse representations;
- generated instructions or runtime calls;
- memory layout;
- expected predictions;
- expected intermediate activations;
- package metadata;
- existing Sparrow-V execution path;
- existing host-side reconstruction path;
- existing RTL-simulation path;
- current test samples;
- package size;
- source commit revision;
- exact files required for import.

Prefer a package already verified against Sparrow-V.

The audit must clearly distinguish:

- real RTL-simulated execution;
- host reconstruction;
- Python reference inference;
- generated-package reload validation.

Do not present host reconstruction as processor execution.

## Frozen package and provenance

Import only the files required to reproduce the selected workload.

Preferred repository structure:

```text
third_party/
└── sparrowml/
    ├── PROVENANCE.md
    ├── package_manifest.json
    ├── model metadata
    ├── weights
    ├── inputs
    ├── expected outputs
    └── selected intermediate references
```

Alternatively use a suitable generated-data directory if `third_party/` is inappropriate under the current source manifest.

Requirements:

- do not copy the entire SparrowML repository;
- record source repository path;
- record source Git revision;
- record import date;
- record exact source paths;
- record checksums for imported package files;
- provide a deterministic import or sync script;
- preserve package metadata;
- keep normal Sparrow-Cluster simulation independent of absolute sibling paths;
- do not use a Git submodule.

Imported artifacts must be small enough to commit responsibly.

Large optional datasets or training artifacts must not be copied.

## Selected workload

Use the canonical completed SparrowML edge workload.

Based on the existing project, the preferred workload is the frozen WISDM-style quantized inference package already validated by SparrowML, unless the audit identifies a newer canonical package.

Freeze:

- selected model;
- number of input features;
- hidden dimensions;
- output classes;
- quantization parameters;
- selected test samples;
- expected predictions;
- selected intermediate outputs;
- dense or sparse execution mode used by each experiment.

Document any difference between the standalone SparrowML target and Sparrow-Cluster execution.

## Execution baseline

First reproduce single-core inference inside Sparrow-Cluster.

Requirements:

1. Load one frozen package.
2. Load at least one selected held-out sample.
3. Execute the intended Sparrow-V/SparrowML instruction or runtime sequence.
4. Verify:
   - final prediction;
   - final logits or output accumulator values;
   - selected intermediate results where available;
   - exact integer agreement where the package promises exact agreement.
5. Record cycles and hardware counters.
6. Confirm that execution uses:
   - real Sparrow-V core;
   - private L1I;
   - coherent L1D;
   - snoopy transport;
   - shared SRAM.

Do not proceed to multicore claims until single-core equivalence is proven.

## Software execution path

Integrate SparrowML into the Milestone 7 runtime flow.

Preferred approach:

- package-to-memory-image generator;
- small runtime driver;
- shared model metadata;
- per-core workload descriptor;
- deterministic result structure;
- existing simulation completion mechanism.

Support the current deterministic generated-image fallback.

If a complete RISC-V ELF compiler becomes available, it may be used, but do not make this milestone depend on installing one.

Clearly distinguish:

- executed generated-image path;
- reference C/assembly API;
- host-side validation.

## Sample-level parallelism

Implement sample-level parallel inference.

### One active core

- one core processes all selected samples;
- other cores remain inactive safely.

### Two active cores

- partition samples deterministically across cores;
- each core writes results to a private, cache-block-safe output region.

### Four active cores

- partition samples deterministically across all four cores;
- avoid false sharing in per-core work descriptors and outputs.

Requirements:

- identical predictions to single-core execution;
- deterministic sample assignment;
- exact result ordering after aggregation;
- no data races;
- no unnecessary lock in the main compute loop;
- barrier or completion synchronization only where needed.

Run enough samples to measure useful multicore scaling without making regression excessive.

## Shared read-only weights

Use one shared cacheable weight representation where practical.

Evaluate:

- all cores reading common weight data;
- L1D shared-state behavior;
- cache reuse;
- coherence traffic;
- whether initial weight reads dominate traffic;
- whether subsequent read-only execution remains mostly shared.

Do not replicate all weights per core unless needed for a comparison.

If package constraints force replication, document that and still provide one shared-data experiment.

## Required partitioning strategies

Implement at least two execution strategies.

### Strategy A — Sample-level parallelism

Each core performs complete inference on independent samples.

This is expected to scale well and produce minimal writable sharing.

### Strategy B — Shared-work partitioning

Partition at least one inference computation across cores.

Preferred options, in order:

1. output-neuron or output-row partitioning;
2. hidden-neuron partitioning;
3. partial-sum partitioning;
4. layer-level cooperative execution.

Choose the simplest strategy supported cleanly by the package.

Requirements:

- shared read-only inputs and weights where suitable;
- per-core partial outputs aligned to separate cache blocks;
- barrier before reduction or next layer;
- deterministic final reduction;
- exact output agreement with reference;
- synchronization and coherence costs measured.

Do not force a complicated partition that obscures correctness.

## Dense and sparse execution

If the selected SparrowML package contains both dense and sparse-aware modes, evaluate both where the current Sparrow-V implementation supports them.

At minimum distinguish:

- dense vector or scalar execution;
- sparse-aware execution;
- host-only sparse reconstruction, if any;
- real processor-executed sparse path.

Do not claim sparse RTL execution if only the host model performs it.

Record:

- conceptual multiplications;
- operations skipped;
- cycles;
- memory traffic;
- cache behavior;
- prediction agreement.

If only one mode is truly executable in Sparrow-Cluster, use it as the required path and document the other as out of scope.

## Memory-layout experiments

Implement controlled layout comparisons.

### Layout 1 — False-sharing-safe outputs

- each core’s result and partial-output region begins on a separate 16-byte cache block;
- synchronization data is separately aligned.

### Layout 2 — Intentionally poor output layout

- place independently written per-core outputs within the same cache block;
- keep logical work identical;
- verify correctness;
- measure additional invalidations and ownership transfers.

### Layout 3 — Shared read-only weights

- one common weight layout;
- all cores read the same data;
- no writes to the weight region.

### Optional Layout 4 — Replicated weights

If memory size allows:

- one private copy per core;
- compare cache/coherence behavior against shared weights;
- report capacity and memory-traffic tradeoffs.

Do not overstate performance conclusions from one model or simulation.

## Synchronization policy

Use the Milestone 7 runtime primitives.

Allowed synchronization:

- LR/SC spinlocks;
- reusable barriers;
- atomic counters;
- per-core completion slots.

Preferred behavior:

- sample-level inference should avoid locks in the compute path;
- shared-work inference should use barriers and per-core partial buffers;
- final reduction may use Core 0 or a lock only if necessary;
- avoid one shared counter update per inner-loop operation.

Record synchronization cycles and SC retry behavior where practical.

## Result and reference validation

For every executed sample, validate:

- input sample ID;
- predicted class;
- output/logit values where available;
- selected intermediate activations;
- package checksum or identifier;
- active-core configuration;
- execution strategy.

Exact integer comparisons are required where the SparrowML package guarantees exact quantized behavior.

If a tolerance is required for any value:

- justify it;
- document it;
- use a fixed deterministic tolerance.

Do not validate only final prediction if stronger reference data is available.

## Hardware counters and metrics

Collect, where available:

- cycles;
- retired instructions;
- L1I accesses;
- L1I hits and misses;
- L1D accesses;
- L1D hits and misses;
- `BUS_RD`;
- `BUS_RDX`;
- `BUS_UPGR`;
- writebacks;
- invalidations;
- interventions;
- bus occupancy;
- per-core arbitration wait;
- LR attempts;
- SC attempts;
- SC failures;
- barrier rounds;
- synchronization retries;
- bytes or words read from shared SRAM;
- model/package size;
- samples completed;
- cycles per sample;
- speedup;
- parallel efficiency.

Clearly identify which metrics are:

- hardware counters;
- testbench observations;
- software counters;
- derived quantities.

## Required experiments

### Experiment 1 — Single-core equivalence

Run selected frozen samples on one core.

Verify exact outputs and selected intermediates.

Record baseline cycles per sample.

### Experiment 2 — Sample-level scaling

Run the same sample set using:

- one core;
- two cores;
- four cores.

Report:

- total cycles;
- cycles per sample;
- speedup;
- parallel efficiency;
- cache misses;
- coherence traffic;
- synchronization cost.

### Experiment 3 — Shared-work partitioning

Run one or more samples cooperatively using two and four cores.

Report:

- correctness;
- partition strategy;
- cycles;
- barrier cost;
- partial-output traffic;
- coherence commands;
- comparison with single-core execution.

### Experiment 4 — Safe versus poor output placement

Compare cache-block-separated output buffers with false-sharing-prone placement.

Report:

- correctness;
- cycles;
- invalidations;
- ownership transfers;
- `BUS_RDX`;
- `BUS_UPGR`;
- writebacks where relevant.

### Experiment 5 — Shared-weight behavior

Measure all cores reading shared read-only weights.

Report:

- first-use misses;
- later hits;
- coherence traffic;
- interventions and invalidations, which should be minimal for read-only data.

### Experiment 6 — Dense versus sparse

Only if both paths execute on the real Sparrow-V/Sparrow-Cluster system.

Report:

- accuracy or prediction agreement;
- operations skipped;
- cycles;
- memory traffic;
- cache behavior;
- coherence behavior.

Do not require sparse mode if the audit proves it is not a real executable target.

### Experiment 7 — Repeated inference

Run repeated inferences to distinguish:

- cold-cache behavior;
- warm-cache behavior;
- package/setup overhead;
- steady-state throughput.

## Active-core configurations

Support:

- one active core;
- two active cores;
- four active cores.

Inactive cores must remain safe and must not modify workload state.

Use deterministic core assignment.

## Verification requirements

### Package integrity

Verify:

- package manifest;
- checksums;
- source revision;
- expected file set;
- no accidental training or dataset artifacts;
- memory size fits the configured SRAM.

### Import script

Add a deterministic import/check script.

It should:

- locate the sibling SparrowML package when explicitly run;
- copy only approved files;
- record provenance;
- verify checksums;
- avoid absolute paths in committed outputs;
- refuse incomplete package imports.

Normal regression must use committed frozen package files and not depend on the sibling repository.

### Software/image generation

Verify:

- package parser;
- address placement;
- alignment;
- model/input/result regions;
- generated instruction legality;
- deterministic image generation;
- no unsupported instructions;
- no memory overlap.

### Single-core validation

Verify exact agreement for every selected sample.

### Multicore validation

Verify:

- no duplicate sample assignment;
- no omitted samples;
- deterministic output ordering;
- all active cores complete;
- inactive cores remain safe;
- all predictions match reference;
- partial outputs combine correctly.

### Shared-work validation

Verify:

- each core processes only its assigned partition;
- all partial outputs are present before reduction;
- barriers are correct;
- final result matches reference;
- no false-sharing-safe buffer overlap.

### Regression preservation

All Milestone 1–7 regressions must continue to pass.

Do not weaken coherence, LR/SC, runtime, or false-sharing checks.

## Timeouts and diagnostics

Every SparrowML simulation must have a bounded timeout.

On timeout report:

- experiment;
- sample ID;
- active-core count;
- partition strategy;
- per-core completion state;
- per-core PC where available;
- current layer or phase;
- barrier state;
- result-buffer state;
- coherence-transport state;
- last observed progress marker.

## Assertions and invariants

Add or preserve checks for:

- model weights are not modified;
- sample assignments are unique and complete;
- per-core output regions do not overlap in safe-layout runs;
- shared-work partial regions do not overlap;
- reduction starts only after all required partials complete;
- predictions match reference;
- exact intermediate checks match reference where enabled;
- inactive cores do not write workload data;
- completion occurs only after all assigned samples finish;
- false-sharing experiment changes layout, not logical work;
- SparrowML execution preserves all MSI and LR/SC invariants.

## Performance calculations

Compute:

```text
speedup(N) = cycles(1 core) / cycles(N cores)
```

and:

```text
parallel efficiency(N) = speedup(N) / N
```

Use equivalent total work for scaling comparisons.

Do not compare different sample counts without normalization.

Clearly distinguish:

- latency of one sample;
- throughput over multiple samples;
- total batch completion cycles.

## Documentation updates

Update:

- `README.md`
- `docs/architecture.md`
- `docs/runtime.md`
- `docs/workloads.md`
- `docs/boot_and_runtime.md`
- `docs/performance_plan.md`
- `docs/verification_plan.md`
- `docs/memory_map.md`
- `docs/cache_architecture.md`
- `docs/coherence_protocol.md`
- `docs/bus_protocol.md`
- `docs/module_hierarchy.md`
- `docs/interface_audit.md`
- `docs/reuse_plan.md`
- `docs/source_manifest.md`
- `docs/build_roadmap.md`
- `docs/risks_and_open_questions.md`

Create:

- `docs/sparrowml_integration.md`
- `docs/build_reports/milestone_8_sparrowml_integration.md`

The build report must include:

- selected SparrowML package;
- source revision;
- import manifest and checksums;
- model architecture summary;
- quantization and sparsity format;
- selected samples;
- reference outputs;
- executed software path;
- distinction between RTL execution and host reconstruction;
- single-core equivalence results;
- one-, two-, and four-core sample-level results;
- shared-work strategy;
- layout experiments;
- dense/sparse status;
- cold/warm-cache results;
- counter tables;
- speedup and efficiency;
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
make sparrowml-package-check
make sparrowml-import-check
make sparrowml-build
make sparrowml-reference-check
make sim-sparrowml-single
make sim-sparrowml-scaling
make sim-sparrowml-shared
make sim-sparrowml-layout
make sim-sparrowml
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

- `make sparrowml-package-check`: verify committed package manifest, files, checksums, sizes, and provenance.
- `make sparrowml-import-check`: validate deterministic import/sync logic without modifying sibling repositories.
- `make sparrowml-build`: generate executable images and result metadata.
- `make sparrowml-reference-check`: validate imported expected outputs and selected intermediates.
- `make sim-sparrowml-single`: single-core exact-equivalence tests.
- `make sim-sparrowml-scaling`: one-, two-, and four-core sample-level scaling.
- `make sim-sparrowml-shared`: cooperative shared-work partitioning.
- `make sim-sparrowml-layout`: safe versus false-sharing-prone layout experiments.
- `make sim-sparrowml`: all required SparrowML experiments.
- `make regress`: complete Milestone 1–8 regression.

Do not make `make check` run the full regression.

## Explicit exclusions

Do not implement:

- model training;
- retraining;
- new quantization research;
- new pruning research;
- new compiler architecture;
- unsupported sparse execution claims;
- full ONNX or PyTorch runtime;
- operating system support;
- dynamic model loading;
- filesystem;
- virtual memory;
- new ISA instructions;
- major Sparrow-V changes;
- MESI;
- non-blocking caches;
- MSHRs;
- L2;
- directory coherence;
- coherent DMA;
- TinyNPU integration;
- FPGA deployment;
- ASIC physical evaluation.

Do not begin Milestone 9.

## Functional requirements

The repository must demonstrate:

1. Frozen SparrowML package import with provenance.
2. Package integrity and checksums.
3. Reproducible package-to-image flow.
4. One real SparrowML inference on one Sparrow-V core.
5. Exact final prediction agreement.
6. Exact selected intermediate agreement where supported.
7. One-core sample-level execution.
8. Two-core sample-level execution.
9. Four-core sample-level execution.
10. Deterministic sample partitioning.
11. No missing or duplicate samples.
12. Shared read-only weight access.
13. At least one cooperative shared-work partition.
14. Exact shared-work output agreement.
15. Barrier and reduction correctness.
16. Cache-block-safe output layout.
17. Intentionally poor output layout comparison.
18. Coherence metrics for both layouts.
19. Cold- and warm-cache measurements.
20. Cycles per sample.
21. Speedup and parallel efficiency.
22. Cache and coherence counter reporting.
23. Dense/sparse distinction documented honestly.
24. All prior regressions preserved.

## Completion gate

Milestone 8 is complete only when:

- a canonical SparrowML deployment package is selected;
- package source revision and source paths are recorded;
- imported files have checksums;
- normal regression does not depend on the sibling SparrowML repository;
- package fits within the implemented memory map;
- package-to-image generation is deterministic;
- unsupported instructions are rejected;
- single-core inference executes on the real Sparrow-V/Sparrow-Cluster path;
- selected single-core outputs match reference exactly where promised;
- one-, two-, and four-core sample-level runs complete;
- sample assignment is complete and non-duplicated;
- multicore predictions match the single-core/reference results;
- shared read-only weights are exercised;
- at least one shared-work partitioning strategy runs correctly;
- shared-work final output matches reference;
- synchronization and reduction are verified;
- safe output placement works;
- intentionally poor placement works correctly and records additional coherence effects where present;
- cold- and warm-cache behavior is measured;
- cycles, cache counters, coherence counters, and synchronization metrics are reported;
- speedup and parallel efficiency are computed using equal total work;
- dense/sparse execution claims match the actual executed path;
- all relevant assertions pass;
- all Milestone 1–7 regressions pass;
- required documentation matches implementation;
- `make check` passes;
- `make docs-check` passes;
- `make sparrowml-package-check` passes;
- `make sparrowml-import-check` passes;
- `make sparrowml-build` passes;
- `make sparrowml-reference-check` passes;
- `make sim-sparrowml-single` passes;
- `make sim-sparrowml-scaling` passes;
- `make sim-sparrowml-shared` passes;
- `make sim-sparrowml-layout` passes;
- `make sim-sparrowml` passes;
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
- no synthesis, FPGA, ASIC, MESI, L2, non-blocking cache, or Milestone 9 functionality has been added;
- `reports/current_milestone_report.md` identifies this exact milestone and contains `STATUS: COMPLETE`.

Use `STATUS: BLOCKED` only for a genuine external, architectural, package, or toolchain blocker that prevents further progress.

If one candidate SparrowML package is unsuitable, inspect other existing canonical package outputs before declaring a blocker.

If required work remains but can still be implemented, use `STATUS: IN_PROGRESS` and continue iterating.

Do not mark complete based only on host reconstruction or final-class agreement. Real processor execution and stronger reference checks are required.

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

- SparrowML source revision;
- package files and size;
- selected sample count;
- exact outputs checked;
- intermediate values checked;
- one-, two-, and four-core cycles;
- cycles per sample;
- speedup;
- parallel efficiency;
- cache hit/miss counts;
- coherence commands;
- invalidations;
- interventions;
- LR/SC retries;
- shared-work partition details;
- safe versus poor layout results;
- cold versus warm results;
- dense/sparse execution status;
- regression commands passed;
- remaining deliberate limitations.

Do not paste complete package files, source files, or documentation.