module tb_l1i;
  logic clk=0, rst_n=0;
  logic cpu_v, cpu_r, cpu_rv, cpu_rr; logic [31:0] cpu_a, cpu_d;
  logic low_v, low_r, low_rv, low_rr; logic [31:0] low_a, low_d;
  logic [63:0] accesses, hits, misses, refill_words, miss_stalls;
  logic pending; logic [31:0] pending_addr; integer delay; integer requests;

  l1_instruction_cache dut(.clk,.rst_n,.cpu_req_valid(cpu_v),.cpu_req_ready(cpu_r),.cpu_req_addr(cpu_a),
    .cpu_resp_valid(cpu_rv),.cpu_resp_ready(cpu_rr),.cpu_resp_data(cpu_d),.lower_req_valid(low_v),
    .lower_req_ready(low_r),.lower_req_addr(low_a),.lower_resp_valid(low_rv),.lower_resp_ready(low_rr),
    .lower_resp_data(low_d),.access_count(accesses),.hit_count(hits),.miss_count(misses),
    .refill_word_count(refill_words),.miss_stall_cycles(miss_stalls));
  always #5 clk=~clk;
  assign low_r = !pending && !low_rv;
  always_ff @(posedge clk) begin
    if (!rst_n) begin pending<=0; pending_addr<=0; delay<=0; low_rv<=0; low_d<=0; requests<=0; end
    else begin
      if (low_rv && low_rr) low_rv<=0;
      if (low_v && low_r) begin pending<=1; pending_addr<=low_a; delay<=2; requests<=requests+1; end
      if (pending) begin
        if (delay != 0) delay<=delay-1;
        else begin pending<=0; low_rv<=1; low_d<=32'h1000_0000 + pending_addr; end
      end
    end
  end
  task automatic fetch(input [31:0] addr);
    begin
      @(negedge clk); cpu_a=addr; cpu_v=1;
      while (!cpu_r) @(posedge clk);
      @(posedge clk); @(negedge clk); cpu_v=0;
      while (!cpu_rv) @(posedge clk);
      if (cpu_d !== 32'h1000_0000 + addr) $fatal(1,"L1I word mismatch addr=%h got=%h",addr,cpu_d);
      @(posedge clk);
    end
  endtask
  initial begin
    cpu_v=0; cpu_a=0; cpu_rr=1;
    repeat(3) @(posedge clk); rst_n=1;
    fetch(32'h0000_0000); fetch(32'h0000_0004); fetch(32'h0000_0008); fetch(32'h0000_000c);
    if (requests != 4 || accesses != 4 || hits != 3 || misses != 1 || refill_words != 4) $fatal(1,"cold refill/hit counters");
    fetch(32'h0000_0400); fetch(32'h0000_0800); fetch(32'h0000_0000);
    if (requests != 16 || accesses != 7 || hits != 3 || misses != 4 || refill_words != 16) $fatal(1,"same-set replacement or counters");
    rst_n=0; repeat(2) @(posedge clk); rst_n=1;
    fetch(32'h0000_0000);
    if (accesses != 1 || hits != 0 || misses != 1 || refill_words != 4) $fatal(1,"reset invalidation");
    $display("PASS l1i: cold refill, offsets, hits, conflicts, deterministic replacement, delayed responses, reset, counters");
    $finish;
  end
endmodule
