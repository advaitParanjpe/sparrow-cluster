module tb_cluster;
  logic clk=0, rst_n=0; integer cycles, i;
  sparrow_cluster_top #(.MEM_BYTES(4096), .READ_LATENCY(2), .WRITE_LATENCY(2)) dut(.clk, .rst_n);
  always #5 clk=~clk;
  initial begin
    for (i=0; i<4096; i=i+1) dut.u_mem.mem[i]=0;
    // read mhartid control aperture; calculate a per-hart result address; store hart*4.
    {dut.u_mem.mem[3],dut.u_mem.mem[2],dut.u_mem.mem[1],dut.u_mem.mem[0]}=32'h100000b7;
    {dut.u_mem.mem[7],dut.u_mem.mem[6],dut.u_mem.mem[5],dut.u_mem.mem[4]}=32'h0000a103;
    {dut.u_mem.mem[11],dut.u_mem.mem[10],dut.u_mem.mem[9],dut.u_mem.mem[8]}=32'h20000193;
    {dut.u_mem.mem[15],dut.u_mem.mem[14],dut.u_mem.mem[13],dut.u_mem.mem[12]}=32'h00211113;
    {dut.u_mem.mem[19],dut.u_mem.mem[18],dut.u_mem.mem[17],dut.u_mem.mem[16]}=32'h002181b3;
    {dut.u_mem.mem[23],dut.u_mem.mem[22],dut.u_mem.mem[21],dut.u_mem.mem[20]}=32'h0021a023;
    {dut.u_mem.mem[27],dut.u_mem.mem[26],dut.u_mem.mem[25],dut.u_mem.mem[24]}=32'h0000006f;
    repeat (3) @(posedge clk); rst_n=1;
    for (cycles=0; cycles<2000; cycles=cycles+1) @(posedge clk);
    if ({dut.u_mem.mem[515],dut.u_mem.mem[514],dut.u_mem.mem[513],dut.u_mem.mem[512]} !== 32'd0) $fatal(1,"hart 0 result");
    if ({dut.u_mem.mem[519],dut.u_mem.mem[518],dut.u_mem.mem[517],dut.u_mem.mem[516]} !== 32'd4) $fatal(1,"hart 1 result");
    if ({dut.u_mem.mem[523],dut.u_mem.mem[522],dut.u_mem.mem[521],dut.u_mem.mem[520]} !== 32'd8) $fatal(1,"hart 2 result");
    if ({dut.u_mem.mem[527],dut.u_mem.mem[526],dut.u_mem.mem[525],dut.u_mem.mem[524]} !== 32'd12) $fatal(1,"hart 3 result");
    $display("PASS cluster: four harts observed IDs 0,1,2,3"); $finish;
  end
endmodule
