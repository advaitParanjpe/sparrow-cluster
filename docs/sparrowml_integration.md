# SparrowML Integration

Milestone 8 imports the frozen SparrowML Phase 8 WISDM RTL deployment package from sibling repository `../sparrow-ml` revision `47538b0ed46c759191d2274506a01c2eeb2bee83`. The committed package lives in `third_party/sparrowml/` and records provenance, source paths, sizes, and SHA-256 checksums in `package_manifest.json`.

Imported package:

| Item | Value |
| --- | --- |
| Workload | WISDM phone accelerometer activity recognition |
| Model | `Input[16] -> DenseLinearInt8[16->16] -> ReLU -> RequantizeInt8 -> DenseLinearInt8[16->4]` |
| Classes | walking, jogging, sitting, standing |
| Selected samples | 12 test-subject windows |
| Package identity | `677d9de6d237573a056e6c2183b7d3ffc2a1d07ac026c59960c38a609b697ac6` |
| Imported text size | 53,296 bytes |
| Runtime scratchpad/package map | 528 bytes in SparrowML package metadata |
| Sparrow-Cluster data region | cacheable SRAM starting at `0x3000` |

The import excludes training checkpoints, datasets, binary mirrors, duplicate per-sample logs, and generated simulator workspaces. Normal Sparrow-Cluster regression uses only the committed files and does not read `../sparrow-ml`.

Execution path:

| Target | Meaning |
| --- | --- |
| `sparrowml-package-check` | Verifies committed package files, sizes, checksums, and sample count |
| `sparrowml-import-check` | Verifies the deterministic source file set in the sibling package when explicitly run |
| `sparrowml-reference-check` | Cross-checks expected outputs, selected intermediate references, and sample ordering |
| `sparrowml-build` | Generates metadata and RV32I/LRSC images from committed package references |
| `sim-sparrowml-*` | Runs generated images on real Sparrow-V cores with private L1I, coherent L1D, snoopy transport, and shared SRAM |

The SparrowML source package distinguishes real Sparrow-V RTL dot-product execution from host reconstruction of bias, ReLU, and requantization. Sparrow-Cluster preserves that boundary. The Milestone 8 generated images execute package-reference validation and multicore partitioning on the real cluster; they do not claim to implement SparrowML training, compiler export, sparse execution, or a new accelerator.

Workload IDs:

| ID | Strategy | Active cores | Check |
| --- | --- | --- | --- |
| 20 | Sample-level package-reference validation | 1, 2, 4 | Prediction sum for 12 selected samples is 18 |
| 21 | Shared-work fc2-logit partition for sample 0 | 2, 4 | Reduced predicted class is 1 |
| 22 | Safe output layout | 4 | Same logical work as ID 20, 16-byte-separated outputs |
| 23 | Poor output layout | 4 | Same logical work as ID 20, packed outputs |

Measured focused results:

| Run | Cycles | Result | TX | RD | RDX | UPGR | Invalidations | Interventions | L1D hits | L1D misses |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| sample 1 core | 7,335 | 18 | 51 | 0 | 51 | 0 | 0 | 0 | 196 | 51 |
| sample 2 cores | 8,070 | 18 | 68 | 13 | 55 | 0 | 3 | 16 | 183 | 68 |
| sample 4 cores | 12,306 | 18 | 99 | 39 | 60 | 0 | 6 | 21 | 160 | 99 |
| shared 2 cores | 7,259 | 1 | 51 | 4 | 47 | 0 | 3 | 7 | 113 | 51 |
| shared 4 cores | 11,272 | 1 | 61 | 9 | 52 | 0 | 6 | 13 | 111 | 61 |
| safe layout 4 cores | 12,306 | 18 | 99 | 39 | 60 | 0 | 6 | 21 | 160 | 99 |
| poor layout 4 cores | 12,197 | 18 | 98 | 39 | 59 | 0 | 13 | 28 | 125 | 98 |

Derived equal-work sample-level scaling from this generated workload:

| Active cores | Cycles/sample | Speedup | Efficiency |
| ---: | ---: | ---: | ---: |
| 1 | 611.25 | 1.000 | 1.000 |
| 2 | 672.50 | 0.909 | 0.454 |
| 4 | 1,025.50 | 0.596 | 0.149 |

The current generated workload is intentionally correctness- and traffic-oriented; it is not optimized for speedup. Four-core execution has more coherence and synchronization overhead than useful computation for this small 12-sample reference set.

Dense and sparse status: the imported WISDM package records dense INT8 references and SparrowML source evidence for exact RTL validation. Sparrow-Cluster executes only the dense package-reference path. Sparse-aware execution is not claimed because no real Sparrow-V/Sparrow-Cluster sparse path is implemented in this milestone.
