# Source manifest

Synthesizable Milestone 1 cluster sources are `rtl/core/imported/` (the reviewed, unmodified Sparrow-V scalar closure), `rtl/interconnect/`, `rtl/memory/`, and `rtl/top/`. The import closure and upstream paths are documented in [reuse plan](reuse_plan.md); its recorded source revision is `995ea0f9cada63688c9e21e739bd41d6b1c118af`.

`tb/unit/` contains focused component tests, `tb/system/` contains real-core system tests, and `sw/tests/m1_multicore.{S,hex}` contains the documented hand-encoded bare-metal test image. `scripts/import_sparrow_v.sh` is deterministic synchronization support. `reports/` and `.codex_runs/` are ignored local run outputs. No generated simulator files, external repositories, caches, or SparrowML artifacts are tracked.
