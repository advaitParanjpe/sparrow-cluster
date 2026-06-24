module tb_l1d;
  logic clk=0,rst_n=0,cpu_v,cpu_r,cpu_w,cpu_rv,cpu_rr; logic [31:0] cpu_a,cpu_wd,cpu_d; logic [3:0] cpu_ws;
  logic low_v,low_r,low_w,low_rv,low_rr; logic [31:0] low_a,low_wd,low_d; logic [3:0] low_ws;
  logic [63:0] accesses,loads,stores,hits,misses,load_misses,store_misses,refills,wb_words,evictions,uncached,stalls;
  logic [7:0] mem[0:16383]; logic pending; logic [31:0] pending_a,pending_wd; logic [3:0] pending_ws; logic pending_w; integer delay, requests, writes, i;
  l1_data_cache dut(.clk,.rst_n,.cpu_req_valid(cpu_v),.cpu_req_ready(cpu_r),.cpu_req_write(cpu_w),.cpu_req_addr(cpu_a),.cpu_req_wdata(cpu_wd),.cpu_req_wstrb(cpu_ws),.cpu_resp_valid(cpu_rv),.cpu_resp_ready(cpu_rr),.cpu_resp_data(cpu_d),.lower_req_valid(low_v),.lower_req_ready(low_r),.lower_req_write(low_w),.lower_req_addr(low_a),.lower_req_wdata(low_wd),.lower_req_wstrb(low_ws),.lower_resp_valid(low_rv),.lower_resp_ready(low_rr),.lower_resp_data(low_d),.access_count(accesses),.load_access_count(loads),.store_access_count(stores),.hit_count(hits),.miss_count(misses),.load_miss_count(load_misses),.store_miss_count(store_misses),.refill_word_count(refills),.dirty_writeback_word_count(wb_words),.dirty_eviction_count(evictions),.uncached_access_count(uncached),.miss_stall_cycles(stalls));
  always #5 clk=~clk;
  assign low_r=!pending&&!low_rv;
  always_ff @(posedge clk) begin
    if(!rst_n) begin pending<=0; low_rv<=0; delay<=0; requests<=0; writes<=0; end else begin
      if(low_rv&&low_rr) low_rv<=0;
      if(low_v&&low_r) begin pending<=1; pending_a<=low_a; pending_w<=low_w; pending_wd<=low_wd; pending_ws<=low_ws; delay<=1; requests<=requests+1; if(low_w) writes<=writes+1; end
      if(pending) if(delay) delay<=delay-1; else begin pending<=0; low_rv<=1; low_d<={mem[pending_a+3],mem[pending_a+2],mem[pending_a+1],mem[pending_a]}; if(pending_w) for(i=0;i<4;i=i+1) if(pending_ws[i]) mem[pending_a+i]<=pending_wd[i*8 +:8]; end
    end
  end
  task automatic request(input logic wr,input [31:0] a,input [31:0] wd,input [3:0] ws, input [31:0] expected);
    begin @(negedge clk); cpu_w=wr; cpu_a=a; cpu_wd=wd; cpu_ws=ws; cpu_v=1; while(!cpu_r) @(posedge clk); @(posedge clk); @(negedge clk); cpu_v=0; while(!cpu_rv) @(posedge clk); if(!wr && cpu_d!==expected) $fatal(1,"response addr=%h got=%h expected=%h",a,cpu_d,expected); @(posedge clk); end
  endtask
  function automatic [31:0] word(input integer a); word={mem[a+3],mem[a+2],mem[a+1],mem[a]}; endfunction
  initial begin
    cpu_v=0; cpu_w=0; cpu_a=0; cpu_wd=0; cpu_ws=0; cpu_rr=1; for(i=0;i<16384;i=i+1) mem[i]=i[7:0]; repeat(3) @(posedge clk); rst_n=1;
    request(0,32'h000,0,0,32'h03020100); request(0,32'h004,0,0,32'h07060504); request(0,32'h008,0,0,32'h0b0a0908); request(0,32'h00c,0,0,32'h0f0e0d0c);
    request(1,32'h004,32'haabbccdd,4'b0011,0); request(0,32'h004,0,0,32'h0706ccdd);
    request(1,32'h008,32'h11223344,4'b1111,0); request(1,32'h00c,32'h55667788,4'b1100,0);
    request(0,32'h1000,0,0,32'h03020100); request(0,32'h2000,0,0,32'h03020100);
    if(word(8)!==32'h11223344 || word(12)!==32'h55660d0c) $fatal(1,"dirty eviction contents");
    request(1,32'h600,32'hcafebabe,4'b1111,0); request(0,32'h600,0,0,32'hcafebabe);
    if(accesses!==hits+misses+uncached || refills!==12 || wb_words!==4 || evictions!==1 || uncached!==2 || writes!==5) $fatal(1,"counter or traffic accounting");
    rst_n=0; repeat(2) @(posedge clk); rst_n=1; request(0,0,0,0,32'h03020100); if(misses!==1||refills!==4) $fatal(1,"reset invalidation");
    $display("PASS l1d: refill/hit, byte and word merge, write-allocate, dirty writeback, replacement, uncached bypass, delayed response, reset, counters"); $finish;
  end
endmodule
