# Module hierarchy

`sparrow_cluster_top` instantiates exactly four `rv32_core` instances, four `l1_instruction_cache` instances, four `core_adapter` instances, one `round_robin_arbiter`, and one `shared_memory_controller`. The controller owns the sole byte-addressed SRAM array, image load, source metadata, latency counter, hart-ID aperture, and invalid-address response. Testbenches are isolated under `tb/unit` and `tb/system`; the bare-metal image is under `sw/tests`.

Each L1I sits between a core IMEM port and its adapter IMEM port. L1D is deliberately absent; it will require a separate milestone/interface audit.
