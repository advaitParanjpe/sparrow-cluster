module l1_data_cache #(
  parameter integer ADDR_WIDTH=32, DATA_WIDTH=32, NUM_SETS=64, NUM_WAYS=2, BLOCK_BYTES=16
) (
  input logic clk, rst_n, input logic cpu_req_valid, output logic cpu_req_ready, input logic cpu_req_write,
  input logic [ADDR_WIDTH-1:0] cpu_req_addr, input logic [DATA_WIDTH-1:0] cpu_req_wdata, input logic [DATA_WIDTH/8-1:0] cpu_req_wstrb,
  output logic cpu_resp_valid, input logic cpu_resp_ready, output logic [DATA_WIDTH-1:0] cpu_resp_data,
  output logic lower_req_valid, input logic lower_req_ready, output logic lower_req_write, output logic [ADDR_WIDTH-1:0] lower_req_addr, output logic [DATA_WIDTH-1:0] lower_req_wdata, output logic [DATA_WIDTH/8-1:0] lower_req_wstrb,
  input logic lower_resp_valid, output logic lower_resp_ready, input logic [DATA_WIDTH-1:0] lower_resp_data,
  output logic [63:0] access_count, load_access_count, store_access_count, hit_count, miss_count, load_miss_count, store_miss_count, refill_word_count, dirty_writeback_word_count, dirty_eviction_count, uncached_access_count, miss_stall_cycles
);
  localparam integer WORD_BYTES=DATA_WIDTH/8, WORDS_PER_BLOCK=BLOCK_BYTES/WORD_BYTES, OFFSET_BITS=$clog2(BLOCK_BYTES), SET_BITS=$clog2(NUM_SETS), WORD_BITS=$clog2(WORDS_PER_BLOCK), TAG_BITS=ADDR_WIDTH-OFFSET_BITS-SET_BITS, WAY_BITS=$clog2(NUM_WAYS), COUNT_BITS=$clog2(WORDS_PER_BLOCK+1);
  localparam integer IDLE=0, WB_REQ=1, WB_WAIT=2, REFILL_REQ=3, REFILL_WAIT=4, UNC_REQ=5, UNC_WAIT=6, RESP=7;
  logic valid_array [0:NUM_WAYS-1][0:NUM_SETS-1]; logic dirty_array [0:NUM_WAYS-1][0:NUM_SETS-1];
  logic [TAG_BITS-1:0] tag_array [0:NUM_WAYS-1][0:NUM_SETS-1]; logic [DATA_WIDTH-1:0] data_array [0:NUM_WAYS-1][0:NUM_SETS-1][0:WORDS_PER_BLOCK-1]; logic replacement [0:NUM_SETS-1];
  logic [2:0] state; logic saved_write; logic [ADDR_WIDTH-1:0] saved_addr, refill_base, victim_base; logic [DATA_WIDTH-1:0] saved_wdata,response_data; logic [DATA_WIDTH/8-1:0] saved_wstrb; logic [SET_BITS-1:0] saved_set; logic [TAG_BITS-1:0] saved_tag; logic [WORD_BITS-1:0] saved_word; logic [WAY_BITS-1:0] victim_way; logic [COUNT_BITS-1:0] word_count; logic hit_any,hit_way; logic [1:0] hit_matches; integer way,set_index;
  function automatic logic is_uncached(input logic [ADDR_WIDTH-1:0] a); is_uncached=(a==32'h1000_0000)||((a>=32'h200)&&(a<=32'h20f))||((a>=32'h300)&&(a<=32'h30f))||((a>=32'h400)&&(a<=32'h40f))||((a>=32'h600)&&(a<=32'h60f)); endfunction
  function automatic logic [DATA_WIDTH-1:0] merge_bytes(input logic [DATA_WIDTH-1:0] old_word,new_word,input logic [DATA_WIDTH/8-1:0] strobes); integer i; begin merge_bytes=old_word; for(i=0;i<WORD_BYTES;i=i+1) if(strobes[i]) merge_bytes[i*8 +:8]=new_word[i*8 +:8]; end endfunction
  always_comb begin
    hit_any=0; hit_way=0; hit_matches=0;
    for(way=0;way<NUM_WAYS;way=way+1) if(valid_array[way][cpu_req_addr[OFFSET_BITS+SET_BITS-1:OFFSET_BITS]] && tag_array[way][cpu_req_addr[OFFSET_BITS+SET_BITS-1:OFFSET_BITS]]==cpu_req_addr[ADDR_WIDTH-1:OFFSET_BITS+SET_BITS]) begin hit_any=1; hit_way=way[WAY_BITS-1:0]; hit_matches=hit_matches+1'b1; end
    cpu_req_ready=(state==IDLE); cpu_resp_valid=(state==RESP); cpu_resp_data=response_data; lower_req_valid=(state==WB_REQ)||(state==REFILL_REQ)||(state==UNC_REQ); lower_req_write=(state==WB_REQ)||((state==UNC_REQ)&&saved_write); lower_req_addr=(state==WB_REQ)?victim_base+word_count*WORD_BYTES:(state==REFILL_REQ)?refill_base+word_count*WORD_BYTES:saved_addr; lower_req_wdata=(state==WB_REQ)?data_array[victim_way][saved_set][word_count[WORD_BITS-1:0]]:saved_wdata; lower_req_wstrb=(state==WB_REQ)?{WORD_BYTES{1'b1}}:saved_wstrb; lower_resp_ready=(state==WB_WAIT)||(state==REFILL_WAIT)||(state==UNC_WAIT);
  end
  always_ff @(posedge clk) begin
    if(!rst_n) begin
      state<=IDLE; saved_write<=0; saved_addr<=0; refill_base<=0; victim_base<=0; saved_wdata<=0; saved_wstrb<=0; saved_set<=0; saved_tag<=0; saved_word<=0; victim_way<=0; word_count<=0; response_data<=0; access_count<=0; load_access_count<=0; store_access_count<=0; hit_count<=0; miss_count<=0; load_miss_count<=0; store_miss_count<=0; refill_word_count<=0; dirty_writeback_word_count<=0; dirty_eviction_count<=0; uncached_access_count<=0; miss_stall_cycles<=0;
      for(way=0;way<NUM_WAYS;way=way+1) for(set_index=0;set_index<NUM_SETS;set_index=set_index+1) begin valid_array[way][set_index]<=0; dirty_array[way][set_index]<=0; end
      for(set_index=0;set_index<NUM_SETS;set_index=set_index+1) replacement[set_index]<=0;
    end else begin
      if(state==WB_REQ||state==WB_WAIT||state==REFILL_REQ||state==REFILL_WAIT) miss_stall_cycles<=miss_stall_cycles+1'b1;
      if(state==IDLE&&cpu_req_valid&&cpu_req_ready) begin
        access_count<=access_count+1'b1; if(cpu_req_write) store_access_count<=store_access_count+1'b1; else load_access_count<=load_access_count+1'b1;
        saved_write<=cpu_req_write; saved_addr<=cpu_req_addr; saved_wdata<=cpu_req_wdata; saved_wstrb<=cpu_req_wstrb; saved_set<=cpu_req_addr[OFFSET_BITS+SET_BITS-1:OFFSET_BITS]; saved_tag<=cpu_req_addr[ADDR_WIDTH-1:OFFSET_BITS+SET_BITS]; saved_word<=cpu_req_addr[OFFSET_BITS-1:2];
        if(is_uncached(cpu_req_addr)) begin uncached_access_count<=uncached_access_count+1'b1; state<=UNC_REQ; end
        else if(hit_any) begin hit_count<=hit_count+1'b1; replacement[cpu_req_addr[OFFSET_BITS+SET_BITS-1:OFFSET_BITS]]<=~hit_way; if(cpu_req_write) begin data_array[hit_way][cpu_req_addr[OFFSET_BITS+SET_BITS-1:OFFSET_BITS]][cpu_req_addr[OFFSET_BITS-1:2]]<=merge_bytes(data_array[hit_way][cpu_req_addr[OFFSET_BITS+SET_BITS-1:OFFSET_BITS]][cpu_req_addr[OFFSET_BITS-1:2]],cpu_req_wdata,cpu_req_wstrb); dirty_array[hit_way][cpu_req_addr[OFFSET_BITS+SET_BITS-1:OFFSET_BITS]]<=1; response_data<=0; end else response_data<=data_array[hit_way][cpu_req_addr[OFFSET_BITS+SET_BITS-1:OFFSET_BITS]][cpu_req_addr[OFFSET_BITS-1:2]]; state<=RESP; end
        else begin
          miss_count<=miss_count+1'b1; if(cpu_req_write) store_miss_count<=store_miss_count+1'b1; else load_miss_count<=load_miss_count+1'b1; refill_base<={cpu_req_addr[ADDR_WIDTH-1:OFFSET_BITS],{OFFSET_BITS{1'b0}}}; word_count<=0;
          if(!valid_array[0][cpu_req_addr[OFFSET_BITS+SET_BITS-1:OFFSET_BITS]]) victim_way<=0; else if(!valid_array[1][cpu_req_addr[OFFSET_BITS+SET_BITS-1:OFFSET_BITS]]) victim_way<=1; else victim_way<=replacement[cpu_req_addr[OFFSET_BITS+SET_BITS-1:OFFSET_BITS]];
          if(valid_array[0][cpu_req_addr[OFFSET_BITS+SET_BITS-1:OFFSET_BITS]] && valid_array[1][cpu_req_addr[OFFSET_BITS+SET_BITS-1:OFFSET_BITS]] && dirty_array[replacement[cpu_req_addr[OFFSET_BITS+SET_BITS-1:OFFSET_BITS]]][cpu_req_addr[OFFSET_BITS+SET_BITS-1:OFFSET_BITS]]) begin victim_base<={tag_array[replacement[cpu_req_addr[OFFSET_BITS+SET_BITS-1:OFFSET_BITS]]][cpu_req_addr[OFFSET_BITS+SET_BITS-1:OFFSET_BITS]],cpu_req_addr[OFFSET_BITS+SET_BITS-1:OFFSET_BITS],{OFFSET_BITS{1'b0}}}; dirty_eviction_count<=dirty_eviction_count+1'b1; state<=WB_REQ; end else state<=REFILL_REQ;
        end
      end
      if(state==WB_REQ&&lower_req_ready) state<=WB_WAIT;
      if(state==WB_WAIT&&lower_resp_valid&&lower_resp_ready) begin dirty_writeback_word_count<=dirty_writeback_word_count+1'b1; if(word_count==WORDS_PER_BLOCK-1) begin word_count<=0; state<=REFILL_REQ; end else begin word_count<=word_count+1'b1; state<=WB_REQ; end end
      if(state==REFILL_REQ&&lower_req_ready) state<=REFILL_WAIT;
      if(state==REFILL_WAIT&&lower_resp_valid&&lower_resp_ready) begin data_array[victim_way][saved_set][word_count[WORD_BITS-1:0]]<=lower_resp_data; refill_word_count<=refill_word_count+1'b1; if(word_count==WORDS_PER_BLOCK-1) begin tag_array[victim_way][saved_set]<=saved_tag; valid_array[victim_way][saved_set]<=1; replacement[saved_set]<=~victim_way; if(saved_write) begin if(saved_word==word_count[WORD_BITS-1:0]) data_array[victim_way][saved_set][word_count[WORD_BITS-1:0]]<=merge_bytes(lower_resp_data,saved_wdata,saved_wstrb); else data_array[victim_way][saved_set][saved_word]<=merge_bytes(data_array[victim_way][saved_set][saved_word],saved_wdata,saved_wstrb); dirty_array[victim_way][saved_set]<=1; response_data<=0; end else begin dirty_array[victim_way][saved_set]<=0; response_data<=(saved_word==word_count[WORD_BITS-1:0])?lower_resp_data:data_array[victim_way][saved_set][saved_word]; end state<=RESP; end else begin word_count<=word_count+1'b1; state<=REFILL_REQ; end end
      if(state==UNC_REQ&&lower_req_ready) state<=UNC_WAIT;
      if(state==UNC_WAIT&&lower_resp_valid&&lower_resp_ready) begin response_data<=lower_resp_data; state<=RESP; end
      if(state==RESP&&cpu_resp_ready) state<=IDLE;
    end
  end
  always_ff @(posedge clk) if(rst_n) begin
    assert(!(hit_any&&!valid_array[hit_way][cpu_req_addr[OFFSET_BITS+SET_BITS-1:OFFSET_BITS]])) else $error("L1D hit from invalid way"); assert(hit_matches<=1) else $error("L1D multiple matching ways"); assert(!(state==WB_REQ&&(word_count>=WORDS_PER_BLOCK||victim_base[OFFSET_BITS-1:0]!=0))) else $error("L1D invalid writeback"); assert(!(state==REFILL_REQ&&(word_count>=WORDS_PER_BLOCK||refill_base[OFFSET_BITS-1:0]!=0))) else $error("L1D invalid refill"); assert(victim_way<NUM_WAYS) else $error("L1D illegal victim"); assert(access_count==hit_count+miss_count+uncached_access_count) else $error("L1D counter accounting");
  end
endmodule
