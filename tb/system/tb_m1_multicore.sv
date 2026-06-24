module tb_m1_multicore;
  logic clk=0, rst_n=0; integer cycles, hart;
  sparrow_cluster_top #(.MEM_BYTES(4096), .READ_LATENCY(2), .WRITE_LATENCY(2),
                        .PROGRAM_IMAGE("sw/tests/m1_multicore.hex")) dut(.clk, .rst_n);
  always #5 clk=~clk;
  function automatic [31:0] word(input integer addr);
    word={dut.u_mem.mem[addr+3],dut.u_mem.mem[addr+2],dut.u_mem.mem[addr+1],dut.u_mem.mem[addr]};
  endfunction
  initial begin
    repeat (3) @(posedge clk); rst_n=1;
    for (cycles=0; cycles<12000; cycles=cycles+1) begin
      @(posedge clk);
      if (word(32'h600)==1 && word(32'h604)==1 && word(32'h608)==1 && word(32'h60c)==1) break;
    end
    if (cycles == 12000) $fatal(1,"multicore completion timeout");
    for (hart=0; hart<4; hart=hart+1) begin
      if (word(32'h400+4*hart) !== 32'h234+hart) $fatal(1,"shared checksum hart %0d",hart);
      if (word(32'h500+16*hart) !== hart) $fatal(1,"partition word hart %0d",hart);
      if (dut.u_mem.mem[32'h504+16*hart] !== 8'h40+hart) $fatal(1,"partition byte hart %0d",hart);
      if (word(32'h6f0-256*hart) !== hart) $fatal(1,"private stack hart %0d got %h",hart,word(32'h6f0-256*hart));
    end
    if (word(32'h300) !== 32'h234 || word(32'h308) !== 1) $fatal(1,"single-writer initialization");
    $display("PASS multicore: 4 stack/ID, shared-read, partition-write, byte-write, and completion tests");
    $finish;
  end
endmodule
