module shared_memory_controller #(
  parameter integer MEM_BYTES = 256 * 1024,
  parameter integer READ_LATENCY = 2,
  parameter integer WRITE_LATENCY = 2,
  parameter PROGRAM_IMAGE = ""
) (
  input logic clk, input logic rst_n, input logic req_valid, output logic req_ready,
  input logic [1:0] req_core, input logic req_port, input logic req_write, input logic [31:0] req_addr,
  input logic [31:0] req_wdata, input logic [3:0] req_wstrb,
  output logic resp_valid, input logic resp_ready, output logic [1:0] resp_core,
  output logic resp_port, output logic [31:0] resp_data
);
  logic [7:0] mem [0:MEM_BYTES-1];
  logic busy, saved_write, saved_port;
  logic [1:0] saved_core;
  logic [31:0] saved_addr, saved_wdata;
  logic [3:0] saved_wstrb;
  integer count;
  integer b;
  function automatic logic mapped_sram(input logic [31:0] a);
    mapped_sram = (a <= MEM_BYTES-4);
  endfunction
  always_comb begin
    req_ready = !busy && !resp_valid;
    resp_core = saved_core; resp_port = saved_port;
  end
  initial begin
    for (b = 0; b < MEM_BYTES; b = b + 1) mem[b] = 8'd0;
    if (PROGRAM_IMAGE != "") $readmemh(PROGRAM_IMAGE, mem);
  end
  always_ff @(posedge clk) begin
    if (!rst_n) begin
      busy <= 1'b0; resp_valid <= 1'b0; resp_data <= '0; count <= 0;
      saved_core <= '0; saved_port <= '0; saved_write <= '0; saved_addr <= '0; saved_wdata <= '0; saved_wstrb <= '0;
    end else begin
      if (resp_valid && resp_ready) resp_valid <= 1'b0;
      if (req_valid && req_ready) begin
        busy <= 1'b1; saved_core <= req_core; saved_port <= req_port; saved_write <= req_write;
        saved_addr <= req_addr; saved_wdata <= req_wdata; saved_wstrb <= req_wstrb;
        count <= req_write ? WRITE_LATENCY : READ_LATENCY;
      end else if (busy) begin
        if (count > 1) count <= count - 1;
        else begin
          busy <= 1'b0; resp_valid <= 1'b1;
          if (saved_addr == 32'h1000_0000 && !saved_write) resp_data <= {30'd0, saved_core};
          else if (mapped_sram(saved_addr)) begin
            resp_data <= {mem[saved_addr+3], mem[saved_addr+2], mem[saved_addr+1], mem[saved_addr]};
            if (saved_write) for (b = 0; b < 4; b = b + 1) if (saved_wstrb[b]) mem[saved_addr+b] <= saved_wdata[8*b +: 8];
          end else resp_data <= 32'd0;
        end
      end
    end
  end
  always_ff @(posedge clk) if (rst_n && saved_write && busy && count == 1 && mapped_sram(saved_addr))
    assert ((saved_addr + 3) < MEM_BYTES) else $error("SRAM write out of range");
  always_ff @(posedge clk) if (rst_n) begin
    assert (!(resp_valid && !resp_ready && req_ready)) else $error("controller accepted while response pending");
    assert (!(req_valid && req_ready && busy)) else $error("controller accepted a second active transaction");
  end
endmodule
