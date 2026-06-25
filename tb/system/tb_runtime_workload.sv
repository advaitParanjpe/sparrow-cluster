module tb_runtime_workload;
`ifndef PROGRAM_IMAGE
`define PROGRAM_IMAGE "build/sw/images/runtime_4c.hex"
`endif
`ifndef WORKLOAD_ID
`define WORKLOAD_ID 1
`endif
`ifndef ACTIVE_CORES
`define ACTIVE_CORES 4
`endif
`ifndef EXPECTED_RESULT
`define EXPECTED_RESULT 28675
`endif
`ifndef TIMEOUT_CYCLES
`define TIMEOUT_CYCLES 80000
`endif

  localparam integer WORKLOAD = `WORKLOAD_ID;
  localparam integer ACTIVE = `ACTIVE_CORES;
  localparam integer EXPECTED = `EXPECTED_RESULT;
  localparam integer TIMEOUT = `TIMEOUT_CYCLES;

  logic clk = 0, rst_n = 0;
  integer cycles, hart;

  sparrow_cluster_top #(
    .MEM_BYTES(65536),
    .READ_LATENCY(2),
    .WRITE_LATENCY(2),
    .PROGRAM_IMAGE(`PROGRAM_IMAGE)
  ) dut(.clk, .rst_n);

  always #5 clk = ~clk;

  function automatic [31:0] word(input integer addr);
    word = {dut.u_mem.mem[addr+3], dut.u_mem.mem[addr+2], dut.u_mem.mem[addr+1], dut.u_mem.mem[addr]};
  endfunction

  function automatic [63:0] l1d_sum(input logic [255:0] counters);
    integer i;
    begin
      l1d_sum = 0;
      for (i = 0; i < 4; i = i + 1) l1d_sum = l1d_sum + counters[i*64 +: 64];
    end
  endfunction

  initial begin
    repeat (3) @(posedge clk);
    rst_n = 1;
    for (cycles = 0; cycles < TIMEOUT; cycles = cycles + 1) begin
      @(posedge clk);
      if ((ACTIVE == 1 && word(32'h600) == 1) ||
          (ACTIVE == 2 && word(32'h600) == 1 && word(32'h604) == 1) ||
          (ACTIVE == 4 && word(32'h600) == 1 && word(32'h604) == 1 && word(32'h608) == 1 && word(32'h60c) == 1)) break;
    end
    if (cycles == TIMEOUT) begin
      $display("TIMEOUT workload=%0d active=%0d done=%h,%h,%h,%h release=%h result=%h failures=%h tx=%0d",
               WORKLOAD, ACTIVE, word(32'h600), word(32'h604), word(32'h608), word(32'h60c),
               word(32'h308), word(32'h204), word(32'h20c), dut.coh_tx_count);
      $display("PC/trap h0 pc=%h if=%h mw=%h trap=%b mepc=%h cause=%h dmem_v=%b dmem_a=%h l1d_state=%0d",
               dut.cores[0].u_core.pc, dut.cores[0].u_core.if_pc, dut.cores[0].u_core.mw_pc,
               dut.cores[0].u_core.trap_valid, dut.cores[0].u_core.mepc, dut.cores[0].u_core.mcause,
               dut.dreq_v[0], dut.dreq_a[31:0], dut.cores[0].u_l1d.state);
      $display("PC/trap h1 pc=%h if=%h mw=%h trap=%b mepc=%h cause=%h dmem_v=%b dmem_a=%h l1d_state=%0d",
               dut.cores[1].u_core.pc, dut.cores[1].u_core.if_pc, dut.cores[1].u_core.mw_pc,
               dut.cores[1].u_core.trap_valid, dut.cores[1].u_core.mepc, dut.cores[1].u_core.mcause,
               dut.dreq_v[1], dut.dreq_a[63:32], dut.cores[1].u_l1d.state);
      $fatal(1, "runtime workload timeout");
    end

    if (word(32'h200) !== 32'hc1a57e07) $fatal(1, "bad result magic workload=%0d got=%h", WORKLOAD, word(32'h200));
    if (word(32'h208) !== ACTIVE[31:0]) $fatal(1, "bad active count workload=%0d got=%0d", WORKLOAD, word(32'h208));
    if (word(32'h20c) !== 0) $fatal(1, "software failure flag workload=%0d failures=%h", WORKLOAD, word(32'h20c));

    if (WORKLOAD == 1) begin
      for (hart = 0; hart < ACTIVE; hart = hart + 1) begin
        if (word(32'h400 + 4*hart) !== (32'h7000 + hart)) $fatal(1, "smoke per-hart result hart=%0d got=%h", hart, word(32'h400 + 4*hart));
      end
    end else begin
      if (word(32'h204) !== EXPECTED[31:0]) $fatal(1, "bad workload result id=%0d expected=%0d got=%0d", WORKLOAD, EXPECTED, word(32'h204));
    end

    for (hart = 0; hart < ACTIVE; hart = hart + 1) begin
      if (dut.l1d_accesses[hart*64 +: 64] == 0) $fatal(1, "no L1D activity hart=%0d workload=%0d", hart, WORKLOAD);
    end
    if ((WORKLOAD == 2 || WORKLOAD == 3 || WORKLOAD == 4 || WORKLOAD == 11) &&
        (dut.cores[0].u_l1d.lr_attempt_count == 0 || dut.cores[0].u_l1d.sc_attempt_count == 0))
      $fatal(1, "missing LR/SC activity workload=%0d", WORKLOAD);
    if ((WORKLOAD == 7 || WORKLOAD == 8 || WORKLOAD == 9) && dut.coh_tx_count == 0)
      $fatal(1, "missing coherence traffic workload=%0d", WORKLOAD);
    if (WORKLOAD >= 20 && dut.coh_tx_count == 0)
      $fatal(1, "missing SparrowML coherence traffic workload=%0d", WORKLOAD);

    $display("PASS runtime workload=%0d active=%0d cycles=%0d result=%0d tx=%0d rd=%0d rdx=%0d upgr=%0d inv=%0d int=%0d lr0=%0d sc0=%0d l1d_hits=%0d l1d_misses=%0d",
             WORKLOAD, ACTIVE, cycles, word(32'h204), dut.coh_tx_count, dut.coh_bus_rd_count,
             dut.coh_bus_rdx_count, dut.coh_bus_upgr_count, l1d_sum(dut.l1d_invalidations),
             l1d_sum(dut.l1d_interventions), dut.cores[0].u_l1d.lr_attempt_count,
             dut.cores[0].u_l1d.sc_attempt_count, l1d_sum(dut.l1d_hits), l1d_sum(dut.l1d_misses));
    $finish;
  end
endmodule
