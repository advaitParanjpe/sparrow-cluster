module tb_msi_coherence;
  import coherence_pkg::*;
  logic clk=0,rst_n=0;
  logic [3:0] cpu_v,cpu_r,cpu_w,cpu_rv,cpu_rr; logic [127:0] cpu_a,cpu_wd,cpu_d; logic [15:0] cpu_ws;
  logic [3:0] low_v,low_r,low_w,low_rv,low_rr; logic [127:0] low_a,low_wd,low_d; logic [15:0] low_ws;
  logic [3:0] bus_v,bus_r,bus_rv,bus_rr,bus_shared,bus_mod,bus_comp,bus_err,bus_wbv;
  logic [11:0] bus_cmd; logic [127:0] bus_a; logic [511:0] bus_wb,bus_d;
  logic [3:0] sv,sother,srv,srp,srm,srd,sra; logic [2:0] scmd; logic [31:0] sa; logic [1:0] sid; logic [511:0] srdata;
  logic mv,mr,mw,mrv,mrr; logic [31:0] ma,mwd,md; logic [3:0] mws;
  logic [255:0] accesses,loads,stores,hits,misses,load_misses,store_misses,refills,wb_words,evictions,uncached,stalls;
  logic [255:0] lhs,lhm,shm,sup,brd,brdx,bup,wb,shs,shm_snoop,interv,invals,downgrades,owners,cstalls,perr;
  logic [1023:0] msi_dbg;
  logic [63:0] tx,tx_brd,tx_brdx,tx_bup,tx_wb,tx_shared,tx_interv,sreads,swrites,acks,occupied,tx_perr,timeouts; logic [255:0] waits;
  logic [31:0] mem[0:4095], saved_a, saved_d; logic saved_w,pending; integer i, cycles;

  genvar g;
  generate for(g=0; g<4; g=g+1) begin: caches
    l1_data_cache u_l1d(.clk,.rst_n,.cpu_req_valid(cpu_v[g]),.cpu_req_ready(cpu_r[g]),.cpu_req_write(cpu_w[g]),.cpu_req_addr(cpu_a[g*32 +: 32]),.cpu_req_wdata(cpu_wd[g*32 +: 32]),.cpu_req_wstrb(cpu_ws[g*4 +: 4]),.cpu_resp_valid(cpu_rv[g]),.cpu_resp_ready(cpu_rr[g]),.cpu_resp_data(cpu_d[g*32 +: 32]),
      .lower_req_valid(low_v[g]),.lower_req_ready(low_r[g]),.lower_req_write(low_w[g]),.lower_req_addr(low_a[g*32 +: 32]),.lower_req_wdata(low_wd[g*32 +: 32]),.lower_req_wstrb(low_ws[g*4 +: 4]),.lower_resp_valid(low_rv[g]),.lower_resp_ready(low_rr[g]),.lower_resp_data(low_d[g*32 +: 32]),
      .bus_req_valid(bus_v[g]),.bus_req_ready(bus_r[g]),.bus_req_cmd(bus_cmd[g*3 +: 3]),.bus_req_addr(bus_a[g*32 +: 32]),.bus_req_wb_data(bus_wb[g*128 +: 128]),.bus_req_wb_data_valid(bus_wbv[g]),.bus_resp_valid(bus_rv[g]),.bus_resp_ready(bus_rr[g]),.bus_resp_data(bus_d[g*128 +: 128]),.bus_resp_shared(bus_shared[g]),.bus_resp_modified(bus_mod[g]),.bus_resp_complete(bus_comp[g]),.bus_resp_error(bus_err[g]),
      .snoop_valid(sv[g]),.snoop_cmd(scmd),.snoop_addr(sa),.snoop_requester(sid),.snoop_other(sother[g]),.snoop_resp_valid(srv[g]),.snoop_resp_present(srp[g]),.snoop_resp_modified(srm[g]),.snoop_resp_data_valid(srd[g]),.snoop_resp_data(srdata[g*128 +: 128]),.snoop_resp_inv_ack(sra[g]),.msi_state_debug(msi_dbg[g*256 +: 256]),
      .access_count(accesses[g*64 +: 64]),.load_access_count(loads[g*64 +: 64]),.store_access_count(stores[g*64 +: 64]),.hit_count(hits[g*64 +: 64]),.miss_count(misses[g*64 +: 64]),.load_miss_count(load_misses[g*64 +: 64]),.store_miss_count(store_misses[g*64 +: 64]),.refill_word_count(refills[g*64 +: 64]),.dirty_writeback_word_count(wb_words[g*64 +: 64]),.dirty_eviction_count(evictions[g*64 +: 64]),.uncached_access_count(uncached[g*64 +: 64]),.miss_stall_cycles(stalls[g*64 +: 64]),
      .load_hit_s_count(lhs[g*64 +: 64]),.load_hit_m_count(lhm[g*64 +: 64]),.store_hit_m_count(shm[g*64 +: 64]),.store_upgrade_count(sup[g*64 +: 64]),.bus_rd_request_count(brd[g*64 +: 64]),.bus_rdx_request_count(brdx[g*64 +: 64]),.bus_upgr_request_count(bup[g*64 +: 64]),.writeback_count(wb[g*64 +: 64]),.snoop_hit_s_count(shs[g*64 +: 64]),.snoop_hit_m_count(shm_snoop[g*64 +: 64]),.intervention_count(interv[g*64 +: 64]),.invalidation_count(invals[g*64 +: 64]),.downgrade_count(downgrades[g*64 +: 64]),.ownership_transfer_count(owners[g*64 +: 64]),.coherence_stall_cycles(cstalls[g*64 +: 64]),.protocol_error_count(perr[g*64 +: 64]));
  end endgenerate

  snoopy_coherence_transport #(.NUM_CORES(4),.SNOOP_TIMEOUT(16)) dut(.clk,.rst_n,
    .req_valid(bus_v),.req_ready(bus_r),.req_cmd(bus_cmd),.req_addr(bus_a),.req_wb_data(bus_wb),.req_wb_data_valid(bus_wbv),.req_resp_valid(bus_rv),.req_resp_ready(bus_rr),.req_resp_data(bus_d),.req_resp_shared(bus_shared),.req_resp_modified(bus_mod),.req_resp_complete(bus_comp),.req_resp_error(bus_err),
    .snoop_valid(sv),.snoop_cmd(scmd),.snoop_addr(sa),.snoop_requester(sid),.snoop_other(sother),.snoop_resp_valid(srv),.snoop_resp_present(srp),.snoop_resp_modified(srm),.snoop_resp_data_valid(srd),.snoop_resp_data(srdata),.snoop_resp_inv_ack(sra),
    .mem_req_valid(mv),.mem_req_ready(mr),.mem_req_write(mw),.mem_req_addr(ma),.mem_req_wdata(mwd),.mem_req_wstrb(mws),.mem_resp_valid(mrv),.mem_resp_ready(mrr),.mem_resp_data(md),
    .transaction_count(tx),.bus_rd_count(tx_brd),.bus_rdx_count(tx_brdx),.bus_upgr_count(tx_bup),.writeback_count(tx_wb),.shared_transaction_count(tx_shared),.intervention_count(tx_interv),.sram_block_read_count(sreads),.sram_block_write_count(swrites),.invalidation_ack_count(acks),.occupied_cycle_count(occupied),.protocol_error_count(tx_perr),.timeout_count(timeouts),.arbitration_wait_cycles(waits));

  always #5 clk=~clk;
  assign cpu_rr=4'hf; assign low_r='0; assign low_rv='0; assign low_d='0; assign mr=!pending&&!mrv;
  initial begin
    #200000;
    $fatal(1,"MSI directed watchdog cpu_v=%b bus_v=%b state tx=%0d rd=%0d rdx=%0d upgr=%0d wb=%0d", cpu_v, bus_v, tx, tx_brd, tx_brdx, tx_bup, tx_wb);
  end
  always_ff @(posedge clk) begin
    if(!rst_n) begin pending<=0; mrv<=0; end else begin
      if(mrv&&mrr) mrv<=0;
      if(mv&&mr) begin pending<=1; saved_a<=ma; saved_d<=mwd; saved_w<=mw; end
      else if(pending) begin pending<=0; mrv<=1; md<=mem[saved_a[13:2]]; if(saved_w) mem[saved_a[13:2]]<=saved_d; end
    end
  end
  task automatic req(input integer c,input logic wr,input [31:0] a,input [31:0] wd,input [3:0] ws,input [31:0] exp);
    begin
      @(negedge clk); cpu_w[c]=wr; cpu_a[c*32 +: 32]=a; cpu_wd[c*32 +: 32]=wd; cpu_ws[c*4 +: 4]=ws; cpu_v[c]=1'b1;
      while(!cpu_r[c]) @(posedge clk); @(posedge clk); @(negedge clk); cpu_v[c]=1'b0;
      while(!cpu_rv[c]) @(posedge clk);
      if(!wr && cpu_d[c*32 +: 32]!==exp) $fatal(1,"core %0d load %h got %h expected %h",c,a,cpu_d[c*32 +: 32],exp);
      @(posedge clk);
    end
  endtask
  task automatic req_async(input integer c,input logic wr,input [31:0] a,input [31:0] wd,input [3:0] ws);
    begin @(negedge clk); cpu_w[c]=wr; cpu_a[c*32 +: 32]=a; cpu_wd[c*32 +: 32]=wd; cpu_ws[c*4 +: 4]=ws; cpu_v[c]=1'b1; end
  endtask
  task automatic wait_async(input integer c,input [31:0] exp);
    begin while(!cpu_r[c]) @(posedge clk); @(posedge clk); @(negedge clk); cpu_v[c]=1'b0; while(!cpu_rv[c]) @(posedge clk); if(cpu_d[c*32 +: 32]!==exp) $fatal(1,"async core %0d got %h",c,cpu_d[c*32 +: 32]); @(posedge clk); end
  endtask
  function automatic [1:0] line_state(input integer c,input integer way,input [31:0] a);
    integer bitpos; begin bitpos=(way*64+a[9:4])*2; line_state=msi_dbg[c*256+bitpos +: 2]; end
  endfunction
  function automatic [31:0] mem_word(input [31:0] a); mem_word=mem[a[13:2]]; endfunction
  initial begin
    cpu_v=0; cpu_w=0; cpu_a=0; cpu_wd=0; cpu_ws=0; for(i=0;i<4096;i=i+1) mem[i]=32'h1000_0000+i;
    repeat(3) @(posedge clk); rst_n=1;
    $display("MSI directed: shared read phase");
    req(0,0,32'h40,0,0,32'h1000_0010);
    req(1,0,32'h40,0,0,32'h1000_0010);
    req(2,0,32'h40,0,0,32'h1000_0010);
    req(3,0,32'h40,0,0,32'h1000_0010);
    req(0,1,32'h40,32'h11112222,4'hf,0);
    req(1,0,32'h40,0,0,32'h11112222);
    if(mem_word(32'h40)!==32'h11112222) $fatal(1,"intervention did not update SRAM");
    $display("MSI directed: ownership transfer phase");
    req(1,1,32'h44,32'h33334444,4'hf,0);
    req(2,1,32'h40,32'h55556666,4'hf,0);
    req(3,0,32'h40,0,0,32'h55556666);
    req(3,1,32'h41,32'haabbccdd,4'b0110,0);
    req(0,0,32'h40,0,0,32'h55bbcc66);
    req(0,1,32'h42,32'heeff0000,4'b1100,0);
    req(1,0,32'h40,0,0,32'heeffcc66);
    $display("MSI directed: eviction phase");
    req(2,1,32'h40,32'h12345678,4'hf,0);
    req(2,1,32'h1040,32'h77778888,4'hf,0);
    req(2,1,32'h2040,32'h9999aaaa,4'hf,0);
    if(wb[2*64 +: 64] == 0) $fatal(1,"dirty eviction did not issue writeback");
    req(0,0,32'h80,0,0,32'h1000_0020);
    req(0,0,32'h1080,0,0,32'h1000_0420);
    req(0,0,32'h2080,0,0,32'h1000_0820);
    if(evictions[0*64 +: 64] != 0) $fatal(1,"clean shared eviction counted dirty");
    $display("MSI directed: concurrent phase");
    fork
      req(0,0,32'hc0,0,0,32'h1000_0030);
      req(1,0,32'hd0,0,0,32'h1000_0034);
      req(2,0,32'he0,0,0,32'h1000_0038);
      req(3,0,32'hf0,0,0,32'h1000_003c);
    join
    for(cycles=0; cycles<4; cycles=cycles+1) if(perr[cycles*64 +: 64]!==0) $fatal(1,"cache protocol error core %0d",cycles);
    if(tx_brd<8 || tx_brdx<3 || tx_bup<3 || tx_interv<3 || acks<6) $fatal(1,"insufficient MSI command coverage");
    $display("PASS msi coherence: shared reads, upgrades, interventions, invalidations, dirty/clean eviction, byte/half/word stores, concurrent arbitration");
    $finish;
  end
endmodule
