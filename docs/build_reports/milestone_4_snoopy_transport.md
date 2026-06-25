# Milestone 4 — Snoopy Coherence Transport Infrastructure

`snoopy_coherence_transport` provides four requester ports using canonical `coherence_pkg` commands (`BUS_RD`, `BUS_RDX`, `BUS_UPGR`, `WRITEBACK`). A requester holds valid fields to acceptance; its ID, block-aligned address, command, and optional 16-byte writeback block remain owned by the transaction until the single response/completion handshake.

The phases are idle/arbitration, snoop broadcast and collection, source selection, four-word SRAM read or write, and requester response. Round-robin priority begins at requester zero and advances only after completion. The requester is excluded from the three-peer response/acknowledgement set. Responses aggregate `shared_seen`; a second modified-owner claim is a protocol error.

A modified owner supplies the authoritative 16-byte block. The transport returns that exact block and writes its four ascending 32-bit words to SRAM before completion. Otherwise reads source SRAM. `BUS_RDX` and `BUS_UPGR` wait for all peer invalidation acknowledgements; `BUS_UPGR` returns no data. `WRITEBACK` writes its supplied block without a snoop broadcast.

Counters count accepted commands, shared transactions, interventions, completed block reads/writes, invalidation acknowledgements, occupied cycles, protocol errors, timeouts, and idle arbitration waits. `tb_snoopy_transport` uses interface-shaped peer fixtures and checks no peer, shared peer, owner intervention, delayed memory handshakes, acknowledgement timeout, and counter consistency.

Measured result: `make sim-snoop-transport` passes seven transactions (three `BUS_RD`, one `BUS_RDX`, two `BUS_UPGR`, one `WRITEBACK`), one intervention, three SRAM block reads, two block writes, and one missing-ack timeout. The existing L1D remains non-coherent; no MSI transitions, invalidations, LR/SC, MSHRs, or coherent L1I behavior are implemented.
