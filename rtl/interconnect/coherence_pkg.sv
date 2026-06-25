package coherence_pkg;
  localparam logic [2:0] BUS_RD    = 3'd0;
  localparam logic [2:0] BUS_RDX   = 3'd1;
  localparam logic [2:0] BUS_UPGR  = 3'd2;
  localparam logic [2:0] WRITEBACK = 3'd3;
  localparam integer COH_BLOCK_BYTES = 16;
  localparam integer COH_BLOCK_WORDS = 4;
endpackage
