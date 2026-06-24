module core_adapter #(
  parameter integer CORE_ID = 0
) (
  input logic clk, input logic rst_n,
  input logic imem_req_valid, output logic imem_req_ready, input logic [31:0] imem_req_addr,
  output logic imem_resp_valid, input logic imem_resp_ready, output logic [31:0] imem_resp_data,
  input logic dmem_req_valid, output logic dmem_req_ready, input logic dmem_req_write,
  input logic [31:0] dmem_req_addr, input logic [31:0] dmem_req_wdata, input logic [3:0] dmem_req_wstrb,
  output logic dmem_resp_valid, input logic dmem_resp_ready, output logic [31:0] dmem_resp_data,
  output logic sys_req_valid, input logic sys_req_ready, output logic sys_req_port,
  output logic sys_req_write, output logic [31:0] sys_req_addr, output logic [31:0] sys_req_wdata,
  output logic [3:0] sys_req_wstrb, input logic sys_resp_valid, input logic [31:0] sys_resp_data,
  output logic sys_resp_ready
);
  logic active, issued, active_port, last_port;
  logic active_write;
  logic [31:0] active_addr, active_wdata;
  logic [3:0] active_wstrb;
  logic choose_port;

  always_comb begin
    choose_port = dmem_req_valid && (!imem_req_valid || !last_port);
    imem_req_ready = !active && imem_req_valid && !choose_port;
    dmem_req_ready = !active && dmem_req_valid && choose_port;
    sys_req_valid = active && !issued;
    sys_req_port = active_port;
    sys_req_write = active_write;
    sys_req_addr = active_addr;
    sys_req_wdata = active_wdata;
    sys_req_wstrb = active_wstrb;
    imem_resp_valid = active && issued && !active_port && sys_resp_valid;
    dmem_resp_valid = active && issued && active_port && sys_resp_valid;
    imem_resp_data = sys_resp_data;
    dmem_resp_data = sys_resp_data;
    sys_resp_ready = active && issued && (active_port ? dmem_resp_ready : imem_resp_ready);
  end

  always_ff @(posedge clk) begin
    if (!rst_n) begin
      active <= 1'b0; issued <= 1'b0; active_port <= 1'b0; last_port <= 1'b1;
      active_write <= 1'b0; active_addr <= '0; active_wdata <= '0; active_wstrb <= '0;
    end else begin
      if (!active && (imem_req_ready || dmem_req_ready)) begin
        active <= 1'b1; issued <= 1'b0; active_port <= dmem_req_ready; last_port <= dmem_req_ready;
        active_write <= dmem_req_ready ? dmem_req_write : 1'b0;
        active_addr <= dmem_req_ready ? dmem_req_addr : imem_req_addr;
        active_wdata <= dmem_req_ready ? dmem_req_wdata : 32'd0;
        active_wstrb <= dmem_req_ready ? dmem_req_wstrb : 4'b0000;
      end
      if (active && !issued && sys_req_ready) issued <= 1'b1;
      if (active && issued && sys_resp_valid && sys_resp_ready) begin active <= 1'b0; issued <= 1'b0; end
    end
  end

  always_ff @(posedge clk) if (rst_n) begin
    assert (!(sys_resp_valid && !active)) else $error("response without active adapter request");
    assert (!(imem_resp_valid && dmem_resp_valid)) else $error("adapter response routing not one-hot");
    assert (!(sys_req_valid && issued)) else $error("adapter issued a request twice");
  end
endmodule
