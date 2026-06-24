module rv32_alu (
  input sparrowv_scalar_pkg::alu_op_t op,
  input logic [31:0] a, input logic [31:0] b, output logic [31:0] y
);
  import sparrowv_scalar_pkg::*;
  always_comb begin
    unique case (op)
      ALU_ADD:  y = a + b;
      ALU_SUB:  y = a - b;
      ALU_SLL:  y = a << b[4:0];
      ALU_SLT:  y = {31'd0, ($signed(a) < $signed(b))};
      ALU_SLTU: y = {31'd0, (a < b)};
      ALU_XOR:  y = a ^ b;
      ALU_SRL:  y = a >> b[4:0];
      ALU_SRA:  y = $signed(a) >>> b[4:0];
      ALU_OR:   y = a | b;
      ALU_AND:  y = a & b;
      default:  y = 32'd0;
    endcase
  end
endmodule
