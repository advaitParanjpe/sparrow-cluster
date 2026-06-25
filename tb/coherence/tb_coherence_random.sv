module tb_coherence_random;
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
  logic [31:0] mem[0:8191], refmem[0:8191], saved_a, saved_d; logic saved_w,pending; integer i, op, seed, core, index, wr;
  genvar g;
  generate for(g=0; g<4; g=g+1) begin: caches
    l1_data_cache u_l1d(.clk,.rst_n,.cpu_req_valid(cpu_v[g]),.cpu_req_ready(cpu_r[g]),.cpu_req_write(cpu_w[g]),.cpu_req_addr(cpu_a[g*32 +: 32]),.cpu_req_wdata(cpu_wd[g*32 +: 32]),.cpu_req_wstrb(cpu_ws[g*4 +: 4]),.cpu_resp_valid(cpu_rv[g]),.cpu_resp_ready(cpu_rr[g]),.cpu_resp_data(cpu_d[g*32 +: 32]),
      .lower_req_valid(low_v[g]),.lower_req_ready(low_r[g]),.lower_req_write(low_w[g]),.lower_req_addr(low_a[g*32 +: 32]),.lower_req_wdata(low_wd[g*32 +: 32]),.lower_req_wstrb(low_ws[g*4 +: 4]),.lower_resp_valid(low_rv[g]),.lower_resp_ready(low_rr[g]),.lower_resp_data(low_d[g*32 +: 32]),
      .bus_req_valid(bus_v[g]),.bus_req_ready(bus_r[g]),.bus_req_cmd(bus_cmd[g*3 +: 3]),.bus_req_addr(bus_a[g*32 +: 32]),.bus_req_wb_data(bus_wb[g*128 +: 128]),.bus_req_wb_data_valid(bus_wbv[g]),.bus_resp_valid(bus_rv[g]),.bus_resp_ready(bus_rr[g]),.bus_resp_data(bus_d[g*128 +: 128]),.bus_resp_shared(bus_shared[g]),.bus_resp_modified(bus_mod[g]),.bus_resp_complete(bus_comp[g]),.bus_resp_error(bus_err[g]),
      .snoop_valid(sv[g]),.snoop_cmd(scmd),.snoop_addr(sa),.snoop_requester(sid),.snoop_other(sother[g]),.snoop_resp_valid(srv[g]),.snoop_resp_present(srp[g]),.snoop_resp_modified(srm[g]),.snoop_resp_data_valid(srd[g]),.snoop_resp_data(srdata[g*128 +: 128]),.snoop_resp_inv_ack(sra[g]),.msi_state_debug(msi_dbg[g*256 +: 256]),
      .access_count(accesses[g*64 +: 64]),.load_access_count(loads[g*64 +: 64]),.store_access_count(stores[g*64 +: 64]),.hit_count(hits[g*64 +: 64]),.miss_count(misses[g*64 +: 64]),.load_miss_count(load_misses[g*64 +: 64]),.store_miss_count(store_misses[g*64 +: 64]),.refill_word_count(refills[g*64 +: 64]),.dirty_writeback_word_count(wb_words[g*64 +: 64]),.dirty_eviction_count(evictions[g*64 +: 64]),.uncached_access_count(uncached[g*64 +: 64]),.miss_stall_cycles(stalls[g*64 +: 64]),
      .load_hit_s_count(lhs[g*64 +: 64]),.load_hit_m_count(lhm[g*64 +: 64]),.store_hit_m_count(shm[g*64 +: 64]),.store_upgrade_count(sup[g*64 +: 64]),.bus_rd_request_count(brd[g*64 +: 64]),.bus_rdx_request_count(brdx[g*64 +: 64]),.bus_upgr_request_count(bup[g*64 +: 64]),.writeback_count(wb[g*64 +: 64]),.snoop_hit_s_count(shs[g*64 +: 64]),.snoop_hit_m_count(shm_snoop[g*64 +: 64]),.intervention_count(interv[g*64 +: 64]),.invalidation_count(invals[g*64 +: 64]),.downgrade_count(downgrades[g*64 +: 64]),.ownership_transfer_count(owners[g*64 +: 64]),.coherence_stall_cycles(cstalls[g*64 +: 64]),.protocol_error_count(perr[g*64 +: 64]));
  end endgenerate
  snoopy_coherence_transport #(.NUM_CORES(4),.SNOOP_TIMEOUT(16)) dut(.clk,.rst_n,.req_valid(bus_v),.req_ready(bus_r),.req_cmd(bus_cmd),.req_addr(bus_a),.req_wb_data(bus_wb),.req_wb_data_valid(bus_wbv),.req_resp_valid(bus_rv),.req_resp_ready(bus_rr),.req_resp_data(bus_d),.req_resp_shared(bus_shared),.req_resp_modified(bus_mod),.req_resp_complete(bus_comp),.req_resp_error(bus_err),.snoop_valid(sv),.snoop_cmd(scmd),.snoop_addr(sa),.snoop_requester(sid),.snoop_other(sother),.snoop_resp_valid(srv),.snoop_resp_present(srp),.snoop_resp_modified(srm),.snoop_resp_data_valid(srd),.snoop_resp_data(srdata),.snoop_resp_inv_ack(sra),.mem_req_valid(mv),.mem_req_ready(mr),.mem_req_write(mw),.mem_req_addr(ma),.mem_req_wdata(mwd),.mem_req_wstrb(mws),.mem_resp_valid(mrv),.mem_resp_ready(mrr),.mem_resp_data(md),.transaction_count(tx),.bus_rd_count(tx_brd),.bus_rdx_count(tx_brdx),.bus_upgr_count(tx_bup),.writeback_count(tx_wb),.shared_transaction_count(tx_shared),.intervention_count(tx_interv),.sram_block_read_count(sreads),.sram_block_write_count(swrites),.invalidation_ack_count(acks),.occupied_cycle_count(occupied),.protocol_error_count(tx_perr),.timeout_count(timeouts),.arbitration_wait_cycles(waits));
  always #5 clk=~clk;
  assign cpu_rr=4'hf; assign low_r='0; assign low_rv='0; assign low_d='0; assign mr=!pending&&!mrv;
  initial begin #1000000; $fatal(1,"random watchdog seed=%0d op=%0d cpu_v=%b bus_v=%b",seed,op,cpu_v,bus_v); end
  always_ff @(posedge clk) begin
    if(!rst_n) begin pending<=0; mrv<=0; end else begin
      if(mrv&&mrr) mrv<=0;
      if(mv&&mr) begin pending<=1; saved_a<=ma; saved_d<=mwd; saved_w<=mw; end
      else if(pending) begin pending<=0; mrv<=1; md<=mem[saved_a[14:2]]; if(saved_w) mem[saved_a[14:2]]<=saved_d; end
    end
  end
  task automatic access(input integer c,input logic write,input [31:0] addr,input [31:0] data,input [31:0] expected);
    begin
      @(negedge clk); cpu_w[c]=write; cpu_a[c*32 +: 32]=addr; cpu_wd[c*32 +: 32]=data; cpu_ws[c*4 +: 4]=4'hf; cpu_v[c]=1'b1;
      while(!cpu_r[c]) @(posedge clk); @(posedge clk); @(negedge clk); cpu_v[c]=1'b0; while(!cpu_rv[c]) @(posedge clk);
      if(!write && cpu_d[c*32 +: 32]!==expected) $fatal(1,"seed %0d op %0d core %0d addr %h got %h expected %h",seed,op,c,addr,cpu_d[c*32 +: 32],expected);
      @(posedge clk);
    end
  endtask
  initial begin
    seed=32'h5eed1234; cpu_v=0; cpu_w=0; cpu_a=0; cpu_wd=0; cpu_ws=0;
    for(i=0;i<8192;i=i+1) begin mem[i]=32'h2000_0000+i; refmem[i]=32'h2000_0000+i; end
    repeat(3) @(posedge clk); rst_n=1;
    for(op=0; op<96; op=op+1) begin
      seed = (seed * 1103515245) + 12345; core = seed[17:16]; index = 64 + {seed[5:2],2'b00};
      if(seed[8]) index = index + 1024;
      wr = seed[9] || (op < 24);
      if(wr) begin refmem[index] = seed ^ (op * 32'h01010101); access(core,1,index<<2,refmem[index],0); end
      else access(core,0,index<<2,0,refmem[index]);
      if(perr[0 +: 64] || perr[64 +: 64] || perr[128 +: 64] || perr[192 +: 64] || tx_perr || timeouts) $fatal(1,"protocol error in random seed");
    end
    $display("PASS coherence random: seed=0x5eed1234 ops=96 checked_loads tx=%0d rd=%0d rdx=%0d upgr=%0d wb=%0d",tx,tx_brd,tx_brdx,tx_bup,tx_wb);
    $finish;
  end
endmodule
