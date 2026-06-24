module rv32_regfile (
  input logic clk, input logic rst_n,
  input logic [4:0] rs1_addr, input logic [4:0] rs2_addr,
  output logic [31:0] rs1_data, output logic [31:0] rs2_data,
  input logic we, input logic [4:0] rd_addr, input logic [31:0] rd_data
);
  logic [31:0] regs [0:31];
  integer i;
  always_comb begin
    rs1_data = rs1_addr == 5'd0 ? 32'd0 : regs[rs1_addr];
    rs2_data = rs2_addr == 5'd0 ? 32'd0 : regs[rs2_addr];
  end
  always_ff @(posedge clk) begin
    if (!rst_n) begin
      for (i = 0; i < 32; i = i + 1) regs[i] <= 32'd0;
    end else begin
      if (we && rd_addr != 5'd0) regs[rd_addr] <= rd_data;
      regs[0] <= 32'd0;
    end
  end
  always_ff @(posedge clk) if (rst_n) assert(regs[0] == 32'd0) else $error("x0 changed");
endmodule
