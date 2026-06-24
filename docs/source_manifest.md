# Source manifest

Synthesizable Milestone 3 cluster sources are `rtl/core/imported/` (the reviewed, unmodified Sparrow-V scalar closure), `rtl/cache/l1_instruction_cache.sv`, `rtl/cache/l1_data_cache.sv`, `rtl/interconnect/`, `rtl/memory/`, and `rtl/top/`. The import closure and upstream paths are documented in [reuse plan](reuse_plan.md); its recorded source revision is `995ea0f9cada63688c9e21e739bd41d6b1c118af`.

`tb/unit/tb_l1i.sv` and `tb/unit/tb_l1d.sv` are focused cache tests; `tb/system/tb_cluster.sv` and `tb/system/tb_m1_multicore.sv` exercise four real cores. `sw/` contains the hand-encoded software image, and ignored `reports/` contains local milestone reports. `scripts/import_sparrow_v.sh` is deterministic synchronization support. No generated simulator files, external repositories, or SparrowML artifacts are tracked.
