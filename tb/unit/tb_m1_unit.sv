module tb_m1_unit;
  logic clk=0, rst_n=0;
  logic [3:0] req; logic ga, gv; logic [1:0] g;
  logic mv, mr, mw, mp, rv, rr; logic [1:0] mc, rc; logic [31:0] ma, md, rd; logic [3:0] ms;
  logic iv, ir, ov, ory, sv, sr, sp, sw, asresp; logic [31:0] ia, od, sa, sd, asdata; logic [3:0] ss;
  integer ticks;
  round_robin_arbiter #(.N(4)) arb(.clk,.rst_n,.req,.grant_accept(ga),.grant_valid(gv),.grant(g));
  shared_memory_controller #(.MEM_BYTES(64),.READ_LATENCY(2),.WRITE_LATENCY(3)) mem(
    .clk,.rst_n,.req_valid(mv),.req_ready(mr),.req_core(mc),.req_port(mp),.req_write(mw),.req_addr(ma),.req_wdata(md),.req_wstrb(ms),.resp_valid(rv),.resp_ready(rr),.resp_core(rc),.resp_port(),.resp_data(rd));
  core_adapter adapter(.clk,.rst_n,.imem_req_valid(iv),.imem_req_ready(ir),.imem_req_addr(ia),.imem_resp_valid(ov),.imem_resp_ready(ory),.imem_resp_data(od),.dmem_req_valid(1'b0),.dmem_req_ready(),.dmem_req_write(1'b0),.dmem_req_addr(0),.dmem_req_wdata(0),.dmem_req_wstrb(4'b0),.dmem_resp_valid(),.dmem_resp_ready(1'b1),.dmem_resp_data(),.sys_req_valid(sv),.sys_req_ready(sr),.sys_req_port(sp),.sys_req_write(sw),.sys_req_addr(sa),.sys_req_wdata(),.sys_req_wstrb(ss),.sys_resp_valid(asresp),.sys_resp_data(asdata),.sys_resp_ready());
  always #5 clk=~clk;
  task automatic submit(input logic write, input [31:0] addr, input [31:0] data, input [3:0] strb, input integer latency);
    begin
      @(negedge clk); mv=1; mw=write; ma=addr; md=data; ms=strb; mc=2; mp=1;
      @(posedge clk); if (!mr) $fatal(1,"controller did not accept request");
      @(negedge clk); mv=0; ticks=0;
      while (!rv) begin @(posedge clk); #1; ticks=ticks+1; end
      if (ticks != latency) $fatal(1,"latency expected %0d got %0d",latency,ticks);
      if (rc != 2 || !mp) $fatal(1,"response source metadata");
      @(posedge clk);
    end
  endtask
  initial begin
    req=0; ga=0; mv=0; mw=0; ma=0; md=0; ms=0; mc=0; mp=0; rr=1; iv=0; ia=0; ory=1; sr=0; asresp=0; asdata=0;
    repeat(2) @(posedge clk); rst_n=1;
    @(negedge clk); req=4'b1111; #1; if (!gv || g!==0) $fatal(1,"initial grant");
    repeat(4) begin ga=1; @(posedge clk); @(negedge clk); end
    if (g!==0) $fatal(1,"continuous request rotation failed"); ga=0; req=0;
    submit(1,0,32'h11223344,4'b1111,3);
    submit(1,0,32'haa00cc00,4'b0101,3);
    submit(0,0,0,0,2); if (rd!==32'h11003300) $fatal(1,"byte enables");
    submit(0,32'h40,0,0,2); if (rd!==0) $fatal(1,"invalid address response");
    // The adapter holds a captured IMEM request stable until the system accepts it and routes only IMEM response.
    @(negedge clk); iv=1; ia=32'h20; #1; @(posedge clk); if (!ir) $fatal(1,"adapter IMEM accept"); @(negedge clk); iv=0;
    if (!sv || sp || sw || sa!==32'h20) $fatal(1,"adapter source capture"); sr=1; @(posedge clk); @(negedge clk); sr=0;
    @(negedge clk); asdata=32'hcafebabe; asresp=1; #1; if (!ov || od!==32'hcafebabe) $fatal(1,"adapter response route"); @(posedge clk); @(negedge clk); asresp=0;
    $display("PASS unit: arbiter, controller latency/byte-enable/error, adapter capture/routing");
    $finish;
  end
endmodule
