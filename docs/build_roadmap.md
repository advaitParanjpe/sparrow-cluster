# Build roadmap

| Milestone | State | Scope |
| --- | --- | --- |
| 1 | implemented | four-core uncached shared SRAM scaffold |
| 2 | implemented | private blocking non-coherent L1I only |
| 3 | implemented | private non-coherent write-back/write-allocate L1D |
| 4 | implemented | four-requester snoopy transport verification |
| 5 | implemented | production L1D MSI coherence integration |
| 6 | not started | minimal LR.W/SC.W |

Milestone 5 does not implement atomics, reservations, MESI, non-blocking caches, L2, coherent L1I, or SparrowML integration. The active milestone specification remains authoritative for runner scope.
