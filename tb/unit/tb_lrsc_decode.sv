module tb_lrsc_decode;
  import sparrowv_scalar_pkg::*;
  logic [31:0] instr;
  logic legal, reg_write, use_imm, load_unsigned, branch, branch_unsigned, jal, jalr, ecall, ebreak;
  logic [1:0] result_sel, branch_kind;
  alu_op_t alu_op;
  mem_op_t mem_op;
  mem_size_t mem_size;
  mem_atomic_t mem_atomic;

  rv32_decoder dut(.instr, .legal, .reg_write, .use_imm, .result_sel, .alu_op,
    .mem_op, .mem_size, .mem_atomic, .load_unsigned, .branch, .branch_unsigned,
    .branch_kind, .jal, .jalr, .ecall, .ebreak);

  task automatic check_lr(input logic [31:0] i);
    begin
      instr = i; #1;
      if (!legal || !reg_write || mem_op != MEM_LOAD || mem_size != SZ_WORD ||
          mem_atomic != MEM_ATOMIC_LR)
        $fatal(1, "LR.W decode failed instr=%h legal=%0b mem_op=%0d atomic=%0d", instr, legal, mem_op, mem_atomic);
    end
  endtask

  task automatic check_sc(input logic [31:0] i);
    begin
      instr = i; #1;
      if (!legal || !reg_write || mem_op != MEM_STORE || mem_size != SZ_WORD ||
          mem_atomic != MEM_ATOMIC_SC)
        $fatal(1, "SC.W decode failed instr=%h legal=%0b mem_op=%0d atomic=%0d", instr, legal, mem_op, mem_atomic);
    end
  endtask

  initial begin
    check_lr(32'h1005_22af); // lr.w x5,(x10)
    check_lr(32'h1605_22af); // lr.w x5,(x10) with aq/rl accepted
    check_sc(32'h18b5_232f); // sc.w x6,x11,(x10)
    instr = 32'h1015_22af; #1; // LR.W with rs2!=0 is illegal.
    if (legal) $fatal(1, "LR.W rs2!=0 decoded as legal");
    instr = 32'h08b5_232f; #1; // AMOSWAP.W remains outside the milestone.
    if (legal) $fatal(1, "AMO decoded as legal");
    $display("PASS lrsc decode: LR.W, SC.W, LR rs2 zero rule, aq/rl ignored, AMOs excluded");
    $finish;
  end
endmodule
