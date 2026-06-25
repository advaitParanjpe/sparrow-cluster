# Build roadmap

| Milestone | State | Scope |
| --- | --- | --- |
| 1 | implemented | four-core uncached shared SRAM scaffold |
| 2 | implemented | private blocking non-coherent L1I only |
| 3 | implemented | private non-coherent write-back/write-allocate L1D |
| 4 | implemented | four-requester snoopy transport verification; production L1D remains non-coherent |
| 5 | not started | MSI coherence |
| 6 | not started | minimal LR.W/SC.W |

Milestone 1 deliberately does not implement any later-row functionality. The active milestone specification remains authoritative.
