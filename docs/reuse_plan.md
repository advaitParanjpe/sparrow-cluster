# Reuse plan

The repository-local imported scalar closure is `rtl/core/imported/{sparrowv_scalar_pkg,rv32_core,rv32_alu,rv32_decoder,rv32_immediate,rv32_regfile}.sv`, copied from the matching `rtl/common` and `rtl/core` paths of Sparrow-V revision `995ea0f9cada63688c9e21e739bd41d6b1c118af`. It is unmodified. `scripts/import_sparrow_v.sh` copies exactly this list from an explicitly supplied or sibling source path; review the upstream diff and revision before running it. Normal builds never reference a sibling directory.

Cluster-specific files are adapters, round-robin arbitration, controller/SRAM, top level, and tests. They do not alter architectural Sparrow-V behavior. SparrowML remains reference-only and is not used in this milestone.
