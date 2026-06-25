module l1_data_cache #(
  parameter integer ADDR_WIDTH=32, DATA_WIDTH=32, NUM_SETS=64, NUM_WAYS=2, BLOCK_BYTES=16
) (
  input logic clk, rst_n, input logic cpu_req_valid, output logic cpu_req_ready, input logic cpu_req_write,
  input logic [ADDR_WIDTH-1:0] cpu_req_addr, input logic [DATA_WIDTH-1:0] cpu_req_wdata, input logic [DATA_WIDTH/8-1:0] cpu_req_wstrb,
  input logic [1:0] cpu_req_atomic,
  output logic cpu_resp_valid, input logic cpu_resp_ready, output logic [DATA_WIDTH-1:0] cpu_resp_data,
  output logic lower_req_valid, input logic lower_req_ready, output logic lower_req_write, output logic [ADDR_WIDTH-1:0] lower_req_addr, output logic [DATA_WIDTH-1:0] lower_req_wdata, output logic [DATA_WIDTH/8-1:0] lower_req_wstrb,
  input logic lower_resp_valid, output logic lower_resp_ready, input logic [DATA_WIDTH-1:0] lower_resp_data,
  output logic bus_req_valid, input logic bus_req_ready, output logic [2:0] bus_req_cmd, output logic [ADDR_WIDTH-1:0] bus_req_addr,
  output logic [127:0] bus_req_wb_data, output logic bus_req_wb_data_valid,
  input logic bus_resp_valid, output logic bus_resp_ready, input logic [127:0] bus_resp_data,
  input logic bus_resp_shared, input logic bus_resp_modified, input logic bus_resp_complete, input logic bus_resp_error,
  input logic snoop_valid, input logic [2:0] snoop_cmd, input logic [ADDR_WIDTH-1:0] snoop_addr, input logic [1:0] snoop_requester, input logic snoop_other,
  output logic snoop_resp_valid, output logic snoop_resp_present, output logic snoop_resp_modified,
  output logic snoop_resp_data_valid, output logic [127:0] snoop_resp_data, output logic snoop_resp_inv_ack,
  output logic [NUM_WAYS*NUM_SETS*2-1:0] msi_state_debug,
  output logic [63:0] access_count, load_access_count, store_access_count, hit_count, miss_count, load_miss_count, store_miss_count, refill_word_count, dirty_writeback_word_count, dirty_eviction_count, uncached_access_count, miss_stall_cycles,
  output logic [63:0] load_hit_s_count, load_hit_m_count, store_hit_m_count, store_upgrade_count, bus_rd_request_count, bus_rdx_request_count, bus_upgr_request_count, writeback_count, snoop_hit_s_count, snoop_hit_m_count, intervention_count, invalidation_count, downgrade_count, ownership_transfer_count, coherence_stall_cycles, protocol_error_count,
  output logic [63:0] lr_attempt_count, lr_complete_count, sc_attempt_count, sc_success_count, sc_failure_count, sc_fail_no_reservation_count, sc_fail_mismatch_count, sc_fail_snoop_count, sc_fail_eviction_count, reservation_clear_count
);
  import coherence_pkg::*;
  localparam logic [1:0] ATOMIC_NONE=2'd0, ATOMIC_LR=2'd1, ATOMIC_SC=2'd2;
  localparam integer WORD_BYTES=DATA_WIDTH/8, WORDS_PER_BLOCK=BLOCK_BYTES/WORD_BYTES, OFFSET_BITS=$clog2(BLOCK_BYTES), SET_BITS=$clog2(NUM_SETS), WORD_BITS=$clog2(WORDS_PER_BLOCK), TAG_BITS=ADDR_WIDTH-OFFSET_BITS-SET_BITS, WAY_BITS=$clog2(NUM_WAYS);
  typedef enum logic [1:0] {MSI_I=2'd0, MSI_S=2'd1, MSI_M=2'd2} msi_t;
  typedef enum logic [2:0] {IDLE=3'd0, EVICT_REQ=3'd1, EVICT_WAIT=3'd2, COH_REQ=3'd3, COH_WAIT=3'd4, UNC_REQ=3'd5, UNC_WAIT=3'd6, RESP=3'd7} state_t;

  msi_t msi_array [0:NUM_WAYS-1][0:NUM_SETS-1];
  logic [TAG_BITS-1:0] tag_array [0:NUM_WAYS-1][0:NUM_SETS-1];
  logic [DATA_WIDTH-1:0] data_array [0:NUM_WAYS-1][0:NUM_SETS-1][0:WORDS_PER_BLOCK-1];
  logic replacement [0:NUM_SETS-1];
  state_t state;
  logic saved_write, pending_store_after_refill, snoop_seen, reservation_valid, reservation_lost_snoop, reservation_lost_eviction;
  logic [1:0] saved_atomic;
  logic [ADDR_WIDTH-1:0] saved_addr, victim_base, reservation_block_addr;
  logic [DATA_WIDTH-1:0] saved_wdata, response_data;
  logic [DATA_WIDTH/8-1:0] saved_wstrb;
  logic [SET_BITS-1:0] saved_set;
  logic [TAG_BITS-1:0] saved_tag;
  logic [WORD_BITS-1:0] saved_word;
  logic [WAY_BITS-1:0] saved_way, victim_way, snoop_way;
  logic [2:0] pending_cmd;
  logic hit_any, snoop_hit, snoop_conflicts_saved;
  logic [WAY_BITS-1:0] hit_way;
  logic [1:0] hit_matches;
  integer way,set_index,word_index,dbg;

  function automatic logic is_uncached(input logic [ADDR_WIDTH-1:0] a);
    is_uncached=(a==32'h1000_0000)||((a>=32'h200)&&(a<=32'h20f))||((a>=32'h300)&&(a<=32'h30f))||((a>=32'h400)&&(a<=32'h40f))||((a>=32'h600)&&(a<=32'h60f));
  endfunction
  function automatic logic [DATA_WIDTH-1:0] merge_bytes(input logic [DATA_WIDTH-1:0] old_word,new_word,input logic [DATA_WIDTH/8-1:0] strobes);
    integer i; begin merge_bytes=old_word; for(i=0;i<WORD_BYTES;i=i+1) if(strobes[i]) merge_bytes[i*8 +:8]=new_word[i*8 +:8]; end
  endfunction
  function automatic logic [127:0] pack_block(input logic [WAY_BITS-1:0] w,input logic [SET_BITS-1:0] s);
    integer j; begin pack_block='0; for(j=0;j<WORDS_PER_BLOCK;j=j+1) pack_block[j*32 +: 32]=data_array[w][s][j]; end
  endfunction
  function automatic logic [ADDR_WIDTH-1:0] block_addr(input logic [ADDR_WIDTH-1:0] a);
    block_addr = {a[ADDR_WIDTH-1:OFFSET_BITS], {OFFSET_BITS{1'b0}}};
  endfunction

  always_comb begin
    hit_any=0; hit_way=0; hit_matches=0;
    for(way=0;way<NUM_WAYS;way=way+1) begin
      if(msi_array[way][cpu_req_addr[OFFSET_BITS+SET_BITS-1:OFFSET_BITS]]!=MSI_I && tag_array[way][cpu_req_addr[OFFSET_BITS+SET_BITS-1:OFFSET_BITS]]==cpu_req_addr[ADDR_WIDTH-1:OFFSET_BITS+SET_BITS]) begin
        hit_any=1; hit_way=way[WAY_BITS-1:0]; hit_matches=hit_matches+1'b1;
      end
    end

    snoop_hit=0; snoop_way=0;
    for(way=0;way<NUM_WAYS;way=way+1) begin
      if(msi_array[way][snoop_addr[OFFSET_BITS+SET_BITS-1:OFFSET_BITS]]!=MSI_I && tag_array[way][snoop_addr[OFFSET_BITS+SET_BITS-1:OFFSET_BITS]]==snoop_addr[ADDR_WIDTH-1:OFFSET_BITS+SET_BITS]) begin
        snoop_hit=1; snoop_way=way[WAY_BITS-1:0];
      end
    end
    snoop_conflicts_saved = snoop_valid && snoop_hit && (snoop_addr[ADDR_WIDTH-1:OFFSET_BITS] == saved_addr[ADDR_WIDTH-1:OFFSET_BITS]);

    cpu_req_ready=(state==IDLE);
    cpu_resp_valid=(state==RESP);
    cpu_resp_data=response_data;
    lower_req_valid=(state==UNC_REQ);
    lower_req_write=saved_write;
    lower_req_addr=saved_addr;
    lower_req_wdata=saved_wdata;
    lower_req_wstrb=saved_wstrb;
    lower_resp_ready=(state==UNC_WAIT);
    bus_req_valid=(state==EVICT_REQ)||(state==COH_REQ);
    bus_req_cmd=(state==EVICT_REQ)?WRITEBACK:pending_cmd;
    bus_req_addr=(state==EVICT_REQ)?victim_base:{saved_addr[ADDR_WIDTH-1:OFFSET_BITS],{OFFSET_BITS{1'b0}}};
    bus_req_wb_data=pack_block(victim_way,saved_set);
    bus_req_wb_data_valid=(state==EVICT_REQ);
    bus_resp_ready=(state==EVICT_WAIT)||(state==COH_WAIT);

    snoop_resp_valid=snoop_valid && snoop_other;
    snoop_resp_present=snoop_resp_valid && snoop_hit;
    snoop_resp_modified=snoop_resp_present && (msi_array[snoop_way][snoop_addr[OFFSET_BITS+SET_BITS-1:OFFSET_BITS]]==MSI_M);
    snoop_resp_data_valid=snoop_resp_modified;
    snoop_resp_data=snoop_resp_modified ? pack_block(snoop_way,snoop_addr[OFFSET_BITS+SET_BITS-1:OFFSET_BITS]) : 128'd0;
    snoop_resp_inv_ack=snoop_resp_valid && ((snoop_cmd==BUS_RDX)||(snoop_cmd==BUS_UPGR));

    msi_state_debug='0;
    for(way=0;way<NUM_WAYS;way=way+1) for(set_index=0;set_index<NUM_SETS;set_index=set_index+1) begin
      dbg=(way*NUM_SETS+set_index)*2;
      msi_state_debug[dbg +: 2]=msi_array[way][set_index];
    end
  end

  always_ff @(posedge clk) begin
    if(!rst_n) begin
      state<=IDLE; saved_write<=0; saved_atomic<=ATOMIC_NONE; pending_store_after_refill<=0; saved_addr<=0; victim_base<=0; saved_wdata<=0; saved_wstrb<=0; saved_set<=0; saved_tag<=0; saved_word<=0; saved_way<=0; victim_way<=0; pending_cmd<=BUS_RD; response_data<=0; snoop_seen<=0; reservation_valid<=0; reservation_block_addr<=0; reservation_lost_snoop<=0; reservation_lost_eviction<=0;
      access_count<=0; load_access_count<=0; store_access_count<=0; hit_count<=0; miss_count<=0; load_miss_count<=0; store_miss_count<=0; refill_word_count<=0; dirty_writeback_word_count<=0; dirty_eviction_count<=0; uncached_access_count<=0; miss_stall_cycles<=0;
      load_hit_s_count<=0; load_hit_m_count<=0; store_hit_m_count<=0; store_upgrade_count<=0; bus_rd_request_count<=0; bus_rdx_request_count<=0; bus_upgr_request_count<=0; writeback_count<=0; snoop_hit_s_count<=0; snoop_hit_m_count<=0; intervention_count<=0; invalidation_count<=0; downgrade_count<=0; ownership_transfer_count<=0; coherence_stall_cycles<=0; protocol_error_count<=0;
      lr_attempt_count<=0; lr_complete_count<=0; sc_attempt_count<=0; sc_success_count<=0; sc_failure_count<=0; sc_fail_no_reservation_count<=0; sc_fail_mismatch_count<=0; sc_fail_snoop_count<=0; sc_fail_eviction_count<=0; reservation_clear_count<=0;
      for(way=0;way<NUM_WAYS;way=way+1) for(set_index=0;set_index<NUM_SETS;set_index=set_index+1) msi_array[way][set_index]<=MSI_I;
      for(set_index=0;set_index<NUM_SETS;set_index=set_index+1) replacement[set_index]<=0;
    end else begin
      if((state==EVICT_REQ)||(state==EVICT_WAIT)||(state==COH_REQ)||(state==COH_WAIT)) begin
        miss_stall_cycles<=miss_stall_cycles+1'b1; coherence_stall_cycles<=coherence_stall_cycles+1'b1;
      end
      if(!snoop_valid) snoop_seen<=1'b0;
      if(snoop_resp_valid && !snoop_seen) begin
        snoop_seen<=1'b1;
        if(snoop_hit && msi_array[snoop_way][snoop_addr[OFFSET_BITS+SET_BITS-1:OFFSET_BITS]]==MSI_S) snoop_hit_s_count<=snoop_hit_s_count+1'b1;
        if(snoop_hit && msi_array[snoop_way][snoop_addr[OFFSET_BITS+SET_BITS-1:OFFSET_BITS]]==MSI_M) begin
          snoop_hit_m_count<=snoop_hit_m_count+1'b1; intervention_count<=intervention_count+1'b1;
        end
        if(snoop_hit && snoop_cmd==BUS_RD && msi_array[snoop_way][snoop_addr[OFFSET_BITS+SET_BITS-1:OFFSET_BITS]]==MSI_M) begin
          if(reservation_valid && reservation_block_addr==block_addr(snoop_addr)) begin reservation_valid<=1'b0; reservation_lost_snoop<=1'b1; reservation_clear_count<=reservation_clear_count+1'b1; end
          msi_array[snoop_way][snoop_addr[OFFSET_BITS+SET_BITS-1:OFFSET_BITS]]<=MSI_S; downgrade_count<=downgrade_count+1'b1;
        end else if(snoop_hit && snoop_cmd==BUS_RDX) begin
          if(reservation_valid && reservation_block_addr==block_addr(snoop_addr)) begin reservation_valid<=1'b0; reservation_lost_snoop<=1'b1; reservation_clear_count<=reservation_clear_count+1'b1; end
          if(msi_array[snoop_way][snoop_addr[OFFSET_BITS+SET_BITS-1:OFFSET_BITS]]==MSI_M) ownership_transfer_count<=ownership_transfer_count+1'b1;
          msi_array[snoop_way][snoop_addr[OFFSET_BITS+SET_BITS-1:OFFSET_BITS]]<=MSI_I; invalidation_count<=invalidation_count+1'b1;
          if(state==COH_REQ && snoop_conflicts_saved) pending_cmd<=BUS_RDX;
        end else if(snoop_hit && snoop_cmd==BUS_UPGR) begin
          if(reservation_valid && reservation_block_addr==block_addr(snoop_addr)) begin reservation_valid<=1'b0; reservation_lost_snoop<=1'b1; reservation_clear_count<=reservation_clear_count+1'b1; end
          if(msi_array[snoop_way][snoop_addr[OFFSET_BITS+SET_BITS-1:OFFSET_BITS]]==MSI_M) protocol_error_count<=protocol_error_count+1'b1;
          else begin msi_array[snoop_way][snoop_addr[OFFSET_BITS+SET_BITS-1:OFFSET_BITS]]<=MSI_I; invalidation_count<=invalidation_count+1'b1; end
          if(state==COH_REQ && snoop_conflicts_saved) pending_cmd<=BUS_RDX;
        end
      end

      if(state==IDLE&&cpu_req_valid&&cpu_req_ready) begin
        access_count<=access_count+1'b1; if(cpu_req_write) store_access_count<=store_access_count+1'b1; else load_access_count<=load_access_count+1'b1;
        if(cpu_req_atomic==ATOMIC_LR) lr_attempt_count<=lr_attempt_count+1'b1;
        if(cpu_req_atomic==ATOMIC_SC) sc_attempt_count<=sc_attempt_count+1'b1;
        saved_write<=cpu_req_write; saved_atomic<=cpu_req_atomic; saved_addr<=cpu_req_addr; saved_wdata<=cpu_req_wdata; saved_wstrb<=cpu_req_wstrb; saved_set<=cpu_req_addr[OFFSET_BITS+SET_BITS-1:OFFSET_BITS]; saved_tag<=cpu_req_addr[ADDR_WIDTH-1:OFFSET_BITS+SET_BITS]; saved_word<=cpu_req_addr[OFFSET_BITS-1:2];
        if(cpu_req_atomic==ATOMIC_SC && (!reservation_valid || reservation_block_addr!=block_addr(cpu_req_addr) || is_uncached(cpu_req_addr) || !hit_any)) begin
          if(reservation_valid) reservation_clear_count<=reservation_clear_count+1'b1;
          if(!reservation_valid) begin
            if(reservation_lost_snoop) sc_fail_snoop_count<=sc_fail_snoop_count+1'b1;
            else if(reservation_lost_eviction) sc_fail_eviction_count<=sc_fail_eviction_count+1'b1;
            else sc_fail_no_reservation_count<=sc_fail_no_reservation_count+1'b1;
          end else if(reservation_block_addr!=block_addr(cpu_req_addr)) sc_fail_mismatch_count<=sc_fail_mismatch_count+1'b1;
          else sc_fail_eviction_count<=sc_fail_eviction_count+1'b1;
          hit_count<=hit_count+1'b1;
          reservation_valid<=1'b0; reservation_lost_snoop<=1'b0; reservation_lost_eviction<=1'b0; sc_failure_count<=sc_failure_count+1'b1; response_data<=32'd1; state<=RESP;
        end else if(is_uncached(cpu_req_addr)) begin
          uncached_access_count<=uncached_access_count+1'b1;
          if(cpu_req_atomic==ATOMIC_LR) begin response_data<=32'd0; state<=RESP; end
          else begin state<=UNC_REQ; end
        end
        else if(hit_any) begin
          replacement[cpu_req_addr[OFFSET_BITS+SET_BITS-1:OFFSET_BITS]]<=~hit_way; saved_way<=hit_way;
          if(!cpu_req_write) begin
            hit_count<=hit_count+1'b1;
            if(msi_array[hit_way][cpu_req_addr[OFFSET_BITS+SET_BITS-1:OFFSET_BITS]]==MSI_S) load_hit_s_count<=load_hit_s_count+1'b1; else load_hit_m_count<=load_hit_m_count+1'b1;
            response_data<=data_array[hit_way][cpu_req_addr[OFFSET_BITS+SET_BITS-1:OFFSET_BITS]][cpu_req_addr[OFFSET_BITS-1:2]];
            if(cpu_req_atomic==ATOMIC_LR) begin reservation_valid<=1'b1; reservation_block_addr<=block_addr(cpu_req_addr); reservation_lost_snoop<=1'b0; reservation_lost_eviction<=1'b0; lr_complete_count<=lr_complete_count+1'b1; end
            state<=RESP;
          end else if(msi_array[hit_way][cpu_req_addr[OFFSET_BITS+SET_BITS-1:OFFSET_BITS]]==MSI_M) begin
            hit_count<=hit_count+1'b1; store_hit_m_count<=store_hit_m_count+1'b1;
            data_array[hit_way][cpu_req_addr[OFFSET_BITS+SET_BITS-1:OFFSET_BITS]][cpu_req_addr[OFFSET_BITS-1:2]]<=merge_bytes(data_array[hit_way][cpu_req_addr[OFFSET_BITS+SET_BITS-1:OFFSET_BITS]][cpu_req_addr[OFFSET_BITS-1:2]],cpu_req_wdata,cpu_req_wstrb);
            response_data<= (cpu_req_atomic==ATOMIC_SC) ? 32'd0 : 32'd0;
            if(cpu_req_atomic==ATOMIC_SC) begin sc_success_count<=sc_success_count+1'b1; reservation_valid<=1'b0; reservation_lost_snoop<=1'b0; reservation_lost_eviction<=1'b0; reservation_clear_count<=reservation_clear_count+1'b1; end
            else if(reservation_valid && reservation_block_addr==block_addr(cpu_req_addr)) begin reservation_valid<=1'b0; reservation_clear_count<=reservation_clear_count+1'b1; end
            state<=RESP;
          end else begin
            hit_count<=hit_count+1'b1; store_upgrade_count<=store_upgrade_count+1'b1; pending_cmd<=BUS_UPGR; pending_store_after_refill<=1'b0; state<=COH_REQ;
          end
        end else begin
          miss_count<=miss_count+1'b1; if(cpu_req_write) store_miss_count<=store_miss_count+1'b1; else load_miss_count<=load_miss_count+1'b1;
          pending_cmd<=cpu_req_write?BUS_RDX:BUS_RD; pending_store_after_refill<=cpu_req_write;
          if(msi_array[0][cpu_req_addr[OFFSET_BITS+SET_BITS-1:OFFSET_BITS]]==MSI_I) victim_way<=0;
          else if(msi_array[1][cpu_req_addr[OFFSET_BITS+SET_BITS-1:OFFSET_BITS]]==MSI_I) victim_way<=1;
          else victim_way<=replacement[cpu_req_addr[OFFSET_BITS+SET_BITS-1:OFFSET_BITS]];
          saved_way <= (msi_array[0][cpu_req_addr[OFFSET_BITS+SET_BITS-1:OFFSET_BITS]]==MSI_I) ? 0 :
                       (msi_array[1][cpu_req_addr[OFFSET_BITS+SET_BITS-1:OFFSET_BITS]]==MSI_I) ? 1 :
                       replacement[cpu_req_addr[OFFSET_BITS+SET_BITS-1:OFFSET_BITS]];
          if(msi_array[(msi_array[0][cpu_req_addr[OFFSET_BITS+SET_BITS-1:OFFSET_BITS]]==MSI_I) ? 0 : (msi_array[1][cpu_req_addr[OFFSET_BITS+SET_BITS-1:OFFSET_BITS]]==MSI_I) ? 1 : replacement[cpu_req_addr[OFFSET_BITS+SET_BITS-1:OFFSET_BITS]]][cpu_req_addr[OFFSET_BITS+SET_BITS-1:OFFSET_BITS]]==MSI_M) begin
            victim_base<={tag_array[(msi_array[0][cpu_req_addr[OFFSET_BITS+SET_BITS-1:OFFSET_BITS]]==MSI_I) ? 0 : (msi_array[1][cpu_req_addr[OFFSET_BITS+SET_BITS-1:OFFSET_BITS]]==MSI_I) ? 1 : replacement[cpu_req_addr[OFFSET_BITS+SET_BITS-1:OFFSET_BITS]]][cpu_req_addr[OFFSET_BITS+SET_BITS-1:OFFSET_BITS]],cpu_req_addr[OFFSET_BITS+SET_BITS-1:OFFSET_BITS],{OFFSET_BITS{1'b0}}};
            if(reservation_valid && reservation_block_addr=={tag_array[(msi_array[0][cpu_req_addr[OFFSET_BITS+SET_BITS-1:OFFSET_BITS]]==MSI_I) ? 0 : (msi_array[1][cpu_req_addr[OFFSET_BITS+SET_BITS-1:OFFSET_BITS]]==MSI_I) ? 1 : replacement[cpu_req_addr[OFFSET_BITS+SET_BITS-1:OFFSET_BITS]]][cpu_req_addr[OFFSET_BITS+SET_BITS-1:OFFSET_BITS]],cpu_req_addr[OFFSET_BITS+SET_BITS-1:OFFSET_BITS],{OFFSET_BITS{1'b0}}}) begin reservation_valid<=1'b0; reservation_lost_eviction<=1'b1; reservation_clear_count<=reservation_clear_count+1'b1; end
            dirty_eviction_count<=dirty_eviction_count+1'b1; state<=EVICT_REQ;
          end else begin
            if(msi_array[(msi_array[0][cpu_req_addr[OFFSET_BITS+SET_BITS-1:OFFSET_BITS]]==MSI_I) ? 0 : (msi_array[1][cpu_req_addr[OFFSET_BITS+SET_BITS-1:OFFSET_BITS]]==MSI_I) ? 1 : replacement[cpu_req_addr[OFFSET_BITS+SET_BITS-1:OFFSET_BITS]]][cpu_req_addr[OFFSET_BITS+SET_BITS-1:OFFSET_BITS]]!=MSI_I &&
               reservation_valid && reservation_block_addr=={tag_array[(msi_array[0][cpu_req_addr[OFFSET_BITS+SET_BITS-1:OFFSET_BITS]]==MSI_I) ? 0 : (msi_array[1][cpu_req_addr[OFFSET_BITS+SET_BITS-1:OFFSET_BITS]]==MSI_I) ? 1 : replacement[cpu_req_addr[OFFSET_BITS+SET_BITS-1:OFFSET_BITS]]][cpu_req_addr[OFFSET_BITS+SET_BITS-1:OFFSET_BITS]],cpu_req_addr[OFFSET_BITS+SET_BITS-1:OFFSET_BITS],{OFFSET_BITS{1'b0}}}) begin reservation_valid<=1'b0; reservation_lost_eviction<=1'b1; reservation_clear_count<=reservation_clear_count+1'b1; end
            state<=COH_REQ;
          end
        end
      end
      if(state==EVICT_REQ&&bus_req_ready) begin writeback_count<=writeback_count+1'b1; state<=EVICT_WAIT; end
      if(state==EVICT_WAIT&&bus_resp_valid&&bus_resp_ready) begin
        dirty_writeback_word_count<=dirty_writeback_word_count+WORDS_PER_BLOCK; msi_array[victim_way][saved_set]<=MSI_I; state<=COH_REQ;
      end
      if(state==COH_REQ&&bus_req_ready) begin
        if(pending_cmd==BUS_RD) bus_rd_request_count<=bus_rd_request_count+1'b1;
        else if(pending_cmd==BUS_RDX) bus_rdx_request_count<=bus_rdx_request_count+1'b1;
        else if(pending_cmd==BUS_UPGR) bus_upgr_request_count<=bus_upgr_request_count+1'b1;
        state<=COH_WAIT;
      end
      if(state==COH_WAIT&&bus_resp_valid&&bus_resp_ready) begin
        if(bus_resp_error) begin protocol_error_count<=protocol_error_count+1'b1; response_data<=0; state<=RESP; end
        else if(pending_cmd==BUS_UPGR) begin
          if(saved_atomic==ATOMIC_SC && (!reservation_valid || reservation_block_addr!=block_addr(saved_addr))) begin
            response_data<=32'd1; sc_failure_count<=sc_failure_count+1'b1;
            if(reservation_lost_snoop) sc_fail_snoop_count<=sc_fail_snoop_count+1'b1;
            else if(reservation_lost_eviction) sc_fail_eviction_count<=sc_fail_eviction_count+1'b1;
            else sc_fail_no_reservation_count<=sc_fail_no_reservation_count+1'b1;
            reservation_valid<=1'b0; reservation_lost_snoop<=1'b0; reservation_lost_eviction<=1'b0;
          end else begin
            msi_array[saved_way][saved_set]<=MSI_M;
            data_array[saved_way][saved_set][saved_word]<=merge_bytes(data_array[saved_way][saved_set][saved_word],saved_wdata,saved_wstrb);
            response_data<=0;
            if(saved_atomic==ATOMIC_SC) begin sc_success_count<=sc_success_count+1'b1; reservation_valid<=1'b0; reservation_lost_snoop<=1'b0; reservation_lost_eviction<=1'b0; reservation_clear_count<=reservation_clear_count+1'b1; end
            else if(reservation_valid && reservation_block_addr==block_addr(saved_addr)) begin reservation_valid<=1'b0; reservation_clear_count<=reservation_clear_count+1'b1; end
          end
          state<=RESP;
        end else begin
          for(word_index=0;word_index<WORDS_PER_BLOCK;word_index=word_index+1) data_array[saved_way][saved_set][word_index]<=bus_resp_data[word_index*32 +: 32];
          tag_array[saved_way][saved_set]<=saved_tag; replacement[saved_set]<=~saved_way; refill_word_count<=refill_word_count+WORDS_PER_BLOCK;
          if(pending_cmd==BUS_RDX || pending_store_after_refill) begin
            msi_array[saved_way][saved_set]<=MSI_M;
            if(saved_atomic==ATOMIC_SC && (!reservation_valid || reservation_block_addr!=block_addr(saved_addr))) begin
              response_data<=32'd1; sc_failure_count<=sc_failure_count+1'b1;
              if(reservation_lost_snoop) sc_fail_snoop_count<=sc_fail_snoop_count+1'b1;
              else if(reservation_lost_eviction) sc_fail_eviction_count<=sc_fail_eviction_count+1'b1;
              else sc_fail_no_reservation_count<=sc_fail_no_reservation_count+1'b1;
              reservation_valid<=1'b0; reservation_lost_snoop<=1'b0; reservation_lost_eviction<=1'b0;
            end else begin
              data_array[saved_way][saved_set][saved_word]<=merge_bytes(bus_resp_data[saved_word*32 +: 32],saved_wdata,saved_wstrb);
              response_data<=0;
              if(saved_atomic==ATOMIC_SC) begin sc_success_count<=sc_success_count+1'b1; reservation_valid<=1'b0; reservation_lost_snoop<=1'b0; reservation_lost_eviction<=1'b0; reservation_clear_count<=reservation_clear_count+1'b1; end
              else if(reservation_valid && reservation_block_addr==block_addr(saved_addr)) begin reservation_valid<=1'b0; reservation_clear_count<=reservation_clear_count+1'b1; end
            end
          end else begin
            msi_array[saved_way][saved_set]<=MSI_S; response_data<=bus_resp_data[saved_word*32 +: 32];
            if(saved_atomic==ATOMIC_LR) begin reservation_valid<=1'b1; reservation_block_addr<=block_addr(saved_addr); reservation_lost_snoop<=1'b0; reservation_lost_eviction<=1'b0; lr_complete_count<=lr_complete_count+1'b1; end
          end
          state<=RESP;
        end
      end
      if(state==UNC_REQ&&lower_req_ready) state<=UNC_WAIT;
      if(state==UNC_WAIT&&lower_resp_valid&&lower_resp_ready) begin response_data<=lower_resp_data; state<=RESP; end
      if(state==RESP&&cpu_resp_ready) state<=IDLE;
    end
  end
  always_ff @(posedge clk) if(rst_n) begin
    assert(!(hit_any&&msi_array[hit_way][cpu_req_addr[OFFSET_BITS+SET_BITS-1:OFFSET_BITS]]==MSI_I)) else $error("L1D hit from invalid MSI state");
    assert(hit_matches<=1) else $error("L1D multiple matching ways");
    assert(!(state==COH_REQ && pending_cmd==BUS_UPGR && msi_array[saved_way][saved_set]!=MSI_S)) else $error("L1D upgrade without shared copy");
    assert(!(state==RESP && saved_write && saved_atomic!=ATOMIC_SC && !is_uncached(saved_addr) && pending_cmd!=BUS_UPGR && pending_cmd!=BUS_RDX && msi_array[saved_way][saved_set]!=MSI_M)) else $error("L1D store completed outside M");
    assert(access_count==hit_count+miss_count+uncached_access_count) else $error("L1D counter accounting");
    assert(!reservation_valid || reservation_block_addr[OFFSET_BITS-1:0] == '0) else $error("unaligned reservation");
    assert(sc_attempt_count==sc_success_count+sc_failure_count || state!=IDLE) else $error("SC counter accounting");
  end
endmodule
