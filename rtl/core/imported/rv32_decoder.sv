module rv32_decoder(
  input logic [31:0] instr,
  output logic legal, output logic reg_write, output logic use_imm,
  output logic [1:0] result_sel, output sparrowv_scalar_pkg::alu_op_t alu_op,
  output sparrowv_scalar_pkg::mem_op_t mem_op, output sparrowv_scalar_pkg::mem_size_t mem_size,
  output logic load_unsigned, output logic branch, output logic branch_unsigned,
  output logic [1:0] branch_kind, output logic jal, output logic jalr,
  output logic ecall, output logic ebreak
);
  import sparrowv_scalar_pkg::*;
  logic [6:0] opcode; logic [2:0] funct3; logic [6:0] funct7;
  always_comb begin
    opcode=instr[6:0]; funct3=instr[14:12]; funct7=instr[31:25];
    legal=1'b1; reg_write=1'b0; use_imm=1'b0; result_sel=2'd0; alu_op=ALU_ADD;
    mem_op=MEM_NONE; mem_size=SZ_WORD; load_unsigned=1'b0; branch=1'b0; branch_unsigned=1'b0;
    branch_kind=2'd0; jal=1'b0; jalr=1'b0; ecall=1'b0; ebreak=1'b0;
    unique case(opcode)
      7'b0110111: begin reg_write=1'b1; result_sel=2'd2; end // LUI
      7'b0010111: begin reg_write=1'b1; result_sel=2'd3; end // AUIPC
      7'b1101111: begin reg_write=1'b1; result_sel=2'd1; jal=1'b1; end
      7'b1100111: begin
        if (funct3==3'd0) begin reg_write=1'b1; result_sel=2'd1; jalr=1'b1; use_imm=1'b1; end
        else legal=1'b0;
      end
      7'b1100011: begin
        branch=1'b1;
        unique case(funct3)
          3'd0: branch_kind=2'd0; // beq
          3'd1: branch_kind=2'd1; // bne
          3'd4: branch_kind=2'd2; // blt
          3'd5: branch_kind=2'd3; // bge
          3'd6: begin branch_kind=2'd2; branch_unsigned=1'b1; end
          3'd7: begin branch_kind=2'd3; branch_unsigned=1'b1; end
          default: begin legal=1'b0; branch=1'b0; end
        endcase
      end
      7'b0000011: begin
        reg_write=1'b1; result_sel=2'd0; use_imm=1'b1; mem_op=MEM_LOAD;
        unique case(funct3)
          3'd0: mem_size=SZ_BYTE;
          3'd1: mem_size=SZ_HALF;
          3'd2: mem_size=SZ_WORD;
          3'd4: begin mem_size=SZ_BYTE; load_unsigned=1'b1; end
          3'd5: begin mem_size=SZ_HALF; load_unsigned=1'b1; end
          default: begin legal=1'b0; mem_op=MEM_NONE; reg_write=1'b0; end
        endcase
      end
      7'b0100011: begin
        use_imm=1'b1; mem_op=MEM_STORE;
        unique case(funct3)
          3'd0: mem_size=SZ_BYTE;
          3'd1: mem_size=SZ_HALF;
          3'd2: mem_size=SZ_WORD;
          default: begin legal=1'b0; mem_op=MEM_NONE; end
        endcase
      end
      7'b0010011: begin
        reg_write=1'b1; use_imm=1'b1;
        unique case(funct3)
          3'd0: alu_op=ALU_ADD;
          3'd2: alu_op=ALU_SLT;
          3'd3: alu_op=ALU_SLTU;
          3'd4: alu_op=ALU_XOR;
          3'd6: alu_op=ALU_OR;
          3'd7: alu_op=ALU_AND;
          3'd1: if (funct7==7'd0) alu_op=ALU_SLL; else begin legal=1'b0; reg_write=1'b0; end
          3'd5: if (funct7==7'd0) alu_op=ALU_SRL; else if (funct7==7'b0100000) alu_op=ALU_SRA; else begin legal=1'b0; reg_write=1'b0; end
          default: begin legal=1'b0; reg_write=1'b0; end
        endcase
      end
      7'b0110011: begin
        reg_write=1'b1;
        unique case(funct3)
          3'd0: if (funct7==7'd0) alu_op=ALU_ADD; else if(funct7==7'b0100000) alu_op=ALU_SUB; else begin legal=1'b0; reg_write=1'b0; end
          3'd1: if (funct7==7'd0) alu_op=ALU_SLL; else begin legal=1'b0; reg_write=1'b0; end
          3'd2: if (funct7==7'd0) alu_op=ALU_SLT; else begin legal=1'b0; reg_write=1'b0; end
          3'd3: if (funct7==7'd0) alu_op=ALU_SLTU; else begin legal=1'b0; reg_write=1'b0; end
          3'd4: if (funct7==7'd0) alu_op=ALU_XOR; else begin legal=1'b0; reg_write=1'b0; end
          3'd5: if (funct7==7'd0) alu_op=ALU_SRL; else if(funct7==7'b0100000) alu_op=ALU_SRA; else begin legal=1'b0; reg_write=1'b0; end
          3'd6: if (funct7==7'd0) alu_op=ALU_OR; else begin legal=1'b0; reg_write=1'b0; end
          3'd7: if (funct7==7'd0) alu_op=ALU_AND; else begin legal=1'b0; reg_write=1'b0; end
          default: begin legal=1'b0; reg_write=1'b0; end
        endcase
      end
      7'b0001111: if (funct3!=3'd0) legal=1'b0;
      7'b1110011: begin
        if (instr==32'h00000073) ecall=1'b1;
        else if (instr==32'h00100073) ebreak=1'b1;
        else legal=1'b0;
      end
      default: legal=1'b0;
    endcase
  end
endmodule
