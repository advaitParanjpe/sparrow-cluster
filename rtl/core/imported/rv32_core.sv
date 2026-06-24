module rv32_core #(
  parameter logic [31:0] RESET_PC = 32'h0000_0000,
  parameter logic [31:0] MTVEC_RESET = 32'h0000_0100
) (
  input logic clk, input logic rst_n,
  output logic imem_req_valid, input logic imem_req_ready, output logic [31:0] imem_req_addr,
  input logic imem_resp_valid, output logic imem_resp_ready, input logic [31:0] imem_resp_data,
  output logic dmem_req_valid, input logic dmem_req_ready, output logic dmem_req_write,
  output logic [31:0] dmem_req_addr, output logic [31:0] dmem_req_wdata, output logic [3:0] dmem_req_wstrb,
  input logic dmem_resp_valid, output logic dmem_resp_ready, input logic [31:0] dmem_resp_data,
  output logic trap_valid, output logic [31:0] mepc, output logic [31:0] mcause, output logic [31:0] mtvec,
  output logic [63:0] cycle_count, output logic [63:0] instret_count,
  output logic retire_valid, output logic [31:0] retire_pc, output logic [31:0] retire_instr,
  output logic retire_rd_we, output logic [4:0] retire_rd, output logic [31:0] retire_rd_data,
  output logic retire_mem_we, output logic [31:0] retire_mem_addr, output logic [31:0] retire_mem_data,
  output logic [3:0] retire_mem_wstrb, output logic retire_trap, output logic [31:0] retire_cause,
  output logic [63:0] imem_stall_cycles, output logic [63:0] dmem_stall_cycles, output logic [63:0] dep_stall_cycles, output logic [63:0] control_flush_cycles
);
  import sparrowv_scalar_pkg::*;
  logic [31:0] pc, if_pc, if_instr, req_addr, out_addr; logic fetch_pending, req_valid, req_epoch, out_epoch, fetch_epoch, if_valid, mw_valid, mw_req_sent;
  logic [31:0] mw_result, mw_addr, mw_store_data, mw_pc, mw_instr;
  logic [4:0] mw_rd; logic mw_reg_write, mw_trap; cause_t mw_cause;
  mem_op_t mw_mem_op; mem_size_t mw_mem_size; logic mw_load_unsigned;
  logic [4:0] rs1, rs2, rd; logic [31:0] rs1_data, rs2_data, rs1_fwd, rs2_fwd, imm, alu_y;
  logic legal, dec_reg_write, use_imm, branch, branch_unsigned, jal, jalr, ecall, ebreak, branch_taken;
  logic [1:0] result_sel, branch_kind; alu_op_t alu_op; mem_op_t dec_mem_op; mem_size_t dec_mem_size; logic dec_load_unsigned;
  logic [31:0] next_result, target; logic dec_misalign; cause_t dec_cause;
  logic rf_we; logic [4:0] rf_waddr; logic [31:0] rf_wdata;

  assign rs1=if_instr[19:15]; assign rs2=if_instr[24:20]; assign rd=if_instr[11:7];
  rv32_regfile rf(.clk, .rst_n, .rs1_addr(rs1), .rs2_addr(rs2), .rs1_data, .rs2_data, .we(rf_we), .rd_addr(rf_waddr), .rd_data(rf_wdata));
  rv32_immediate ig(.instr(if_instr), .imm);
  rv32_decoder dec(.instr(if_instr), .legal, .reg_write(dec_reg_write), .use_imm, .result_sel, .alu_op, .mem_op(dec_mem_op), .mem_size(dec_mem_size), .load_unsigned(dec_load_unsigned), .branch, .branch_unsigned, .branch_kind, .jal, .jalr, .ecall, .ebreak);
  always_comb begin
    rs1_fwd=rs1_data; rs2_fwd=rs2_data;
    if (mw_valid && !mw_trap && mw_mem_op==MEM_NONE && mw_reg_write && mw_rd!=0 && mw_rd==rs1) rs1_fwd=mw_result;
    if (mw_valid && !mw_trap && mw_mem_op==MEM_NONE && mw_reg_write && mw_rd!=0 && mw_rd==rs2) rs2_fwd=mw_result;
  end
  rv32_alu alu(.op(alu_op), .a(rs1_fwd), .b(use_imm ? imm : rs2_fwd), .y(alu_y));

  always_comb begin
    unique case (branch_kind)
      2'd0: branch_taken = rs1_fwd == rs2_fwd;
      2'd1: branch_taken = rs1_fwd != rs2_fwd;
      2'd2: branch_taken = branch_unsigned ? (rs1_fwd < rs2_fwd) : ($signed(rs1_fwd) < $signed(rs2_fwd));
      default: branch_taken = branch_unsigned ? (rs1_fwd >= rs2_fwd) : ($signed(rs1_fwd) >= $signed(rs2_fwd));
    endcase
    target = jalr ? ((rs1_fwd + imm) & 32'hffff_fffe) : (if_pc + imm);
    unique case (result_sel)
      2'd1: next_result = if_pc + 32'd4;
      2'd2: next_result = imm;
      2'd3: next_result = if_pc + imm;
      default: next_result = alu_y;
    endcase
    dec_misalign = (if_pc[1:0] != 2'b00) || ((dec_mem_op == MEM_LOAD || dec_mem_op == MEM_STORE) &&
                    ((dec_mem_size == SZ_WORD && alu_y[1:0] != 2'b00) || (dec_mem_size == SZ_HALF && alu_y[0])) ) ||
                    ((jal || jalr || (branch && branch_taken)) && target[1:0] != 2'b00);
    if (!legal) dec_cause=CAUSE_ILLEGAL;
    else if (if_pc[1:0] != 2'b00 || ((jal || jalr || (branch && branch_taken)) && target[1:0] != 2'b00)) dec_cause=CAUSE_I_MISALIGN;
    else if (dec_mem_op == MEM_LOAD && dec_misalign) dec_cause=CAUSE_L_MISALIGN;
    else if (dec_mem_op == MEM_STORE && dec_misalign) dec_cause=CAUSE_S_MISALIGN;
    else if (ecall) dec_cause=CAUSE_ECALL;
    else dec_cause=CAUSE_EBREAK;
  end

  always_comb begin
    imem_req_valid = req_valid && !fetch_pending;
    imem_req_addr = req_addr;
    imem_resp_ready = fetch_pending && (!if_valid || out_epoch != fetch_epoch);
    dmem_req_valid = mw_valid && mw_mem_op != MEM_NONE && !mw_req_sent && !mw_trap;
    dmem_req_write = mw_mem_op == MEM_STORE;
    dmem_req_addr = {mw_addr[31:2], 2'b00};
    dmem_req_wdata = mw_store_data << (8 * mw_addr[1:0]);
    unique case(mw_mem_size)
      SZ_BYTE: dmem_req_wstrb = 4'b0001 << mw_addr[1:0];
      SZ_HALF: dmem_req_wstrb = mw_addr[1] ? 4'b1100 : 4'b0011;
      default: dmem_req_wstrb = 4'b1111;
    endcase
    dmem_resp_ready = mw_valid && mw_mem_op != MEM_NONE && mw_req_sent;
    rf_we=1'b0; rf_waddr=mw_rd; rf_wdata=mw_result;
    if (mw_valid && !mw_trap && mw_mem_op == MEM_NONE && mw_reg_write) rf_we=1'b1;
    if (mw_valid && !mw_trap && mw_mem_op == MEM_LOAD && mw_req_sent && dmem_resp_valid) begin
      rf_we=mw_reg_write;
      unique case(mw_mem_size)
        SZ_BYTE: rf_wdata = mw_load_unsigned ? {24'd0,dmem_resp_data[8*mw_addr[1:0] +: 8]} : {{24{dmem_resp_data[8*mw_addr[1:0]+7]}},dmem_resp_data[8*mw_addr[1:0] +: 8]};
        SZ_HALF: if (mw_addr[1]) rf_wdata = mw_load_unsigned ? {16'd0,dmem_resp_data[31:16]} : {{16{dmem_resp_data[31]}},dmem_resp_data[31:16]};
                 else rf_wdata = mw_load_unsigned ? {16'd0,dmem_resp_data[15:0]} : {{16{dmem_resp_data[15]}},dmem_resp_data[15:0]};
        default: rf_wdata = dmem_resp_data;
      endcase
    end
  end

  always_ff @(posedge clk) begin
    if (!rst_n) begin
      pc<=RESET_PC; if_pc<=32'd0; if_instr<=32'd0; fetch_pending<=1'b0; req_valid<=1'b1; req_addr<=RESET_PC; req_epoch<=0; out_addr<=0; out_epoch<=0; fetch_epoch<=0; if_valid<=1'b0; mw_valid<=1'b0; mw_req_sent<=1'b0;
      mw_result<=32'd0; mw_addr<=32'd0; mw_store_data<=32'd0; mw_pc<=32'd0; mw_instr<=0; mw_rd<=5'd0; mw_reg_write<=1'b0; mw_trap<=1'b0; mw_cause<=CAUSE_ILLEGAL; mw_mem_op<=MEM_NONE; mw_mem_size<=SZ_WORD; mw_load_unsigned<=1'b0;
      trap_valid<=1'b0; mepc<=32'd0; mcause<=32'd0; mtvec<=MTVEC_RESET; cycle_count<=64'd0; instret_count<=64'd0; retire_valid<=0; retire_trap<=0; retire_pc<=0; retire_instr<=0; retire_rd_we<=0; retire_rd<=0; retire_rd_data<=0; retire_mem_we<=0; retire_mem_addr<=0; retire_mem_data<=0; retire_mem_wstrb<=0; retire_cause<=0; imem_stall_cycles<=0; dmem_stall_cycles<=0; dep_stall_cycles<=0; control_flush_cycles<=0;
    end else begin
      cycle_count <= cycle_count + 64'd1;
      retire_valid<=0; retire_trap<=0; retire_rd_we<=0; retire_mem_we<=0;
      if (imem_req_valid && !imem_req_ready) imem_stall_cycles<=imem_stall_cycles+1;
      if (dmem_req_valid && !dmem_req_ready) dmem_stall_cycles<=dmem_stall_cycles+1;
      if (if_valid && mw_valid && mw_mem_op!=MEM_NONE) dep_stall_cycles<=dep_stall_cycles+1;
      if (imem_req_valid && imem_req_ready) begin fetch_pending<=1'b1; out_addr<=req_addr; out_epoch<=req_epoch; req_valid<=1'b0; if (req_epoch==fetch_epoch) pc<=req_addr+32'd4; end
      if (imem_resp_valid && imem_resp_ready) begin
        fetch_pending<=1'b0;
        if (out_epoch==fetch_epoch) begin if_pc<=out_addr; if_instr<=imem_resp_data; if_valid<=1'b1; end
      end
      if (!req_valid && !fetch_pending && !trap_valid) begin req_valid<=1'b1; req_addr<=pc; req_epoch<=fetch_epoch; end
      if (mw_valid) begin
        if (mw_trap) begin
          trap_valid<=1'b1; mepc<=mw_pc; mcause<={28'd0,mw_cause}; pc<=mtvec; fetch_epoch<=~fetch_epoch; if_valid<=0; mw_valid<=1'b0; mw_req_sent<=1'b0; retire_valid<=1; retire_trap<=1; retire_pc<=mw_pc; retire_instr<=mw_instr; retire_cause<={28'd0,mw_cause};
        end else if (mw_mem_op == MEM_NONE) begin
          mw_valid<=1'b0; instret_count<=instret_count+64'd1; retire_valid<=1; retire_pc<=mw_pc; retire_instr<=mw_instr; retire_rd_we<=mw_reg_write && mw_rd!=0; retire_rd<=mw_rd; retire_rd_data<=mw_result;
        end else begin
          if (dmem_req_valid && dmem_req_ready) mw_req_sent<=1'b1;
          if (dmem_resp_valid && dmem_resp_ready) begin mw_valid<=1'b0; mw_req_sent<=1'b0; instret_count<=instret_count+64'd1; retire_valid<=1; retire_pc<=mw_pc; retire_instr<=mw_instr; retire_rd_we<=mw_reg_write && mw_rd!=0; retire_rd<=mw_rd; retire_rd_data<=rf_wdata; retire_mem_we<=mw_mem_op==MEM_STORE; retire_mem_addr<=mw_addr; retire_mem_data<=mw_store_data; retire_mem_wstrb<=dmem_req_wstrb; end
        end
      end
      if (if_valid && !trap_valid && !imem_req_valid && (!mw_valid || (!mw_trap && mw_mem_op==MEM_NONE))) begin
        mw_valid<=1'b1; mw_pc<=if_pc; mw_instr<=if_instr; mw_rd<=rd; mw_reg_write<=dec_reg_write; mw_result<=next_result; mw_addr<=alu_y; mw_store_data<=rs2_fwd; mw_mem_op<=dec_mem_op; mw_mem_size<=dec_mem_size; mw_load_unsigned<=dec_load_unsigned;
        mw_trap<=(!legal || dec_misalign || ecall || ebreak); mw_cause<=dec_cause; if_valid<=1'b0; mw_req_sent<=1'b0;
        if ((jal || jalr || (branch && branch_taken)) && !dec_misalign) begin pc<=target; fetch_epoch<=~fetch_epoch; if_valid<=1'b0; control_flush_cycles<=control_flush_cycles+1; end
      end
    end
  end
  always_ff @(posedge clk) if (rst_n) begin
    assert (pc[1:0] == 2'b00) else $error("unaligned PC");
    assert (!(rf_we && (!mw_valid || mw_trap))) else $error("invalid stage writeback");
    assert (!(dmem_req_valid && (!mw_valid || mw_trap || mw_mem_op == MEM_NONE))) else $error("invalid store/load request");
    assert (!(mw_trap && rf_we)) else $error("trap writeback");
  end
endmodule
