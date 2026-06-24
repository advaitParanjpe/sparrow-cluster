module l1_instruction_cache #(
  parameter integer ADDR_WIDTH = 32,
  parameter integer DATA_WIDTH = 32,
  parameter integer NUM_SETS = 64,
  parameter integer NUM_WAYS = 2,
  parameter integer BLOCK_BYTES = 16
) (
  input logic clk, input logic rst_n,
  input logic cpu_req_valid, output logic cpu_req_ready, input logic [ADDR_WIDTH-1:0] cpu_req_addr,
  output logic cpu_resp_valid, input logic cpu_resp_ready, output logic [DATA_WIDTH-1:0] cpu_resp_data,
  output logic lower_req_valid, input logic lower_req_ready, output logic [ADDR_WIDTH-1:0] lower_req_addr,
  input logic lower_resp_valid, output logic lower_resp_ready, input logic [DATA_WIDTH-1:0] lower_resp_data,
  output logic [63:0] access_count, output logic [63:0] hit_count, output logic [63:0] miss_count,
  output logic [63:0] refill_word_count, output logic [63:0] miss_stall_cycles
);
  localparam integer WORD_BYTES = DATA_WIDTH / 8;
  localparam integer WORDS_PER_BLOCK = BLOCK_BYTES / WORD_BYTES;
  localparam integer OFFSET_BITS = $clog2(BLOCK_BYTES);
  localparam integer SET_BITS = $clog2(NUM_SETS);
  localparam integer WORD_BITS = $clog2(WORDS_PER_BLOCK);
  localparam integer TAG_BITS = ADDR_WIDTH - OFFSET_BITS - SET_BITS;
  localparam integer WAY_BITS = $clog2(NUM_WAYS);
  localparam integer WORD_COUNT_BITS = $clog2(WORDS_PER_BLOCK + 1);
  localparam integer STATE_IDLE = 0, STATE_REFILL_REQ = 1, STATE_REFILL_WAIT = 2, STATE_RESP = 3;

  logic valid_array [0:NUM_WAYS-1][0:NUM_SETS-1];
  logic [TAG_BITS-1:0] tag_array [0:NUM_WAYS-1][0:NUM_SETS-1];
  logic [DATA_WIDTH-1:0] data_array [0:NUM_WAYS-1][0:NUM_SETS-1][0:WORDS_PER_BLOCK-1];
  logic replacement [0:NUM_SETS-1];
  logic [1:0] state;
  logic [ADDR_WIDTH-1:0] refill_base;
  logic [SET_BITS-1:0] saved_set;
  logic [TAG_BITS-1:0] saved_tag;
  logic [WORD_BITS-1:0] saved_word;
  logic [WAY_BITS-1:0] victim_way;
  logic [WORD_COUNT_BITS-1:0] refill_word;
  logic [DATA_WIDTH-1:0] response_data;
  logic hit_any, hit_way;
  logic [1:0] hit_matches;
  integer way, set_index;

  always_comb begin
    hit_any = 1'b0;
    hit_way = 1'b0;
    hit_matches = '0;
    for (way = 0; way < NUM_WAYS; way = way + 1) begin
      if (valid_array[way][cpu_req_addr[OFFSET_BITS + SET_BITS - 1:OFFSET_BITS]] &&
          tag_array[way][cpu_req_addr[OFFSET_BITS + SET_BITS - 1:OFFSET_BITS]] == cpu_req_addr[ADDR_WIDTH-1:OFFSET_BITS + SET_BITS]) begin
        hit_any = 1'b1;
        hit_way = way[WAY_BITS-1:0];
        hit_matches = hit_matches + 1'b1;
      end
    end
    cpu_req_ready = (state == STATE_IDLE);
    cpu_resp_valid = (state == STATE_RESP);
    cpu_resp_data = response_data;
    lower_req_valid = (state == STATE_REFILL_REQ);
    lower_req_addr = refill_base + (refill_word * WORD_BYTES);
    lower_resp_ready = (state == STATE_REFILL_WAIT);
  end

  always_ff @(posedge clk) begin
    if (!rst_n) begin
      state <= STATE_IDLE;
      refill_base <= '0; saved_set <= '0; saved_tag <= '0; saved_word <= '0;
      victim_way <= '0; refill_word <= '0; response_data <= '0;
      access_count <= '0; hit_count <= '0; miss_count <= '0; refill_word_count <= '0; miss_stall_cycles <= '0;
      for (way = 0; way < NUM_WAYS; way = way + 1)
        for (set_index = 0; set_index < NUM_SETS; set_index = set_index + 1)
          valid_array[way][set_index] <= 1'b0;
      for (set_index = 0; set_index < NUM_SETS; set_index = set_index + 1) replacement[set_index] <= 1'b0;
    end else begin
      if (state == STATE_REFILL_REQ || state == STATE_REFILL_WAIT) miss_stall_cycles <= miss_stall_cycles + 1'b1;
      if (state == STATE_IDLE && cpu_req_valid && cpu_req_ready) begin
        access_count <= access_count + 1'b1;
        saved_set <= cpu_req_addr[OFFSET_BITS + SET_BITS - 1:OFFSET_BITS];
        saved_tag <= cpu_req_addr[ADDR_WIDTH-1:OFFSET_BITS + SET_BITS];
        saved_word <= cpu_req_addr[OFFSET_BITS-1:2];
        if (hit_any) begin
          hit_count <= hit_count + 1'b1;
          response_data <= data_array[hit_way][cpu_req_addr[OFFSET_BITS + SET_BITS - 1:OFFSET_BITS]][cpu_req_addr[OFFSET_BITS-1:2]];
          replacement[cpu_req_addr[OFFSET_BITS + SET_BITS - 1:OFFSET_BITS]] <= ~hit_way;
          state <= STATE_RESP;
        end else begin
          miss_count <= miss_count + 1'b1;
          refill_base <= {cpu_req_addr[ADDR_WIDTH-1:OFFSET_BITS], {OFFSET_BITS{1'b0}}};
          refill_word <= '0;
          if (!valid_array[0][cpu_req_addr[OFFSET_BITS + SET_BITS - 1:OFFSET_BITS]]) victim_way <= '0;
          else if (!valid_array[1][cpu_req_addr[OFFSET_BITS + SET_BITS - 1:OFFSET_BITS]]) victim_way <= 1'b1;
          else victim_way <= replacement[cpu_req_addr[OFFSET_BITS + SET_BITS - 1:OFFSET_BITS]];
          state <= STATE_REFILL_REQ;
        end
      end
      if (state == STATE_REFILL_REQ && lower_req_valid && lower_req_ready) state <= STATE_REFILL_WAIT;
      if (state == STATE_REFILL_WAIT && lower_resp_valid && lower_resp_ready) begin
        data_array[victim_way][saved_set][refill_word[WORD_BITS-1:0]] <= lower_resp_data;
        refill_word_count <= refill_word_count + 1'b1;
        if (refill_word == WORDS_PER_BLOCK - 1) begin
          tag_array[victim_way][saved_set] <= saved_tag;
          valid_array[victim_way][saved_set] <= 1'b1;
          replacement[saved_set] <= ~victim_way;
          response_data <= (saved_word == refill_word[WORD_BITS-1:0]) ? lower_resp_data : data_array[victim_way][saved_set][saved_word];
          state <= STATE_RESP;
        end else begin
          refill_word <= refill_word + 1'b1;
          state <= STATE_REFILL_REQ;
        end
      end
      if (state == STATE_RESP && cpu_resp_valid && cpu_resp_ready) state <= STATE_IDLE;
    end
  end

  always_ff @(posedge clk) if (rst_n) begin
    assert (!(hit_any && !valid_array[hit_way][cpu_req_addr[OFFSET_BITS + SET_BITS - 1:OFFSET_BITS]])) else $error("L1I hit from invalid way");
    assert (hit_matches <= 1) else $error("L1I multiple matching ways");
    assert (!(state == STATE_REFILL_REQ && refill_word >= WORDS_PER_BLOCK)) else $error("L1I refill word out of range");
    assert (!(state == STATE_REFILL_REQ && refill_base[OFFSET_BITS-1:0] != 0)) else $error("L1I refill address not aligned");
    assert (!(cpu_resp_valid && state != STATE_RESP)) else $error("L1I response without tracked request");
    assert (victim_way < NUM_WAYS) else $error("L1I illegal replacement way");
    assert (access_count == hit_count + miss_count) else $error("L1I counter accounting");
  end
endmodule
