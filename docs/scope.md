# Scope

## Goals

Deliver a verifiable four-core bare-metal shared-memory system around Sparrow-V, then execute a partitioned SparrowML workload.

## Baseline features

Four cores; private 2 KiB/2-way/16-byte-block L1I and L1D; blocking caches; non-coherent read-only L1I; write-back/write-allocate L1D snoopy MSI; one round-robin bus/transaction; shared parameterized-latency SRAM; minimal LR.W/SC.W; strong ordering; directed, randomized, assertion, and software verification.

## Non-goals

Non-blocking caches, MSHRs, L2, directory, crossbar/NoC, full RV32A, OoO/speculation, virtual memory/OS, coherent TinyNPU, and prefetching.

## Stretch goals

MESI only after workload evidence; implementation evaluation after functional milestones.

## Completion criteria

Each roadmap gate passes with its documented tests and no unsupported measurement claim. Milestone 0 is complete when the interface, protocol, reuse, risks, and automation documents are checked.
