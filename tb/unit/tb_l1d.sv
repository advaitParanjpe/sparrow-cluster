module tb_l1d;
  import coherence_pkg::*;
  logic clk=0,rst_n=0,cpu_v,cpu_r,cpu_w,cpu_rv,cpu_rr; logic [31:0] cpu_a,cpu_wd,cpu_d; logic [3:0] cpu_ws;
  logic low_v,low_r,low_w,low_rv,low_rr; logic [31:0] low_a,low_wd,low_d; logic [3:0] low_ws;
  logic bus_v,bus_r,bus_rv,bus_rr,bus_shared,bus_mod,bus_comp,bus_err,bus_wbv; logic [2:0] bus_cmd; logic [31:0] bus_a; logic [127:0] bus_wb,bus_d;
  logic sv,sother,srv,srp,srm,srd,sra; logic [2:0] scmd; logic [31:0] sa; logic [1:0] sid; logic [127:0] srdata;
  logic mv,mr,mw,mrv,mrr; logic [31:0] ma,mwd,md; logic [3:0] mws;
  logic [63:0] accesses,loads,stores,hits,misses,load_misses,store_misses,refills,wb_words,evictions,uncached,stalls;
  logic [63:0] lhs,lhm,shm,sup,brd,brdx,bup,wb,shs,shm_snoop,interv,invals,downgrades,owners,cstalls,perr;
  logic [255:0] msi_dbg;
  logic [63:0] tx,tx_brd,tx_brdx,tx_bup,tx_wb,tx_shared,tx_interv,sreads,swrites,acks,occupied,tx_perr,timeouts,waits;
  logic [7:0] mem[0:16383]; logic pending, pending_low; logic [31:0] pending_a,pending_wd; logic [3:0] pending_ws; logic pending_w; integer delay, requests, writes, i;

  l1_data_cache dut(.clk,.rst_n,.cpu_req_valid(cpu_v),.cpu_req_ready(cpu_r),.cpu_req_write(cpu_w),.cpu_req_addr(cpu_a),.cpu_req_wdata(cpu_wd),.cpu_req_wstrb(cpu_ws),.cpu_resp_valid(cpu_rv),.cpu_resp_ready(cpu_rr),.cpu_resp_data(cpu_d),
    .lower_req_valid(low_v),.lower_req_ready(low_r),.lower_req_write(low_w),.lower_req_addr(low_a),.lower_req_wdata(low_wd),.lower_req_wstrb(low_ws),.lower_resp_valid(low_rv),.lower_resp_ready(low_rr),.lower_resp_data(low_d),
    .bus_req_valid(bus_v),.bus_req_ready(bus_r),.bus_req_cmd(bus_cmd),.bus_req_addr(bus_a),.bus_req_wb_data(bus_wb),.bus_req_wb_data_valid(bus_wbv),.bus_resp_valid(bus_rv),.bus_resp_ready(bus_rr),.bus_resp_data(bus_d),.bus_resp_shared(bus_shared),.bus_resp_modified(bus_mod),.bus_resp_complete(bus_comp),.bus_resp_error(bus_err),
    .snoop_valid(sv),.snoop_cmd(scmd),.snoop_addr(sa),.snoop_requester(sid),.snoop_other(sother),.snoop_resp_valid(srv),.snoop_resp_present(srp),.snoop_resp_modified(srm),.snoop_resp_data_valid(srd),.snoop_resp_data(srdata),.snoop_resp_inv_ack(sra),.msi_state_debug(msi_dbg),
    .access_count(accesses),.load_access_count(loads),.store_access_count(stores),.hit_count(hits),.miss_count(misses),.load_miss_count(load_misses),.store_miss_count(store_misses),.refill_word_count(refills),.dirty_writeback_word_count(wb_words),.dirty_eviction_count(evictions),.uncached_access_count(uncached),.miss_stall_cycles(stalls),
    .load_hit_s_count(lhs),.load_hit_m_count(lhm),.store_hit_m_count(shm),.store_upgrade_count(sup),.bus_rd_request_count(brd),.bus_rdx_request_count(brdx),.bus_upgr_request_count(bup),.writeback_count(wb),.snoop_hit_s_count(shs),.snoop_hit_m_count(shm_snoop),.intervention_count(interv),.invalidation_count(invals),.downgrade_count(downgrades),.ownership_transfer_count(owners),.coherence_stall_cycles(cstalls),.protocol_error_count(perr));
  snoopy_coherence_transport #(.NUM_CORES(1),.SNOOP_TIMEOUT(8)) txp(.clk,.rst_n,
    .req_valid(bus_v),.req_ready(bus_r),.req_cmd(bus_cmd),.req_addr(bus_a),.req_wb_data(bus_wb),.req_wb_data_valid(bus_wbv),.req_resp_valid(bus_rv),.req_resp_ready(bus_rr),.req_resp_data(bus_d),.req_resp_shared(bus_shared),.req_resp_modified(bus_mod),.req_resp_complete(bus_comp),.req_resp_error(bus_err),
    .snoop_valid(sv),.snoop_cmd(scmd),.snoop_addr(sa),.snoop_requester(sid),.snoop_other(sother),.snoop_resp_valid(srv),.snoop_resp_present(srp),.snoop_resp_modified(srm),.snoop_resp_data_valid(srd),.snoop_resp_data(srdata),.snoop_resp_inv_ack(sra),
    .mem_req_valid(mv),.mem_req_ready(mr),.mem_req_write(mw),.mem_req_addr(ma),.mem_req_wdata(mwd),.mem_req_wstrb(mws),.mem_resp_valid(mrv),.mem_resp_ready(mrr),.mem_resp_data(md),
    .transaction_count(tx),.bus_rd_count(tx_brd),.bus_rdx_count(tx_brdx),.bus_upgr_count(tx_bup),.writeback_count(tx_wb),.shared_transaction_count(tx_shared),.intervention_count(tx_interv),.sram_block_read_count(sreads),.sram_block_write_count(swrites),.invalidation_ack_count(acks),.occupied_cycle_count(occupied),.protocol_error_count(tx_perr),.timeout_count(timeouts),.arbitration_wait_cycles(waits));
  always #5 clk=~clk;
  assign low_r=!pending&&!low_rv; assign mr=!pending&&!mrv;
  always_ff @(posedge clk) begin
    if(!rst_n) begin pending<=0; pending_low<=0; low_rv<=0; mrv<=0; delay<=0; requests<=0; writes<=0; end else begin
      if(low_rv&&low_rr) low_rv<=0; if(mrv&&mrr) mrv<=0;
      if((low_v&&low_r)||(mv&&mr)) begin pending<=1; pending_low<=low_v; pending_a<=low_v?low_a:ma; pending_w<=low_v?low_w:mw; pending_wd<=low_v?low_wd:mwd; pending_ws<=low_v?low_ws:mws; delay<=1; requests<=requests+1; if(low_v?low_w:mw) writes<=writes+1; end
      if(pending) if(delay) delay<=delay-1; else begin
        pending<=0;
        if(pending_w) for(i=0;i<4;i=i+1) if(pending_ws[i]) mem[pending_a+i]<=pending_wd[i*8 +:8];
        if(pending_a==32'h1000_0000) begin low_rv<=1; low_d<=0; end
        else if(pending_a[31:0] < 16384) begin
          low_d<={mem[pending_a+3],mem[pending_a+2],mem[pending_a+1],mem[pending_a]};
          md<={mem[pending_a+3],mem[pending_a+2],mem[pending_a+1],mem[pending_a]};
          if(pending_low) low_rv<=1; else mrv<=1;
        end
      end
    end
  end
  task automatic request(input logic wr,input [31:0] a,input [31:0] wd,input [3:0] ws, input [31:0] expected);
    begin @(negedge clk); cpu_w=wr; cpu_a=a; cpu_wd=wd; cpu_ws=ws; cpu_v=1; while(!cpu_r) @(posedge clk); @(posedge clk); @(negedge clk); cpu_v=0; while(!cpu_rv) @(posedge clk); if(!wr && cpu_d!==expected) $fatal(1,"response addr=%h got=%h expected=%h",a,cpu_d,expected); @(posedge clk); end
  endtask
  function automatic [31:0] word(input integer a); word={mem[a+3],mem[a+2],mem[a+1],mem[a]}; endfunction
  initial begin
    cpu_v=0; cpu_w=0; cpu_a=0; cpu_wd=0; cpu_ws=0; cpu_rr=1; for(i=0;i<16384;i=i+1) mem[i]=i[7:0]; repeat(3) @(posedge clk); rst_n=1;
    request(0,32'h000,0,0,32'h03020100); request(0,32'h004,0,0,32'h07060504);
    request(1,32'h004,32'haabbccdd,4'b0011,0); request(0,32'h004,0,0,32'h0706ccdd);
    request(1,32'h008,32'h11223344,4'b1111,0); request(1,32'h00c,32'h55667788,4'b1100,0);
    request(0,32'h1000,0,0,32'h03020100); request(0,32'h2000,0,0,32'h03020100);
    if(word(8)!==32'h11223344 || word(12)!==32'h55660d0c) $fatal(1,"dirty eviction contents");
    request(1,32'h600,32'hcafebabe,4'b1111,0); request(0,32'h600,0,0,32'hcafebabe);
    if(accesses!==hits+misses+uncached || refills!==12 || wb_words!==4 || evictions!==1 || uncached!==2 || writes<5) $fatal(1,"counter or traffic accounting");
    rst_n=0; repeat(2) @(posedge clk); rst_n=1; request(0,0,0,0,32'h03020100); if(misses!==1||refills!==4) $fatal(1,"reset invalidation");
    $display("PASS l1d: MSI refill/hit, upgrade, byte and word merge, write-allocate, writeback, replacement, uncached bypass, reset, counters"); $finish;
  end
endmodule
