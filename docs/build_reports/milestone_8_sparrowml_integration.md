# Milestone 8 - SparrowML Multicore Integration

Selected package: SparrowML Phase 8 WISDM RTL package from `../sparrow-ml` revision `47538b0ed46c759191d2274506a01c2eeb2bee83`.

Imported files: 13 text files under `third_party/sparrowml/`, 53,296 bytes total. `package_manifest.json` records exact source paths, sizes, and SHA-256 checksums. Training checkpoints, datasets, binary mirrors, per-sample logs, and generated simulator workspaces are deliberately absent. Normal regression uses only committed package files.

Model summary: WISDM phone accelerometer activity recognition, 16 int8 input features, dense `16->16` fc1, ReLU, hidden requantization, dense `16->4` fc2, classes walking/jogging/sitting/standing. The selected package contains 12 test-subject samples, expected predictions, fc2 accumulator outputs, and selected fc1/hidden intermediate references.

Executed software path: `scripts/build_runtime_sw.py` remains the deterministic RV32I/LRSC image generator. Milestone 8 adds package-derived workload IDs 20 through 23 and places cacheable SparrowML runtime data at `0x3000`. Simulations instantiate real Sparrow-V cores, private L1I, coherent L1D, snoopy MSI transport, and shared SRAM.

Execution boundary: SparrowML source evidence distinguishes real RTL dot-product execution from host reconstruction of bias/ReLU/requantization. Sparrow-Cluster package checks validate imported references and simulations execute package-reference validation and multicore partitioning. This milestone does not claim retraining, sparse execution, a compiler backend, or a new accelerator.

Measured focused results:

| Run | Cycles | Result | TX | RD | RDX | UPGR | Invalidations | Interventions | L1D hits | L1D misses |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| single equivalence, 1 core | 7,335 | 18 | 51 | 0 | 51 | 0 | 0 | 0 | 196 | 51 |
| sample scaling, 2 cores | 8,070 | 18 | 68 | 13 | 55 | 0 | 3 | 16 | 183 | 68 |
| sample scaling, 4 cores | 12,306 | 18 | 99 | 39 | 60 | 0 | 6 | 21 | 160 | 99 |
| shared-work, 2 cores | 7,259 | 1 | 51 | 4 | 47 | 0 | 3 | 7 | 113 | 51 |
| shared-work, 4 cores | 11,272 | 1 | 61 | 9 | 52 | 0 | 6 | 13 | 111 | 61 |
| safe layout, 4 cores | 12,306 | 18 | 99 | 39 | 60 | 0 | 6 | 21 | 160 | 99 |
| poor layout, 4 cores | 12,197 | 18 | 98 | 39 | 59 | 0 | 13 | 28 | 125 | 98 |

Sample-level equal-work calculations:

| Active cores | Cycles/sample | Speedup | Efficiency |
| ---: | ---: | ---: | ---: |
| 1 | 611.25 | 1.000 | 1.000 |
| 2 | 672.50 | 0.909 | 0.454 |
| 4 | 1,025.50 | 0.596 | 0.149 |

Safe versus poor layout: both runs produce result 18. The poor packed layout records more invalidations and interventions than the safe layout in this run: invalidations increase from 6 to 13 and interventions from 21 to 28.

Shared read-only behavior: all SparrowML workload variants read common package-derived reference and weight-summary data from cacheable SRAM. The small workload creates coherence traffic, but the measured result should not be generalized beyond this package-reference benchmark.

Dense/sparse status: dense package-reference execution is implemented. Sparse-aware execution is deliberately not claimed because no real Sparrow-V/Sparrow-Cluster sparse path exists in this milestone.

Known limitations: the generated fallback validates package references and multicore partitioning rather than running a complete compiler-produced SparrowML instruction stream. Cold/warm behavior is represented by repeated generated-image runs in `sim-sparrowml`; no optimized steady-state ML throughput claim is made.

Verification run for this report passed:

```text
make sparrowml-package-check
make sparrowml-import-check
make sparrowml-build
make sparrowml-reference-check
make sim-sparrowml
```

Full regression status is recorded in `reports/current_milestone_report.md`.
