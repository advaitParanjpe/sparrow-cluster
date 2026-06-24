# Source manifest

Synthesizable Milestone 2 cluster sources are `rtl/core/imported/` (the reviewed, unmodified Sparrow-V scalar closure), `rtl/cache/l1_instruction_cache.sv`, `rtl/interconnect/`, `rtl/memory/`, and `rtl/top/`. The import closure and upstream paths are documented in [reuse plan](reuse_plan.md); its recorded source revision is `995ea0f9cada63688c9e21e739bd41d6b1c118af`.

`tb/unit/tb_l1i.sv` is the focused L1I test; `tb/system/tb_cluster.sv` executes the hand-encoded `sw/tests/m2_l1i.S` conflict program, and `sw/tests/m1_multicore.{S,hex}` contains the Milestone 1 bare-metal image. `scripts/import_sparrow_v.sh` is deterministic synchronization support. `reports/` and `.codex_runs/` are ignored local run outputs. No generated simulator files, external repositories, or SparrowML artifacts are tracked.
