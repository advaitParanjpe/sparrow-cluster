module snoopy_coherence_transport #(
  parameter integer NUM_CORES = 4,
  parameter integer SNOOP_TIMEOUT = 32
) (
  input logic clk, input logic rst_n,
  input logic [NUM_CORES-1:0] req_valid, output logic [NUM_CORES-1:0] req_ready,
  input logic [NUM_CORES*3-1:0] req_cmd, input logic [NUM_CORES*32-1:0] req_addr,
  input logic [NUM_CORES*128-1:0] req_wb_data, input logic [NUM_CORES-1:0] req_wb_data_valid,
  output logic [NUM_CORES-1:0] req_resp_valid, input logic [NUM_CORES-1:0] req_resp_ready,
  output logic [NUM_CORES*128-1:0] req_resp_data, output logic [NUM_CORES-1:0] req_resp_shared,
  output logic [NUM_CORES-1:0] req_resp_modified, output logic [NUM_CORES-1:0] req_resp_complete,
  output logic [NUM_CORES-1:0] req_resp_error,
  output logic [NUM_CORES-1:0] snoop_valid, output logic [2:0] snoop_cmd,
  output logic [31:0] snoop_addr, output logic [1:0] snoop_requester,
  output logic [NUM_CORES-1:0] snoop_other,
  input logic [NUM_CORES-1:0] snoop_resp_valid, input logic [NUM_CORES-1:0] snoop_resp_present,
  input logic [NUM_CORES-1:0] snoop_resp_modified, input logic [NUM_CORES-1:0] snoop_resp_data_valid,
  input logic [NUM_CORES*128-1:0] snoop_resp_data, input logic [NUM_CORES-1:0] snoop_resp_inv_ack,
  output logic mem_req_valid, input logic mem_req_ready, output logic mem_req_write,
  output logic [31:0] mem_req_addr, output logic [31:0] mem_req_wdata, output logic [3:0] mem_req_wstrb,
  input logic mem_resp_valid, output logic mem_resp_ready, input logic [31:0] mem_resp_data,
  output logic [63:0] transaction_count, output logic [63:0] bus_rd_count,
  output logic [63:0] bus_rdx_count, output logic [63:0] bus_upgr_count, output logic [63:0] writeback_count,
  output logic [63:0] shared_transaction_count, output logic [63:0] intervention_count,
  output logic [63:0] sram_block_read_count, output logic [63:0] sram_block_write_count,
  output logic [63:0] invalidation_ack_count, output logic [63:0] occupied_cycle_count,
  output logic [63:0] protocol_error_count, output logic [63:0] timeout_count,
  output logic [NUM_CORES*64-1:0] arbitration_wait_cycles
);
  import coherence_pkg::*;
  typedef enum logic [3:0] {IDLE, SNOOP, SELECT, MEM_RD_REQ, MEM_RD_WAIT, MEM_WR_REQ, MEM_WR_WAIT, RESP} state_t;
  state_t state;
  logic [1:0] rr_next, active_id;
  logic [2:0] active_cmd;
  logic [31:0] active_addr;
  logic [127:0] active_wb_data, owner_data, response_data;
  logic active_wb_valid, shared_seen, modified_seen, error_seen, write_for_intervention;
  logic [NUM_CORES-1:0] response_seen, ack_seen;
  logic [2:0] word_index;
  integer timeout_cycles;
  integer i, idx, selected;
  logic selected_valid;
  logic peers_done, acks_done;

  always_comb begin
    selected = 0; selected_valid = 1'b0;
    for (i=0; i<NUM_CORES; i=i+1) begin
      idx = rr_next + i; if (idx >= NUM_CORES) idx = idx - NUM_CORES;
      if (!selected_valid && req_valid[idx]) begin selected = idx; selected_valid = 1'b1; end
    end
    req_ready = '0;
    if (state == IDLE && selected_valid) req_ready[selected] = 1'b1;
    snoop_valid = '0; snoop_other = '0;
    if (state == SNOOP) for (i=0; i<NUM_CORES; i=i+1) if (i != active_id) begin snoop_valid[i] = 1'b1; snoop_other[i] = 1'b1; end
    snoop_cmd = active_cmd; snoop_addr = active_addr; snoop_requester = active_id;
    peers_done = 1'b1; acks_done = 1'b1;
    for (i=0; i<NUM_CORES; i=i+1) if (i != active_id) begin
      if (!response_seen[i]) peers_done = 1'b0;
      if ((active_cmd == BUS_RDX || active_cmd == BUS_UPGR) && !ack_seen[i]) acks_done = 1'b0;
    end
    mem_req_valid = (state == MEM_RD_REQ || state == MEM_WR_REQ);
    mem_req_write = (state == MEM_WR_REQ);
    mem_req_addr = active_addr + {27'd0, word_index, 2'b00};
    mem_req_wdata = write_for_intervention ? owner_data[word_index*32 +: 32] : active_wb_data[word_index*32 +: 32];
    mem_req_wstrb = 4'hf;
    mem_resp_ready = 1'b1;
    req_resp_valid = '0; req_resp_data = '0; req_resp_shared = '0; req_resp_modified = '0; req_resp_complete = '0; req_resp_error = '0;
    if (state == RESP) begin
      req_resp_valid[active_id] = 1'b1; req_resp_data[active_id*128 +: 128] = response_data;
      req_resp_shared[active_id] = shared_seen; req_resp_modified[active_id] = modified_seen;
      req_resp_complete[active_id] = 1'b1; req_resp_error[active_id] = error_seen;
    end
  end

  always_ff @(posedge clk) begin
    if (!rst_n) begin
      state<=IDLE; rr_next<=0; active_id<=0; active_cmd<=0; active_addr<=0; active_wb_data<=0; active_wb_valid<=0;
      owner_data<=0; response_data<=0; shared_seen<=0; modified_seen<=0; error_seen<=0; write_for_intervention<=0; response_seen<='0; ack_seen<='0; word_index<=0; timeout_cycles<=0;
      transaction_count<=0; bus_rd_count<=0; bus_rdx_count<=0; bus_upgr_count<=0; writeback_count<=0; shared_transaction_count<=0; intervention_count<=0; sram_block_read_count<=0; sram_block_write_count<=0; invalidation_ack_count<=0; occupied_cycle_count<=0; protocol_error_count<=0; timeout_count<=0; arbitration_wait_cycles<='0;
    end else begin
      if (state != IDLE) occupied_cycle_count <= occupied_cycle_count + 1'b1;
      if (state == IDLE) for (i=0;i<NUM_CORES;i=i+1) if (req_valid[i] && !(req_ready[i])) arbitration_wait_cycles[i*64 +: 64] <= arbitration_wait_cycles[i*64 +: 64] + 1'b1;
      case (state)
        IDLE: if (selected_valid && req_ready[selected]) begin
          active_id<=selected; active_cmd<=req_cmd[selected*3 +: 3]; active_addr<=req_addr[selected*32 +: 32] & 32'hffff_fff0; active_wb_data<=req_wb_data[selected*128 +: 128]; active_wb_valid<=req_wb_data_valid[selected];
          response_seen<='0; ack_seen<='0; shared_seen<=0; modified_seen<=0; error_seen<=0; timeout_cycles<=0; word_index<=0; response_data<=0;
          transaction_count<=transaction_count+1'b1; if(req_cmd[selected*3 +:3]==BUS_RD) bus_rd_count<=bus_rd_count+1'b1; else if(req_cmd[selected*3 +:3]==BUS_RDX) bus_rdx_count<=bus_rdx_count+1'b1; else if(req_cmd[selected*3 +:3]==BUS_UPGR) bus_upgr_count<=bus_upgr_count+1'b1; else if(req_cmd[selected*3 +:3]==WRITEBACK) writeback_count<=writeback_count+1'b1;
          if (req_cmd[selected*3 +:3] == WRITEBACK) state <= MEM_WR_REQ; else state <= SNOOP;
        end
        SNOOP: begin
          timeout_cycles <= timeout_cycles + 1;
          for (i=0;i<NUM_CORES;i=i+1) if (i != active_id && snoop_resp_valid[i] && !response_seen[i]) begin
            response_seen[i] <= 1'b1;
            if (snoop_resp_present[i]) shared_seen <= 1'b1;
            if (snoop_resp_modified[i]) begin
              if (modified_seen) begin error_seen<=1'b1; protocol_error_count<=protocol_error_count+1'b1; end
              else begin modified_seen<=1'b1; owner_data<=snoop_resp_data[i*128 +: 128]; if(!snoop_resp_data_valid[i]) begin error_seen<=1'b1; protocol_error_count<=protocol_error_count+1'b1; end end
            end
            if ((active_cmd==BUS_RDX || active_cmd==BUS_UPGR) && snoop_resp_inv_ack[i]) begin ack_seen[i]<=1'b1; invalidation_ack_count<=invalidation_ack_count+1'b1; end
          end
          if (timeout_cycles >= SNOOP_TIMEOUT) begin error_seen<=1'b1; timeout_count<=timeout_count+1'b1; protocol_error_count<=protocol_error_count+1'b1; state<=RESP; end
          else if (peers_done && acks_done) state<=SELECT;
        end
        SELECT: begin
          if (shared_seen) shared_transaction_count<=shared_transaction_count+1'b1;
          if (active_cmd == BUS_UPGR) begin if(modified_seen) begin error_seen<=1'b1; protocol_error_count<=protocol_error_count+1'b1; end state<=RESP; end
          else if (active_cmd == WRITEBACK) state<=MEM_WR_REQ;
          else if (modified_seen) begin intervention_count<=intervention_count+1'b1; response_data<=owner_data; write_for_intervention<=1'b1; word_index<=0; state<=MEM_WR_REQ; end
          else begin write_for_intervention<=1'b0; word_index<=0; state<=MEM_RD_REQ; end
        end
        MEM_RD_REQ: if (mem_req_ready) state<=MEM_RD_WAIT;
        MEM_RD_WAIT: if (mem_resp_valid) begin response_data[word_index*32 +: 32] <= mem_resp_data; if(word_index==3) begin sram_block_read_count<=sram_block_read_count+1'b1; state<=RESP; end else begin word_index<=word_index+1'b1; state<=MEM_RD_REQ; end end
        MEM_WR_REQ: if (mem_req_ready) state<=MEM_WR_WAIT;
        MEM_WR_WAIT: if (mem_resp_valid) begin if(word_index==3) begin sram_block_write_count<=sram_block_write_count+1'b1; state<=RESP; end else begin word_index<=word_index+1'b1; state<=MEM_WR_REQ; end end
        RESP: if (req_resp_ready[active_id]) begin rr_next <= (active_id == NUM_CORES-1) ? 0 : active_id+1'b1; state<=IDLE; end
        default: state<=IDLE;
      endcase
    end
  end
  always_ff @(posedge clk) if (rst_n) begin
    assert (!(state != IDLE && active_addr[3:0] != 0)) else $error("coherence address unaligned");
    assert (!(state == RESP && active_cmd == BUS_UPGR && response_data != 0)) else $error("BusUpgr returned data");
    assert (!(state == SNOOP && snoop_valid[active_id])) else $error("requester snooped itself");
    assert (!(modified_seen && !write_for_intervention && state == MEM_RD_REQ)) else $error("stale SRAM selected over owner");
  end
endmodule
