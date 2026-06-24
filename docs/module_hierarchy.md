# Module hierarchy

`sparrow_cluster_top` instantiates exactly four `rv32_core` instances, four `l1_instruction_cache` instances, four `l1_data_cache` instances, four `core_adapter` instances, one `round_robin_arbiter`, and one `shared_memory_controller`. The controller owns the sole byte-addressed SRAM array, image load, source metadata, latency counter, hart-ID aperture, and invalid-address response. Testbenches are isolated under `tb/unit` and `tb/system`; the bare-metal image is under `sw/tests`.

Each L1I and L1D sits between the corresponding core port and adapter port. L1D cacheable traffic and uncached bypass share the adapter DMEM port.
