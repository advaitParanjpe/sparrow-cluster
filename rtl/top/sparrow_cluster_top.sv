module sparrow_cluster_top #(
  parameter integer NUM_CORES = 4, parameter integer MEM_BYTES = 256 * 1024,
  parameter integer READ_LATENCY = 2, parameter integer WRITE_LATENCY = 2,
  parameter PROGRAM_IMAGE = ""
) (input logic clk, input logic rst_n);
  logic [NUM_CORES-1:0] ireq_v, ireq_r, iresp_v, iresp_r, dreq_v, dreq_r, dresp_v, dresp_r, dreq_w;
  logic [NUM_CORES*32-1:0] ireq_a, iresp_d, dreq_a, dreq_wd, dresp_d;
  logic [NUM_CORES*4-1:0] dreq_ws;
  logic [NUM_CORES-1:0] l1req_v, l1req_r, l1resp_v, l1resp_r;
  logic [NUM_CORES*32-1:0] l1req_a, l1resp_d;
  logic [NUM_CORES*64-1:0] l1_accesses, l1_hits, l1_misses, l1_refill_words, l1_miss_stall_cycles;
  logic [NUM_CORES-1:0] l1dreq_v, l1dreq_r, l1dresp_v, l1dresp_r;
  logic [NUM_CORES*32-1:0] l1dreq_a, l1dreq_wd, l1dresp_d;
  logic [NUM_CORES*4-1:0] l1dreq_ws;
  logic [NUM_CORES-1:0] l1dreq_w;
  logic [NUM_CORES*64-1:0] l1d_accesses, l1d_load_accesses, l1d_store_accesses, l1d_hits, l1d_misses, l1d_load_misses, l1d_store_misses, l1d_refill_words, l1d_dirty_writeback_words, l1d_dirty_evictions, l1d_uncached_accesses, l1d_miss_stall_cycles;
  logic [NUM_CORES*64-1:0] l1d_load_hit_s, l1d_load_hit_m, l1d_store_hit_m, l1d_store_upgrades, l1d_bus_rd, l1d_bus_rdx, l1d_bus_upgr, l1d_writebacks, l1d_snoop_hit_s, l1d_snoop_hit_m, l1d_interventions, l1d_invalidations, l1d_downgrades, l1d_ownership_transfers, l1d_coherence_stalls, l1d_protocol_errors;
  logic [NUM_CORES-1:0] coh_req_v, coh_req_r, coh_resp_v, coh_resp_r, coh_wbv, coh_resp_shared, coh_resp_modified, coh_resp_complete, coh_resp_error;
  logic [NUM_CORES*3-1:0] coh_req_cmd;
  logic [NUM_CORES*32-1:0] coh_req_addr;
  logic [NUM_CORES*128-1:0] coh_req_wb_data, coh_resp_data;
  logic [NUM_CORES-1:0] snoop_v, snoop_other, snoop_resp_v, snoop_resp_present, snoop_resp_modified, snoop_resp_data_valid, snoop_resp_inv_ack;
  logic [2:0] snoop_cmd;
  logic [31:0] snoop_addr;
  logic [1:0] snoop_requester;
  logic [NUM_CORES*128-1:0] snoop_resp_data;
  logic coh_mem_v, coh_mem_r, coh_mem_w, coh_mem_rv, coh_mem_rr;
  logic [31:0] coh_mem_a, coh_mem_wd, coh_mem_d;
  logic [3:0] coh_mem_ws;
  logic [63:0] coh_tx_count, coh_bus_rd_count, coh_bus_rdx_count, coh_bus_upgr_count, coh_writeback_count, coh_shared_count, coh_intervention_count, coh_sram_read_count, coh_sram_write_count, coh_ack_count, coh_occupied_cycles, coh_protocol_error_count, coh_timeout_count;
  logic [NUM_CORES*64-1:0] coh_wait_cycles;
  logic [NUM_CORES-1:0] sreq_v, sreq_r, sport, swrite, sresp_v, sresp_r;
  logic [NUM_CORES*32-1:0] saddr, swdata, sresp_d;
  logic [NUM_CORES*4-1:0] swstrb;
  logic [1:0] grant, mresp_core; logic grant_v, mem_req_ready, adapter_mem_ready, mresp_v, mresp_r, mport, mem_pending_coh; logic [31:0] mresp_d;
  genvar g;
  generate for (g=0; g<NUM_CORES; g=g+1) begin: cores
    rv32_core u_core(.clk(clk), .rst_n(rst_n), .imem_req_valid(ireq_v[g]), .imem_req_ready(ireq_r[g]), .imem_req_addr(ireq_a[g*32 +: 32]), .imem_resp_valid(iresp_v[g]), .imem_resp_ready(iresp_r[g]), .imem_resp_data(iresp_d[g*32 +: 32]), .dmem_req_valid(dreq_v[g]), .dmem_req_ready(dreq_r[g]), .dmem_req_write(dreq_w[g]), .dmem_req_addr(dreq_a[g*32 +: 32]), .dmem_req_wdata(dreq_wd[g*32 +: 32]), .dmem_req_wstrb(dreq_ws[g*4 +: 4]), .dmem_resp_valid(dresp_v[g]), .dmem_resp_ready(dresp_r[g]), .dmem_resp_data(dresp_d[g*32 +: 32]), .trap_valid(), .mepc(), .mcause(), .mtvec(), .cycle_count(), .instret_count(), .retire_valid(), .retire_pc(), .retire_instr(), .retire_rd_we(), .retire_rd(), .retire_rd_data(), .retire_mem_we(), .retire_mem_addr(), .retire_mem_data(), .retire_mem_wstrb(), .retire_trap(), .retire_cause(), .imem_stall_cycles(), .dmem_stall_cycles(), .dep_stall_cycles(), .control_flush_cycles());
    l1_instruction_cache u_l1i(.clk(clk), .rst_n(rst_n), .cpu_req_valid(ireq_v[g]), .cpu_req_ready(ireq_r[g]), .cpu_req_addr(ireq_a[g*32 +: 32]), .cpu_resp_valid(iresp_v[g]), .cpu_resp_ready(iresp_r[g]), .cpu_resp_data(iresp_d[g*32 +: 32]), .lower_req_valid(l1req_v[g]), .lower_req_ready(l1req_r[g]), .lower_req_addr(l1req_a[g*32 +: 32]), .lower_resp_valid(l1resp_v[g]), .lower_resp_ready(l1resp_r[g]), .lower_resp_data(l1resp_d[g*32 +: 32]), .access_count(l1_accesses[g*64 +: 64]), .hit_count(l1_hits[g*64 +: 64]), .miss_count(l1_misses[g*64 +: 64]), .refill_word_count(l1_refill_words[g*64 +: 64]), .miss_stall_cycles(l1_miss_stall_cycles[g*64 +: 64]));
    l1_data_cache u_l1d(.clk(clk), .rst_n(rst_n), .cpu_req_valid(dreq_v[g]), .cpu_req_ready(dreq_r[g]), .cpu_req_write(dreq_w[g]), .cpu_req_addr(dreq_a[g*32 +: 32]), .cpu_req_wdata(dreq_wd[g*32 +: 32]), .cpu_req_wstrb(dreq_ws[g*4 +: 4]), .cpu_resp_valid(dresp_v[g]), .cpu_resp_ready(dresp_r[g]), .cpu_resp_data(dresp_d[g*32 +: 32]), .lower_req_valid(l1dreq_v[g]), .lower_req_ready(l1dreq_r[g]), .lower_req_write(l1dreq_w[g]), .lower_req_addr(l1dreq_a[g*32 +: 32]), .lower_req_wdata(l1dreq_wd[g*32 +: 32]), .lower_req_wstrb(l1dreq_ws[g*4 +: 4]), .lower_resp_valid(l1dresp_v[g]), .lower_resp_ready(l1dresp_r[g]), .lower_resp_data(l1dresp_d[g*32 +: 32]),
      .bus_req_valid(coh_req_v[g]), .bus_req_ready(coh_req_r[g]), .bus_req_cmd(coh_req_cmd[g*3 +: 3]), .bus_req_addr(coh_req_addr[g*32 +: 32]), .bus_req_wb_data(coh_req_wb_data[g*128 +: 128]), .bus_req_wb_data_valid(coh_wbv[g]), .bus_resp_valid(coh_resp_v[g]), .bus_resp_ready(coh_resp_r[g]), .bus_resp_data(coh_resp_data[g*128 +: 128]), .bus_resp_shared(coh_resp_shared[g]), .bus_resp_modified(coh_resp_modified[g]), .bus_resp_complete(coh_resp_complete[g]), .bus_resp_error(coh_resp_error[g]),
      .snoop_valid(snoop_v[g]), .snoop_cmd(snoop_cmd), .snoop_addr(snoop_addr), .snoop_requester(snoop_requester), .snoop_other(snoop_other[g]), .snoop_resp_valid(snoop_resp_v[g]), .snoop_resp_present(snoop_resp_present[g]), .snoop_resp_modified(snoop_resp_modified[g]), .snoop_resp_data_valid(snoop_resp_data_valid[g]), .snoop_resp_data(snoop_resp_data[g*128 +: 128]), .snoop_resp_inv_ack(snoop_resp_inv_ack[g]), .msi_state_debug(),
      .access_count(l1d_accesses[g*64 +: 64]), .load_access_count(l1d_load_accesses[g*64 +: 64]), .store_access_count(l1d_store_accesses[g*64 +: 64]), .hit_count(l1d_hits[g*64 +: 64]), .miss_count(l1d_misses[g*64 +: 64]), .load_miss_count(l1d_load_misses[g*64 +: 64]), .store_miss_count(l1d_store_misses[g*64 +: 64]), .refill_word_count(l1d_refill_words[g*64 +: 64]), .dirty_writeback_word_count(l1d_dirty_writeback_words[g*64 +: 64]), .dirty_eviction_count(l1d_dirty_evictions[g*64 +: 64]), .uncached_access_count(l1d_uncached_accesses[g*64 +: 64]), .miss_stall_cycles(l1d_miss_stall_cycles[g*64 +: 64]),
      .load_hit_s_count(l1d_load_hit_s[g*64 +: 64]), .load_hit_m_count(l1d_load_hit_m[g*64 +: 64]), .store_hit_m_count(l1d_store_hit_m[g*64 +: 64]), .store_upgrade_count(l1d_store_upgrades[g*64 +: 64]), .bus_rd_request_count(l1d_bus_rd[g*64 +: 64]), .bus_rdx_request_count(l1d_bus_rdx[g*64 +: 64]), .bus_upgr_request_count(l1d_bus_upgr[g*64 +: 64]), .writeback_count(l1d_writebacks[g*64 +: 64]), .snoop_hit_s_count(l1d_snoop_hit_s[g*64 +: 64]), .snoop_hit_m_count(l1d_snoop_hit_m[g*64 +: 64]), .intervention_count(l1d_interventions[g*64 +: 64]), .invalidation_count(l1d_invalidations[g*64 +: 64]), .downgrade_count(l1d_downgrades[g*64 +: 64]), .ownership_transfer_count(l1d_ownership_transfers[g*64 +: 64]), .coherence_stall_cycles(l1d_coherence_stalls[g*64 +: 64]), .protocol_error_count(l1d_protocol_errors[g*64 +: 64]));
    core_adapter #(.CORE_ID(g)) u_adapter(.clk(clk), .rst_n(rst_n), .imem_req_valid(l1req_v[g]), .imem_req_ready(l1req_r[g]), .imem_req_addr(l1req_a[g*32 +: 32]), .imem_resp_valid(l1resp_v[g]), .imem_resp_ready(l1resp_r[g]), .imem_resp_data(l1resp_d[g*32 +: 32]), .dmem_req_valid(l1dreq_v[g]), .dmem_req_ready(l1dreq_r[g]), .dmem_req_write(l1dreq_w[g]), .dmem_req_addr(l1dreq_a[g*32 +: 32]), .dmem_req_wdata(l1dreq_wd[g*32 +: 32]), .dmem_req_wstrb(l1dreq_ws[g*4 +: 4]), .dmem_resp_valid(l1dresp_v[g]), .dmem_resp_ready(l1dresp_r[g]), .dmem_resp_data(l1dresp_d[g*32 +: 32]), .sys_req_valid(sreq_v[g]), .sys_req_ready(sreq_r[g]), .sys_req_port(sport[g]), .sys_req_write(swrite[g]), .sys_req_addr(saddr[g*32 +: 32]), .sys_req_wdata(swdata[g*32 +: 32]), .sys_req_wstrb(swstrb[g*4 +: 4]), .sys_resp_valid(sresp_v[g]), .sys_resp_data(sresp_d[g*32 +: 32]), .sys_resp_ready(sresp_r[g]));
  end endgenerate
  snoopy_coherence_transport #(.NUM_CORES(NUM_CORES)) u_coh(.clk(clk), .rst_n(rst_n),
    .req_valid(coh_req_v), .req_ready(coh_req_r), .req_cmd(coh_req_cmd), .req_addr(coh_req_addr), .req_wb_data(coh_req_wb_data), .req_wb_data_valid(coh_wbv),
    .req_resp_valid(coh_resp_v), .req_resp_ready(coh_resp_r), .req_resp_data(coh_resp_data), .req_resp_shared(coh_resp_shared), .req_resp_modified(coh_resp_modified), .req_resp_complete(coh_resp_complete), .req_resp_error(coh_resp_error),
    .snoop_valid(snoop_v), .snoop_cmd(snoop_cmd), .snoop_addr(snoop_addr), .snoop_requester(snoop_requester), .snoop_other(snoop_other),
    .snoop_resp_valid(snoop_resp_v), .snoop_resp_present(snoop_resp_present), .snoop_resp_modified(snoop_resp_modified), .snoop_resp_data_valid(snoop_resp_data_valid), .snoop_resp_data(snoop_resp_data), .snoop_resp_inv_ack(snoop_resp_inv_ack),
    .mem_req_valid(coh_mem_v), .mem_req_ready(coh_mem_r), .mem_req_write(coh_mem_w), .mem_req_addr(coh_mem_a), .mem_req_wdata(coh_mem_wd), .mem_req_wstrb(coh_mem_ws), .mem_resp_valid(coh_mem_rv), .mem_resp_ready(coh_mem_rr), .mem_resp_data(coh_mem_d),
    .transaction_count(coh_tx_count), .bus_rd_count(coh_bus_rd_count), .bus_rdx_count(coh_bus_rdx_count), .bus_upgr_count(coh_bus_upgr_count), .writeback_count(coh_writeback_count),
    .shared_transaction_count(coh_shared_count), .intervention_count(coh_intervention_count), .sram_block_read_count(coh_sram_read_count), .sram_block_write_count(coh_sram_write_count), .invalidation_ack_count(coh_ack_count),
    .occupied_cycle_count(coh_occupied_cycles), .protocol_error_count(coh_protocol_error_count), .timeout_count(coh_timeout_count), .arbitration_wait_cycles(coh_wait_cycles));

  round_robin_arbiter #(.N(NUM_CORES)) u_arb(.clk(clk), .rst_n(rst_n), .req(sreq_v), .grant_accept(grant_v && adapter_mem_ready), .grant_valid(grant_v), .grant(grant));
  always_comb begin
    adapter_mem_ready = (!coh_mem_v) && mem_req_ready;
    coh_mem_r = coh_mem_v && mem_req_ready;
    sreq_r = '0; if (grant_v) sreq_r[grant] = adapter_mem_ready;
    sresp_v = '0; sresp_d = '0; coh_mem_rv = 1'b0; coh_mem_d = mresp_d; mresp_r = 1'b0;
    if (mresp_v && mem_pending_coh) begin coh_mem_rv = 1'b1; mresp_r = coh_mem_rr; end
    else if (mresp_v) begin sresp_v[mresp_core] = 1'b1; sresp_d[mresp_core*32 +: 32] = mresp_d; mresp_r = sresp_r[mresp_core]; end
  end
  shared_memory_controller #(.MEM_BYTES(MEM_BYTES), .READ_LATENCY(READ_LATENCY), .WRITE_LATENCY(WRITE_LATENCY), .PROGRAM_IMAGE(PROGRAM_IMAGE)) u_mem(.clk(clk), .rst_n(rst_n),
    .req_valid(coh_mem_v || grant_v), .req_ready(mem_req_ready), .req_core(coh_mem_v ? 2'd0 : grant), .req_port(coh_mem_v ? 1'b1 : sport[grant]), .req_write(coh_mem_v ? coh_mem_w : swrite[grant]), .req_addr(coh_mem_v ? coh_mem_a : saddr[grant*32 +: 32]), .req_wdata(coh_mem_v ? coh_mem_wd : swdata[grant*32 +: 32]), .req_wstrb(coh_mem_v ? coh_mem_ws : swstrb[grant*4 +: 4]),
    .resp_valid(mresp_v), .resp_ready(mresp_r), .resp_core(mresp_core), .resp_port(mport), .resp_data(mresp_d));
  always_ff @(posedge clk) begin
    if (!rst_n) mem_pending_coh <= 1'b0;
    else if ((coh_mem_v || grant_v) && mem_req_ready) mem_pending_coh <= coh_mem_v;
  end
  always_ff @(posedge clk) if (rst_n) begin
    assert (!(mresp_v && (mresp_core >= NUM_CORES))) else $error("response core out of range");
    assert (!(mresp_v && !mem_pending_coh && !(sresp_v[mresp_core]))) else $error("response was not routed to its source");
  end
endmodule
