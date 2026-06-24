#!/usr/bin/env sh
# Synchronize exactly the reviewed scalar-core closure.  Run from repository root.
set -eu
src=${1:-../sparrow-v}
test -f "$src/rtl/core/rv32_core.sv"
mkdir -p rtl/core/imported
cp "$src/rtl/common/sparrowv_scalar_pkg.sv" rtl/core/imported/
cp "$src/rtl/core/rv32_core.sv" "$src/rtl/core/rv32_alu.sv" "$src/rtl/core/rv32_decoder.sv" "$src/rtl/core/rv32_immediate.sv" "$src/rtl/core/rv32_regfile.sv" rtl/core/imported/
