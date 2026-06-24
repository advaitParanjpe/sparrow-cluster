module sparrow_cluster_top #(
  parameter integer NUM_CORES = 4, parameter integer MEM_BYTES = 256 * 1024,
  parameter integer READ_LATENCY = 2, parameter integer WRITE_LATENCY = 2,
  parameter PROGRAM_IMAGE = ""
) (input logic clk, input logic rst_n);
  logic [NUM_CORES-1:0] ireq_v, ireq_r, iresp_v, iresp_r, dreq_v, dreq_r, dresp_v, dresp_r, dreq_w;
  logic [NUM_CORES*32-1:0] ireq_a, iresp_d, dreq_a, dreq_wd, dresp_d;
  logic [NUM_CORES*4-1:0] dreq_ws;
  logic [NUM_CORES-1:0] sreq_v, sreq_r, sport, swrite, sresp_v, sresp_r;
  logic [NUM_CORES*32-1:0] saddr, swdata, sresp_d;
  logic [NUM_CORES*4-1:0] swstrb;
  logic [1:0] grant, mresp_core; logic grant_v, mreq_r, mresp_v, mresp_r, mport; logic [31:0] mresp_d;
  genvar g;
  generate for (g=0; g<NUM_CORES; g=g+1) begin: cores
    rv32_core u_core(.clk(clk), .rst_n(rst_n), .imem_req_valid(ireq_v[g]), .imem_req_ready(ireq_r[g]), .imem_req_addr(ireq_a[g*32 +: 32]), .imem_resp_valid(iresp_v[g]), .imem_resp_ready(iresp_r[g]), .imem_resp_data(iresp_d[g*32 +: 32]), .dmem_req_valid(dreq_v[g]), .dmem_req_ready(dreq_r[g]), .dmem_req_write(dreq_w[g]), .dmem_req_addr(dreq_a[g*32 +: 32]), .dmem_req_wdata(dreq_wd[g*32 +: 32]), .dmem_req_wstrb(dreq_ws[g*4 +: 4]), .dmem_resp_valid(dresp_v[g]), .dmem_resp_ready(dresp_r[g]), .dmem_resp_data(dresp_d[g*32 +: 32]), .trap_valid(), .mepc(), .mcause(), .mtvec(), .cycle_count(), .instret_count(), .retire_valid(), .retire_pc(), .retire_instr(), .retire_rd_we(), .retire_rd(), .retire_rd_data(), .retire_mem_we(), .retire_mem_addr(), .retire_mem_data(), .retire_mem_wstrb(), .retire_trap(), .retire_cause(), .imem_stall_cycles(), .dmem_stall_cycles(), .dep_stall_cycles(), .control_flush_cycles());
    core_adapter #(.CORE_ID(g)) u_adapter(.clk(clk), .rst_n(rst_n), .imem_req_valid(ireq_v[g]), .imem_req_ready(ireq_r[g]), .imem_req_addr(ireq_a[g*32 +: 32]), .imem_resp_valid(iresp_v[g]), .imem_resp_ready(iresp_r[g]), .imem_resp_data(iresp_d[g*32 +: 32]), .dmem_req_valid(dreq_v[g]), .dmem_req_ready(dreq_r[g]), .dmem_req_write(dreq_w[g]), .dmem_req_addr(dreq_a[g*32 +: 32]), .dmem_req_wdata(dreq_wd[g*32 +: 32]), .dmem_req_wstrb(dreq_ws[g*4 +: 4]), .dmem_resp_valid(dresp_v[g]), .dmem_resp_ready(dresp_r[g]), .dmem_resp_data(dresp_d[g*32 +: 32]), .sys_req_valid(sreq_v[g]), .sys_req_ready(sreq_r[g]), .sys_req_port(sport[g]), .sys_req_write(swrite[g]), .sys_req_addr(saddr[g*32 +: 32]), .sys_req_wdata(swdata[g*32 +: 32]), .sys_req_wstrb(swstrb[g*4 +: 4]), .sys_resp_valid(sresp_v[g]), .sys_resp_data(sresp_d[g*32 +: 32]), .sys_resp_ready(sresp_r[g]));
  end endgenerate
  round_robin_arbiter #(.N(NUM_CORES)) u_arb(.clk(clk), .rst_n(rst_n), .req(sreq_v), .grant_accept(grant_v && mreq_r), .grant_valid(grant_v), .grant(grant));
  always_comb begin
    sreq_r = '0; if (grant_v) sreq_r[grant] = mreq_r;
    sresp_v = '0; sresp_d = '0; mresp_r = 1'b0;
    if (mresp_v) begin sresp_v[mresp_core] = 1'b1; sresp_d[mresp_core*32 +: 32] = mresp_d; mresp_r = sresp_r[mresp_core]; end
  end
  shared_memory_controller #(.MEM_BYTES(MEM_BYTES), .READ_LATENCY(READ_LATENCY), .WRITE_LATENCY(WRITE_LATENCY), .PROGRAM_IMAGE(PROGRAM_IMAGE)) u_mem(.clk(clk), .rst_n(rst_n), .req_valid(grant_v), .req_ready(mreq_r), .req_core(grant), .req_port(sport[grant]), .req_write(swrite[grant]), .req_addr(saddr[grant*32 +: 32]), .req_wdata(swdata[grant*32 +: 32]), .req_wstrb(swstrb[grant*4 +: 4]), .resp_valid(mresp_v), .resp_ready(mresp_r), .resp_core(mresp_core), .resp_port(mport), .resp_data(mresp_d));
  always_ff @(posedge clk) if (rst_n) begin
    assert (!(mresp_v && (mresp_core >= NUM_CORES))) else $error("response core out of range");
    assert (!(mresp_v && !(sresp_v[mresp_core]))) else $error("response was not routed to its source");
  end
endmodule
