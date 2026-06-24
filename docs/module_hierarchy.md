# Module hierarchy

`sparrow_cluster_top` instantiates exactly four `rv32_core` instances, four `core_adapter` instances, one `round_robin_arbiter`, and one `shared_memory_controller`. The controller owns the sole byte-addressed SRAM array, image load, source metadata, latency counter, hart-ID aperture, and invalid-address response. Testbenches are isolated under `tb/unit` and `tb/system`; the bare-metal image is under `sw/tests`.

Later L1I and L1D modules must connect on the adapter system-request boundary. No cache module exists in Milestone 1.
