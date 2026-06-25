module tb_atomic_random;
  import coherence_pkg::*;
  localparam logic [1:0] ATOMIC_NONE=2'd0, ATOMIC_LR=2'd1, ATOMIC_SC=2'd2;
  logic clk=0,rst_n=0;
  logic [3:0] cpu_v,cpu_r,cpu_w,cpu_rv,cpu_rr;
  logic [7:0] cpu_atomic;
  logic [127:0] cpu_a,cpu_wd,cpu_d;
  logic [15:0] cpu_ws;
  logic [3:0] low_v,low_r,low_w,low_rv,low_rr;
  logic [127:0] low_a,low_wd,low_d;
  logic [15:0] low_ws;
  logic [3:0] bus_v,bus_r,bus_rv,bus_rr,bus_shared,bus_mod,bus_comp,bus_err,bus_wbv;
  logic [11:0] bus_cmd;
  logic [127:0] bus_a;
  logic [511:0] bus_wb,bus_d;
  logic [3:0] sv,sother,srv,srp,srm,srd,sra;
  logic [2:0] scmd;
  logic [31:0] sa,saved_a,saved_d,md,ma,mwd;
  logic [1:0] sid;
  logic [511:0] srdata;
  logic mv,mr,mw,mrv,mrr,saved_w,pending;
  logic [3:0] mws;
  logic [31:0] mem[0:4095], model[0:4095], observed, a, value;
  logic [3:0] res_valid;
  logic [31:0] res_block[0:3];
  logic [255:0] lr_attempts,lr_done,sc_attempts,sc_success,sc_failure,clear_count;
  logic [255:0] accesses,loads,stores,hits,misses,load_misses,store_misses,refills,wb_words,evictions,uncached,stalls;
  logic [255:0] lhs,lhm,shm,sup,brd,brdx,bup,wb,shs,shm_snoop,interv,invals,downgrades,owners,cstalls,perr;
  logic [63:0] tx,tx_brd,tx_brdx,tx_bup,tx_wb,tx_shared,tx_interv,sreads,swrites,acks,occupied,tx_perr,timeouts;
  logic [255:0] waits;
  integer i, op, c, peer, idx, seed, successes, failures;

  genvar g;
  generate for(g=0; g<4; g=g+1) begin: caches
    l1_data_cache u_l1d(.clk,.rst_n,.cpu_req_valid(cpu_v[g]),.cpu_req_ready(cpu_r[g]),.cpu_req_write(cpu_w[g]),.cpu_req_addr(cpu_a[g*32 +: 32]),.cpu_req_wdata(cpu_wd[g*32 +: 32]),.cpu_req_wstrb(cpu_ws[g*4 +: 4]),.cpu_req_atomic(cpu_atomic[g*2 +: 2]),.cpu_resp_valid(cpu_rv[g]),.cpu_resp_ready(cpu_rr[g]),.cpu_resp_data(cpu_d[g*32 +: 32]),
      .lower_req_valid(low_v[g]),.lower_req_ready(low_r[g]),.lower_req_write(low_w[g]),.lower_req_addr(low_a[g*32 +: 32]),.lower_req_wdata(low_wd[g*32 +: 32]),.lower_req_wstrb(low_ws[g*4 +: 4]),.lower_resp_valid(low_rv[g]),.lower_resp_ready(low_rr[g]),.lower_resp_data(low_d[g*32 +: 32]),
      .bus_req_valid(bus_v[g]),.bus_req_ready(bus_r[g]),.bus_req_cmd(bus_cmd[g*3 +: 3]),.bus_req_addr(bus_a[g*32 +: 32]),.bus_req_wb_data(bus_wb[g*128 +: 128]),.bus_req_wb_data_valid(bus_wbv[g]),.bus_resp_valid(bus_rv[g]),.bus_resp_ready(bus_rr[g]),.bus_resp_data(bus_d[g*128 +: 128]),.bus_resp_shared(bus_shared[g]),.bus_resp_modified(bus_mod[g]),.bus_resp_complete(bus_comp[g]),.bus_resp_error(bus_err[g]),
      .snoop_valid(sv[g]),.snoop_cmd(scmd),.snoop_addr(sa),.snoop_requester(sid),.snoop_other(sother[g]),.snoop_resp_valid(srv[g]),.snoop_resp_present(srp[g]),.snoop_resp_modified(srm[g]),.snoop_resp_data_valid(srd[g]),.snoop_resp_data(srdata[g*128 +: 128]),.snoop_resp_inv_ack(sra[g]),.msi_state_debug(),
      .access_count(accesses[g*64 +: 64]),.load_access_count(loads[g*64 +: 64]),.store_access_count(stores[g*64 +: 64]),.hit_count(hits[g*64 +: 64]),.miss_count(misses[g*64 +: 64]),.load_miss_count(load_misses[g*64 +: 64]),.store_miss_count(store_misses[g*64 +: 64]),.refill_word_count(refills[g*64 +: 64]),.dirty_writeback_word_count(wb_words[g*64 +: 64]),.dirty_eviction_count(evictions[g*64 +: 64]),.uncached_access_count(uncached[g*64 +: 64]),.miss_stall_cycles(stalls[g*64 +: 64]),
      .load_hit_s_count(lhs[g*64 +: 64]),.load_hit_m_count(lhm[g*64 +: 64]),.store_hit_m_count(shm[g*64 +: 64]),.store_upgrade_count(sup[g*64 +: 64]),.bus_rd_request_count(brd[g*64 +: 64]),.bus_rdx_request_count(brdx[g*64 +: 64]),.bus_upgr_request_count(bup[g*64 +: 64]),.writeback_count(wb[g*64 +: 64]),.snoop_hit_s_count(shs[g*64 +: 64]),.snoop_hit_m_count(shm_snoop[g*64 +: 64]),.intervention_count(interv[g*64 +: 64]),.invalidation_count(invals[g*64 +: 64]),.downgrade_count(downgrades[g*64 +: 64]),.ownership_transfer_count(owners[g*64 +: 64]),.coherence_stall_cycles(cstalls[g*64 +: 64]),.protocol_error_count(perr[g*64 +: 64]),
      .lr_attempt_count(lr_attempts[g*64 +: 64]),.lr_complete_count(lr_done[g*64 +: 64]),.sc_attempt_count(sc_attempts[g*64 +: 64]),.sc_success_count(sc_success[g*64 +: 64]),.sc_failure_count(sc_failure[g*64 +: 64]),.sc_fail_no_reservation_count(),.sc_fail_mismatch_count(),.sc_fail_snoop_count(),.sc_fail_eviction_count(),.reservation_clear_count(clear_count[g*64 +: 64]));
  end endgenerate

  snoopy_coherence_transport #(.NUM_CORES(4),.SNOOP_TIMEOUT(16)) txp(.clk,.rst_n,
    .req_valid(bus_v),.req_ready(bus_r),.req_cmd(bus_cmd),.req_addr(bus_a),.req_wb_data(bus_wb),.req_wb_data_valid(bus_wbv),.req_resp_valid(bus_rv),.req_resp_ready(bus_rr),.req_resp_data(bus_d),.req_resp_shared(bus_shared),.req_resp_modified(bus_mod),.req_resp_complete(bus_comp),.req_resp_error(bus_err),
    .snoop_valid(sv),.snoop_cmd(scmd),.snoop_addr(sa),.snoop_requester(sid),.snoop_other(sother),.snoop_resp_valid(srv),.snoop_resp_present(srp),.snoop_resp_modified(srm),.snoop_resp_data_valid(srd),.snoop_resp_data(srdata),.snoop_resp_inv_ack(sra),
    .mem_req_valid(mv),.mem_req_ready(mr),.mem_req_write(mw),.mem_req_addr(ma),.mem_req_wdata(mwd),.mem_req_wstrb(mws),.mem_resp_valid(mrv),.mem_resp_ready(mrr),.mem_resp_data(md),
    .transaction_count(tx),.bus_rd_count(tx_brd),.bus_rdx_count(tx_brdx),.bus_upgr_count(tx_bup),.writeback_count(tx_wb),.shared_transaction_count(tx_shared),.intervention_count(tx_interv),.sram_block_read_count(sreads),.sram_block_write_count(swrites),.invalidation_ack_count(acks),.occupied_cycle_count(occupied),.protocol_error_count(tx_perr),.timeout_count(timeouts),.arbitration_wait_cycles(waits));

  always #5 clk=~clk;
  assign cpu_rr=4'hf; assign low_r='0; assign low_rv='0; assign low_d='0; assign mr=!pending&&!mrv;

  always_ff @(posedge clk) begin
    if(!rst_n) begin pending<=0; mrv<=0; end else begin
      if(mrv&&mrr) mrv<=0;
      if(mv&&mr) begin pending<=1; saved_a<=ma; saved_d<=mwd; saved_w<=mw; end
      else if(pending) begin pending<=0; mrv<=1; md<=mem[saved_a[13:2]]; if(saved_w) mem[saved_a[13:2]]<=saved_d; end
    end
  end

  task automatic issue(input integer core,input logic wr,input logic [1:0] atomic,input [31:0] addr,input [31:0] wd,output [31:0] resp);
    begin
      @(negedge clk); cpu_w[core]=wr; cpu_atomic[core*2 +: 2]=atomic; cpu_a[core*32 +: 32]=addr; cpu_wd[core*32 +: 32]=wd; cpu_ws[core*4 +: 4]=4'hf; cpu_v[core]=1'b1;
      while(!cpu_r[core]) @(posedge clk);
      @(posedge clk); @(negedge clk); cpu_v[core]=1'b0; cpu_atomic[core*2 +: 2]=ATOMIC_NONE;
      while(!cpu_rv[core]) @(posedge clk);
      resp=cpu_d[core*32 +: 32];
      @(posedge clk);
    end
  endtask

  function automatic [31:0] block(input [31:0] addr); block={addr[31:4],4'h0}; endfunction

  initial begin
    seed=32'h5eed_600d; successes=0; failures=0; cpu_v=0; cpu_w=0; cpu_a=0; cpu_wd=0; cpu_ws=0; cpu_atomic=0; res_valid=0;
    for(i=0;i<4096;i=i+1) begin mem[i]=32'h3000_0000+i; model[i]=32'h3000_0000+i; end
    repeat(3) @(posedge clk); rst_n=1;
    for(c=0; c<4; c=c+1) begin
      idx = 16 + c;
      a = {idx[29:0],2'b00};
      value = 32'h6000_0100 | c;
      issue(c,1'b0,ATOMIC_LR,a,32'd0,observed);
      if(observed!==model[idx]) $fatal(1,"seed LR mismatch core=%0d",c);
      issue(c,1'b1,ATOMIC_SC,a,value,observed);
      if(observed!==32'd0) $fatal(1,"seed SC failed core=%0d got=%h",c,observed);
      model[idx]=value; successes=successes+1;
      res_valid[c]=1'b0;
    end
    for(op=0; op<72; op=op+1) begin
      seed = (seed * 32'd1103515245) + 32'd12345;
      c = seed[1:0];
      idx = 16 + seed[7:2];
      a = {idx[29:0],2'b00};
      value = 32'h6000_0000 | op;
      unique case(seed[10:8])
        3'd0,3'd1: begin
          issue(c,1'b0,ATOMIC_LR,a,32'd0,observed);
          if(observed!==model[idx]) $fatal(1,"random LR mismatch op=%0d core=%0d addr=%h got=%h expected=%h",op,c,a,observed,model[idx]);
          res_valid[c]=1'b1; res_block[c]=block(a);
        end
        3'd2,3'd3,3'd4: begin
          issue(c,1'b1,ATOMIC_SC,a,value,observed);
          if(res_valid[c] && res_block[c]==block(a)) begin
            if(observed!==32'd0) $fatal(1,"random SC expected success op=%0d core=%0d got=%h",op,c,observed);
            model[idx]=value; successes=successes+1;
          end else begin
            if(observed===32'd0) $fatal(1,"random SC expected failure op=%0d core=%0d",op,c);
            failures=failures+1;
          end
          res_valid[c]=1'b0;
        end
        default: begin
          issue(c,1'b1,ATOMIC_NONE,a,value,observed);
          model[idx]=value;
          for(peer=0; peer<4; peer=peer+1) if(res_valid[peer] && res_block[peer]==block(a)) res_valid[peer]=1'b0;
        end
      endcase
    end
    for(i=16;i<80;i=i+1) begin
      a={i[29:0],2'b00};
      issue(i[1:0],1'b0,ATOMIC_NONE,a,32'd0,observed);
      if(observed!==model[i]) $fatal(1,"random final memory mismatch idx=%0d got=%h expected=%h",i,observed,model[i]);
    end
    for(i=0;i<4;i=i+1) begin
      if(sc_attempts[i*64 +: 64] !== sc_success[i*64 +: 64] + sc_failure[i*64 +: 64])
        $fatal(1,"random SC counter mismatch core=%0d",i);
      if(perr[i*64 +: 64]!==0) $fatal(1,"random protocol error core=%0d",i);
    end
    if(successes==0 || failures==0 || tx_brdx==0 || tx_bup==0) $fatal(1,"random coverage too low success=%0d failure=%0d rdx=%0d upgr=%0d",successes,failures,tx_brdx,tx_bup);
    $display("PASS atomic random: seed=0x5eed600d ops=72 successes=%0d failures=%0d",successes,failures);
    $finish;
  end
endmodule
