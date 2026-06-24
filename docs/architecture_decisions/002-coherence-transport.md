# ADR 002: coherence and transport

**Accepted.** Use blocking write-back/write-allocate L1D snoopy MSI on one round-robin shared bus, one active transaction, and M-owner intervention with coupled SRAM update. L1I is non-coherent. No MSHRs, directory, NoC, or MESI baseline.
