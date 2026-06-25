# Sparrow runtime

Milestone 7 uses `scripts/build_runtime_sw.py` as the executable software flow. It emits deterministic RV32I plus `lr.w`/`sc.w` images and matching listings under ignored `build/sw/`.

The files in this directory define the intended C/assembly ABI for a later ELF-based flow: startup at `_start`, per-hart stack selection, hart-ID helpers, LR/SC wrappers, spinlock, atomic counter, and reusable barrier. They are kept small and libc-free so their interfaces match the generated images.
