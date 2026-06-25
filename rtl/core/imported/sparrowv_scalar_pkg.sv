package sparrowv_scalar_pkg;
  typedef enum logic [3:0] {
    ALU_ADD, ALU_SUB, ALU_SLL, ALU_SLT, ALU_SLTU, ALU_XOR, ALU_SRL, ALU_SRA,
    ALU_OR, ALU_AND
  } alu_op_t;

  typedef enum logic [2:0] {MEM_NONE, MEM_LOAD, MEM_STORE} mem_op_t;
  typedef enum logic [1:0] {MEM_ATOMIC_NONE, MEM_ATOMIC_LR, MEM_ATOMIC_SC} mem_atomic_t;
  typedef enum logic [2:0] {SZ_BYTE, SZ_HALF, SZ_WORD} mem_size_t;
  typedef enum logic [3:0] {
    CAUSE_ILLEGAL = 4'd2, CAUSE_I_MISALIGN = 4'd0, CAUSE_L_MISALIGN = 4'd4,
    CAUSE_S_MISALIGN = 4'd6, CAUSE_ECALL = 4'd11, CAUSE_EBREAK = 4'd3
  } cause_t;
endpackage
