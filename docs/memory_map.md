# Memory map

Default SRAM is parameterized as 256 KiB at `0x00000000..0x0003ffff`; the Milestone 7 runtime testbench uses a 64 KiB SRAM instance. Unmapped accesses return zero. The reset vector stays at `0x00000000` and `mtvec` remains Sparrow-V's `0x00000100`.

| Range | Purpose |
| --- | --- |
| `0x00000000..0x000000ff` | program image and boot code |
| `0x00000100..0x000001ff` | trap vector space |
| `0x00000200..0x0000020f` | uncached cluster-test result words |
| `0x00000300..0x0000030f` | uncached initialization and release flag |
| `0x00000400..0x0000040f` | uncached per-hart result words |
| `0x00000500..0x0000053f` | four 16-byte static partitions |
| `0x00000600..0x0000060f` | uncached per-hart completion words |
| `0x00000800..` | Milestone 7 generated runtime/workload text |
| `0x00001000..0x000011ff` | cacheable shared workload data |
| `0x0000fc00..0x0000ffff` | four 256-byte Milestone 7 stack regions, allocated downward |
| `0x0003fc00..0x0003ffff` | four 256-byte production stack regions, allocated downward |
| `0x10000000` | read-only core-local hart ID |

Ordinary mapped SRAM is cacheable, coherent, and usable for LR/SC, except for the explicit uncached apertures above. Uncached accesses do not allocate and do not modify MSI metadata. LR to an uncached aperture does not establish a reservation, and SC to an uncached aperture fails without storing. The directed 4 KiB test configuration uses equivalent low test stacks at `0x6f0`, `0x5f0`, `0x4f0`, and `0x3f0`; they are non-overlapping.
