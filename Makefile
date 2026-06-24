PYTHON ?= python3

.PHONY: check docs-check tree milestone-check milestone-run milestone-status sim-unit sim-l1i sim-cluster sim-multicore regress
IVERILOG ?= iverilog
VVP ?= vvp
RTL = rtl/core/imported/sparrowv_scalar_pkg.sv rtl/core/imported/rv32_alu.sv rtl/core/imported/rv32_decoder.sv rtl/core/imported/rv32_immediate.sv rtl/core/imported/rv32_regfile.sv rtl/core/imported/rv32_core.sv rtl/cache/l1_instruction_cache.sv rtl/interconnect/core_adapter.sv rtl/interconnect/round_robin_arbiter.sv rtl/memory/shared_memory_controller.sv rtl/top/sparrow_cluster_top.sv
check:
	$(PYTHON) scripts/check_repo.py

docs-check:
	$(PYTHON) scripts/check_repo.py --docs-only

tree:
	$(PYTHON) scripts/check_repo.py --tree

milestone-check:
	$(PYTHON) scripts/check_milestone.py

milestone-run:
	bash scripts/run_milestone.sh

milestone-status:
	bash scripts/run_milestone.sh --status

sim-unit:
	@mkdir -p /tmp/sparrow-cluster-sim
	$(IVERILOG) -g2012 -s tb_m1_unit -o /tmp/sparrow-cluster-sim/unit.vvp rtl/interconnect/core_adapter.sv rtl/interconnect/round_robin_arbiter.sv rtl/memory/shared_memory_controller.sv tb/unit/tb_m1_unit.sv
	$(VVP) /tmp/sparrow-cluster-sim/unit.vvp

sim-l1i:
	@mkdir -p /tmp/sparrow-cluster-sim
	$(IVERILOG) -g2012 -s tb_l1i -o /tmp/sparrow-cluster-sim/l1i.vvp rtl/cache/l1_instruction_cache.sv tb/unit/tb_l1i.sv
	$(VVP) /tmp/sparrow-cluster-sim/l1i.vvp

sim-cluster:
	@mkdir -p /tmp/sparrow-cluster-sim
	$(IVERILOG) -g2012 -s tb_cluster -o /tmp/sparrow-cluster-sim/cluster.vvp $(RTL) tb/system/tb_cluster.sv
	$(VVP) /tmp/sparrow-cluster-sim/cluster.vvp

sim-multicore:
	@mkdir -p /tmp/sparrow-cluster-sim
	$(IVERILOG) -g2012 -s tb_m1_multicore -o /tmp/sparrow-cluster-sim/multicore.vvp $(RTL) tb/system/tb_m1_multicore.sv
	$(VVP) /tmp/sparrow-cluster-sim/multicore.vvp

regress: check docs-check sim-unit sim-l1i sim-cluster sim-multicore
