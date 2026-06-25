# Build roadmap

| Milestone | State | Scope |
| --- | --- | --- |
| 1 | implemented | four-core uncached shared SRAM scaffold |
| 2 | implemented | private blocking non-coherent L1I only |
| 3 | implemented | private non-coherent write-back/write-allocate L1D |
| 4 | implemented | four-requester snoopy transport verification |
| 5 | implemented | production L1D MSI coherence integration |
| 6 | implemented | minimal LR.W/SC.W |
| 7 | implemented | deterministic multicore runtime and workloads |
| 8 | implemented | frozen SparrowML WISDM package integration and multicore workload evaluation |

Milestone 8 does not implement model training, retraining, sparse processor execution, other AMOs, full RV32A, MESI, non-blocking caches, L2, coherent L1I, an operating system, interrupts, or FPGA/ASIC deployment. The active milestone specification remains authoritative for runner scope.
