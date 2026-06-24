# Memory map

Default SRAM is parameterized as 256 KiB at `0x00000000..0x0003ffff`; unmapped accesses return zero. The reset vector stays at `0x00000000` and `mtvec` remains Sparrow-V's `0x00000100`.

| Range | Purpose |
| --- | --- |
| `0x00000000..0x000000ff` | program image and boot code |
| `0x00000100..0x000001ff` | trap vector space |
| `0x00000200..0x000002ff` | runtime data available to tests |
| `0x00000300..0x0000030f` | single-writer initialized data and release flag |
| `0x00000400..0x0000040f` | per-hart result words |
| `0x00000500..0x0000053f` | four 16-byte static partitions |
| `0x00000600..0x0000060f` | per-hart completion words |
| `0x0003fc00..0x0003ffff` | four 256-byte production stack regions, allocated downward |
| `0x10000000` | read-only core-local hart ID |

The directed 4 KiB test configuration uses equivalent low test stacks at `0x6f0`, `0x5f0`, `0x4f0`, and `0x3f0`; they are non-overlapping. No other control registers exist.
