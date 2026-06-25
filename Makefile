PYTHON ?= python3

.PHONY: check docs-check tree milestone-check milestone-run milestone-status sparrowml-package-check sparrowml-import-check sparrowml-build sparrowml-reference-check sim-sparrowml-single sim-sparrowml-scaling sim-sparrowml-shared sim-sparrowml-layout sim-sparrowml sw-check sw-build sw-disasm sim-unit sim-l1i sim-l1d sim-snoop-transport sim-msi sim-coherence-random sim-lrsc sim-atomic-random sim-runtime sim-counter sim-lock sim-barrier sim-workloads sim-cluster sim-multicore regress
IVERILOG ?= iverilog
VVP ?= vvp
RTL = rtl/core/imported/sparrowv_scalar_pkg.sv rtl/core/imported/rv32_alu.sv rtl/core/imported/rv32_decoder.sv rtl/core/imported/rv32_immediate.sv rtl/core/imported/rv32_regfile.sv rtl/core/imported/rv32_core.sv rtl/interconnect/coherence_pkg.sv rtl/cache/l1_instruction_cache.sv rtl/cache/l1_data_cache.sv rtl/interconnect/core_adapter.sv rtl/interconnect/round_robin_arbiter.sv rtl/interconnect/snoopy_coherence_transport.sv rtl/memory/shared_memory_controller.sv rtl/top/sparrow_cluster_top.sv
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

sparrowml-package-check:
	$(PYTHON) scripts/sparrowml_package.py package-check

sparrowml-import-check:
	$(PYTHON) scripts/sparrowml_package.py import-check

sparrowml-build: sparrowml-package-check sparrowml-reference-check sw-build
	$(PYTHON) scripts/sparrowml_package.py build

sparrowml-reference-check:
	$(PYTHON) scripts/sparrowml_package.py reference-check

sw-check:
	$(PYTHON) scripts/build_runtime_sw.py check

sw-build:
	$(PYTHON) scripts/build_runtime_sw.py build

sw-disasm:
	$(PYTHON) scripts/build_runtime_sw.py disasm

sim-unit:
	@mkdir -p /tmp/sparrow-cluster-sim
	$(IVERILOG) -g2012 -s tb_m1_unit -o /tmp/sparrow-cluster-sim/unit.vvp rtl/interconnect/core_adapter.sv rtl/interconnect/round_robin_arbiter.sv rtl/memory/shared_memory_controller.sv tb/unit/tb_m1_unit.sv
	$(VVP) /tmp/sparrow-cluster-sim/unit.vvp

sim-l1i:
	@mkdir -p /tmp/sparrow-cluster-sim
	$(IVERILOG) -g2012 -s tb_l1i -o /tmp/sparrow-cluster-sim/l1i.vvp rtl/cache/l1_instruction_cache.sv tb/unit/tb_l1i.sv
	$(VVP) /tmp/sparrow-cluster-sim/l1i.vvp

sim-l1d:
	@mkdir -p /tmp/sparrow-cluster-sim
	$(IVERILOG) -g2012 -s tb_l1d -o /tmp/sparrow-cluster-sim/l1d.vvp rtl/interconnect/coherence_pkg.sv rtl/cache/l1_data_cache.sv rtl/interconnect/snoopy_coherence_transport.sv tb/unit/tb_l1d.sv
	$(VVP) /tmp/sparrow-cluster-sim/l1d.vvp

sim-snoop-transport:
	@mkdir -p /tmp/sparrow-cluster-sim
	$(IVERILOG) -g2012 -s tb_snoopy_transport -o /tmp/sparrow-cluster-sim/snoop.vvp rtl/interconnect/coherence_pkg.sv rtl/interconnect/snoopy_coherence_transport.sv tb/unit/tb_snoopy_transport.sv
	$(VVP) /tmp/sparrow-cluster-sim/snoop.vvp

sim-msi:
	@mkdir -p /tmp/sparrow-cluster-sim
	$(IVERILOG) -g2012 -s tb_msi_coherence -o /tmp/sparrow-cluster-sim/msi.vvp rtl/interconnect/coherence_pkg.sv rtl/cache/l1_data_cache.sv rtl/interconnect/snoopy_coherence_transport.sv tb/coherence/tb_msi_coherence.sv
	$(VVP) /tmp/sparrow-cluster-sim/msi.vvp

sim-coherence-random:
	@mkdir -p /tmp/sparrow-cluster-sim
	$(IVERILOG) -g2012 -s tb_coherence_random -o /tmp/sparrow-cluster-sim/coherence_random.vvp rtl/interconnect/coherence_pkg.sv rtl/cache/l1_data_cache.sv rtl/interconnect/snoopy_coherence_transport.sv tb/coherence/tb_coherence_random.sv
	$(VVP) /tmp/sparrow-cluster-sim/coherence_random.vvp

sim-lrsc:
	@mkdir -p /tmp/sparrow-cluster-sim
	$(IVERILOG) -g2012 -s tb_lrsc_decode -o /tmp/sparrow-cluster-sim/lrsc_decode.vvp rtl/core/imported/sparrowv_scalar_pkg.sv rtl/core/imported/rv32_decoder.sv tb/unit/tb_lrsc_decode.sv
	$(VVP) /tmp/sparrow-cluster-sim/lrsc_decode.vvp
	$(IVERILOG) -g2012 -s tb_lrsc_coherence -o /tmp/sparrow-cluster-sim/lrsc_coherence.vvp rtl/interconnect/coherence_pkg.sv rtl/cache/l1_data_cache.sv rtl/interconnect/snoopy_coherence_transport.sv tb/coherence/tb_lrsc_coherence.sv
	$(VVP) /tmp/sparrow-cluster-sim/lrsc_coherence.vvp
sim-atomic-random:
	@mkdir -p /tmp/sparrow-cluster-sim
	$(IVERILOG) -g2012 -s tb_atomic_random -o /tmp/sparrow-cluster-sim/atomic_random.vvp rtl/interconnect/coherence_pkg.sv rtl/cache/l1_data_cache.sv rtl/interconnect/snoopy_coherence_transport.sv tb/coherence/tb_atomic_random.sv
	$(VVP) /tmp/sparrow-cluster-sim/atomic_random.vvp

define run_runtime_case
	@mkdir -p /tmp/sparrow-cluster-sim
	$(IVERILOG) -g2012 -s tb_runtime_workload -DPROGRAM_IMAGE=\"build/sw/images/$(1).hex\" -DWORKLOAD_ID=$(2) -DACTIVE_CORES=$(3) -DEXPECTED_RESULT=$(4) -DTIMEOUT_CYCLES=$(5) -o /tmp/sparrow-cluster-sim/$(1).vvp $(RTL) tb/system/tb_runtime_workload.sv
	$(VVP) /tmp/sparrow-cluster-sim/$(1).vvp
endef

sim-runtime: sw-build
	$(call run_runtime_case,runtime_1c,1,1,28672,80000)
	$(call run_runtime_case,runtime_2c,1,2,28673,80000)
	$(call run_runtime_case,runtime_4c,1,4,28675,80000)

sim-counter: sw-build
	$(call run_runtime_case,counter_1c,2,1,8,120000)
	$(call run_runtime_case,counter_2c,2,2,16,120000)
	$(call run_runtime_case,counter_4c,2,4,32,120000)

sim-lock: sw-build
	$(call run_runtime_case,lock_4c,3,4,24,160000)

sim-barrier: sw-build
	$(call run_runtime_case,barrier_1c,4,1,5,160000)
	$(call run_runtime_case,barrier_2c,4,2,10,160000)
	$(call run_runtime_case,barrier_4c,4,4,20,160000)

sim-workloads: sw-build
	$(call run_runtime_case,prodcons_2c,5,2,6,180000)
	$(call run_runtime_case,reduction_1c,6,1,36,120000)
	$(call run_runtime_case,reduction_2c,6,2,36,120000)
	$(call run_runtime_case,reduction_4c,6,4,36,120000)
	$(call run_runtime_case,pingpong_2c,7,2,12,180000)
	$(call run_runtime_case,false_4c,8,4,24,160000)
	$(call run_runtime_case,padded_4c,9,4,24,160000)
	$(call run_runtime_case,readmostly_1c,10,1,784,120000)
	$(call run_runtime_case,readmostly_2c,10,2,1568,120000)
	$(call run_runtime_case,readmostly_4c,10,4,3136,120000)
	$(call run_runtime_case,mixed_1c,11,1,4,180000)
	$(call run_runtime_case,mixed_2c,11,2,8,180000)
	$(call run_runtime_case,mixed_4c,11,4,16,180000)

sim-sparrowml-single: sparrowml-build
	$(call run_runtime_case,sparrowml_sample_1c,20,1,18,240000)

sim-sparrowml-scaling: sparrowml-build
	$(call run_runtime_case,sparrowml_sample_1c,20,1,18,240000)
	$(call run_runtime_case,sparrowml_sample_2c,20,2,18,240000)
	$(call run_runtime_case,sparrowml_sample_4c,20,4,18,240000)

sim-sparrowml-shared: sparrowml-build
	$(call run_runtime_case,sparrowml_shared_2c,21,2,1,220000)
	$(call run_runtime_case,sparrowml_shared_4c,21,4,1,220000)

sim-sparrowml-layout: sparrowml-build
	$(call run_runtime_case,sparrowml_layout_safe_4c,22,4,18,240000)
	$(call run_runtime_case,sparrowml_layout_poor_4c,23,4,18,240000)

sim-sparrowml: sim-sparrowml-single sim-sparrowml-scaling sim-sparrowml-shared sim-sparrowml-layout

sim-cluster:
	@mkdir -p /tmp/sparrow-cluster-sim
	$(IVERILOG) -g2012 -s tb_cluster -o /tmp/sparrow-cluster-sim/cluster.vvp $(RTL) tb/system/tb_cluster.sv
	$(VVP) /tmp/sparrow-cluster-sim/cluster.vvp

sim-multicore:
	@mkdir -p /tmp/sparrow-cluster-sim
	$(IVERILOG) -g2012 -s tb_m1_multicore -o /tmp/sparrow-cluster-sim/multicore.vvp $(RTL) tb/system/tb_m1_multicore.sv
	$(VVP) /tmp/sparrow-cluster-sim/multicore.vvp

regress: check docs-check sparrowml-package-check sparrowml-import-check sparrowml-build sparrowml-reference-check sw-check sw-build sw-disasm sim-unit sim-l1i sim-l1d sim-snoop-transport sim-msi sim-coherence-random sim-lrsc sim-atomic-random sim-runtime sim-counter sim-lock sim-barrier sim-workloads sim-sparrowml sim-cluster sim-multicore
