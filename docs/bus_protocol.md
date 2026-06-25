# Snoopy bus protocol

`snoopy_coherence_transport` accepts four packed requester ports from the production L1D caches. It captures command/address/data on grant, broadcasts the command to the three peer snoopers, collects presence/modified/data/ack responses, and then either reads SRAM, writes SRAM, or completes an upgrade.

Requests are block-aligned internally. `BUS_RD` and `BUS_RDX` return a 128-bit block to the requester. `BUS_UPGR` returns no data and completes after peer acknowledgement. `WRITEBACK` bypasses snooping and writes all four words to SRAM.

For `BUS_RD` and `BUS_RDX`, a modified owner has priority over SRAM. The owner’s block is forwarded to the requester and written to SRAM by the same transaction. If no owner responds, the transport reads four ascending SRAM words. `BUS_RDX` and `BUS_UPGR` require peer invalidation acknowledgements; timeout raises the error path and increments protocol counters.

The production top-level arbitrates the transport’s SRAM word port with the existing adapter path feeding L1I and uncached L1D traffic. Only one SRAM request is presented to the controller, and responses are routed back either to the coherence transport or to the recorded adapter source.

LR/SC adds no new bus command. LR uses `BUS_RD` only on cache miss. Successful SC uses the ordinary store paths: no bus on local `M`, `BUS_UPGR` from local `S`, and no supported success from local `I`. Failed SC does not issue a coherence transaction.

Milestone 7 runtime workloads are linked/generated to use the same request paths as normal software. The workload testbench records transport command counts, invalidations, and interventions but does not change arbitration, serialization, or SRAM mux behavior.
