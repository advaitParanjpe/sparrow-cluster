# MSI coherence protocol

Production L1D caches now implement snoopy MSI over the canonical commands in `coherence_pkg`: `BUS_RD=0`, `BUS_RDX=1`, `BUS_UPGR=2`, and `WRITEBACK=3`. The transport remains globally serialized, so one block transaction is active at a time.

| Event | I | S | M |
| --- | --- | --- | --- |
| Local load | `BUS_RD`, install `S` | serve | serve |
| Local store | `BUS_RDX`, install `M` | `BUS_UPGR`, then merge in `M` | merge |
| Snoop `BUS_RD` | no copy | report shared | supply block, `M->S` |
| Snoop `BUS_RDX` | ack no copy | invalidate | supply block, `M->I` |
| Snoop `BUS_UPGR` | ack no copy | invalidate | protocol error |
| Evict | none | discard clean | `WRITEBACK`, then discard |

Modified-owner data is authoritative. On intervention, the owner supplies the same 16-byte block to the requester and to SRAM through the transport’s coupled writeback path before the requester completes. SRAM data is selected only when no modified owner responds.

Local processor requests are accepted only in the L1D `IDLE` state. Snoop responses are combinational from stable MSI arrays and state transitions are committed once per broadcast. If a pending but not yet granted local upgrade is invalidated by another accepted transaction, the pending command is promoted to `BUS_RDX` before it is granted. The requesting cache is never snooped by its own transaction.

Assertions and checked invariants cover invalid hits, duplicate ways, upgrades without `S`, stores completing outside `M`, stale-SRAM selection over an owner, requester self-snoop, and counter accounting.
