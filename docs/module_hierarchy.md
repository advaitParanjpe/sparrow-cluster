# Module hierarchy

`sparrow_cluster_top` instantiates exactly four `rv32_core` instances, four `l1_instruction_cache` instances, four coherent `l1_data_cache` instances, four `core_adapter` instances, one `round_robin_arbiter` for adapter traffic, one `snoopy_coherence_transport`, and one `shared_memory_controller`.

Each L1I uses the adapter IMEM port. Each L1D has two lower paths: uncached/MMIO requests use the adapter DMEM port, while cacheable SRAM requests use the block-oriented coherence requester and snooper ports. The top-level memory mux shares the single SRAM controller between adapter traffic and coherence block transfers.

Testbenches are under `tb/unit`, `tb/coherence`, and `tb/system`; the bare-metal image is under `sw/tests`.
The core exports a two-bit DMEM atomic intent to its private L1D. The L1D owns LR/SC reservation state and exposes LR/SC counters.
