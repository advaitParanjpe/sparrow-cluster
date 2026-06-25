module tb_snoopy_transport;
  import coherence_pkg::*;
  logic clk=0,rst_n=0;
  logic [3:0] rv,rr,rdv,rdr,rshared,rmodified,rcomplete,rerror;
  logic [11:0] rcmd; logic [127:0] raddr; logic [511:0] rwb,rdata; logic [3:0] rwbv;
  logic [3:0] sv,sother,srv,srp,srm,srd,sra; logic [2:0] scmd; logic [31:0] saddr; logic [1:0] sid; logic [511:0] srdata;
  logic mv,mr,mw,mrv,mrr; logic [31:0] ma,mwd,md; logic [3:0] mws;
  logic [63:0] tx,brd,brdx,bup,wb,shared,interv,sreads,swrites,acks,occupied,perr,timeouts; logic [255:0] waits;
  logic [3:0] present_mask, modified_mask, ack_mask; logic [127:0] peer_data[0:3];
  logic [31:0] mem[0:255], saved_a,saved_d; logic saved_w,pending; integer i;
  snoopy_coherence_transport #(.SNOOP_TIMEOUT(8)) dut(.*,
    .req_valid(rv),.req_ready(rr),.req_cmd(rcmd),.req_addr(raddr),.req_wb_data(rwb),.req_wb_data_valid(rwbv),.req_resp_valid(rdv),.req_resp_ready(rdr),.req_resp_data(rdata),.req_resp_shared(rshared),.req_resp_modified(rmodified),.req_resp_complete(rcomplete),.req_resp_error(rerror),
    .snoop_valid(sv),.snoop_cmd(scmd),.snoop_addr(saddr),.snoop_requester(sid),.snoop_other(sother),.snoop_resp_valid(srv),.snoop_resp_present(srp),.snoop_resp_modified(srm),.snoop_resp_data_valid(srd),.snoop_resp_data(srdata),.snoop_resp_inv_ack(sra),
    .mem_req_valid(mv),.mem_req_ready(mr),.mem_req_write(mw),.mem_req_addr(ma),.mem_req_wdata(mwd),.mem_req_wstrb(mws),.mem_resp_valid(mrv),.mem_resp_ready(mrr),.mem_resp_data(md),
    .transaction_count(tx),.bus_rd_count(brd),.bus_rdx_count(brdx),.bus_upgr_count(bup),.writeback_count(wb),.shared_transaction_count(shared),.intervention_count(interv),.sram_block_read_count(sreads),.sram_block_write_count(swrites),.invalidation_ack_count(acks),.occupied_cycle_count(occupied),.protocol_error_count(perr),.timeout_count(timeouts),.arbitration_wait_cycles(waits));
  always #5 clk=~clk;
  always_comb begin
    srv=sv; srp=present_mask & sv; srm=modified_mask & sv; srd=modified_mask & sv; sra=ack_mask & sv; srdata='0;
    for(i=0;i<4;i=i+1) srdata[i*128 +:128]=peer_data[i];
    mr=!pending&&!mrv;
  end
  always_ff @(posedge clk) begin
    if(!rst_n) begin pending<=0;mrv<=0;md<=0; end else begin
      if(mrv&&mrr) mrv<=0;
      if(mv&&mr) begin pending<=1;saved_a<=ma;saved_d<=mwd;saved_w<=mw; end
      else if(pending) begin pending<=0;mrv<=1;md<=mem[saved_a[9:2]]; if(saved_w) mem[saved_a[9:2]]<=saved_d; end
    end
  end
  task automatic issue(input integer id,input [2:0] cmd,input [31:0] addr,input [127:0] data,input expect_data,input [127:0] expected,input expect_error);
    begin
      @(negedge clk); rcmd[id*3 +:3]=cmd; raddr[id*32 +:32]=addr; rwb[id*128 +:128]=data; rwbv[id]=(cmd==WRITEBACK); rv[id]=1;
      while(!rr[id]) @(posedge clk); @(negedge clk); rv[id]=0;
      while(!rdv[id]) @(posedge clk);
      if(rerror[id]!==expect_error) $fatal(1,"error flag cmd %0d",cmd);
      if(expect_data && rdata[id*128 +:128]!==expected) $fatal(1,"data cmd %0d got %h expected %h",cmd,rdata[id*128 +:128],expected);
      @(posedge clk);
    end
  endtask
  task automatic clear_peers; begin present_mask=0;modified_mask=0;ack_mask=4'hf; for(i=0;i<4;i=i+1) peer_data[i]=0; end endtask
  initial begin
    rv=0;rcmd=0;raddr=0;rwb=0;rwbv=0;rdr=4'hf;clear_peers(); for(i=0;i<256;i=i+1) mem[i]=32'h10000000+i;
    repeat(3) @(posedge clk); rst_n=1;
    issue(0,BUS_RD,32'h40,0,1,{mem[19],mem[18],mem[17],mem[16]},0);
    clear_peers(); present_mask=4'b0010;
    issue(0,BUS_RD,32'h40,0,1,{mem[19],mem[18],mem[17],mem[16]},0);
    clear_peers(); present_mask=4'b0110; modified_mask=4'b0100; peer_data[2]=128'hd0d1d2d3_c0c1c2c3_b0b1b2b3_a0a1a2a3;
    issue(1,BUS_RD,32'h40,0,1,peer_data[2],0);
    if({mem[19],mem[18],mem[17],mem[16]}!==peer_data[2]) $fatal(1,"intervention failed SRAM update");
    clear_peers(); present_mask=4'b1001;
    issue(2,BUS_RDX,32'h40,0,1,128'hd0d1d2d3_c0c1c2c3_b0b1b2b3_a0a1a2a3,0);
    clear_peers();
    issue(3,BUS_UPGR,32'h40,0,0,0,0);
    clear_peers();
    issue(0,WRITEBACK,32'h80,128'h44444444_33333333_22222222_11111111,0,0,0);
    if({mem[35],mem[34],mem[33],mem[32]}!==128'h44444444_33333333_22222222_11111111) $fatal(1,"writeback words");
    clear_peers(); ack_mask=4'b0000;
    issue(1,BUS_UPGR,32'h40,0,0,0,1);
    if(tx!==7 || brd!==3 || brdx!==1 || bup!==2 || wb!==1 || interv!==1 || sreads!==3 || swrites!==2 || timeouts!==1 || perr<1) $fatal(1,"counter consistency tx=%0d rd=%0d rdx=%0d upgr=%0d wb=%0d",tx,brd,brdx,bup,wb);
    $display("PASS snoopy transport: RR requests, BusRd/RdX/Upgr/writeback, shared aggregation, intervention SRAM update, delayed-ready memory, timeout and counters"); $finish;
  end
endmodule
