module round_robin_arbiter #(parameter integer N = 4) (
  input logic clk, input logic rst_n, input logic [N-1:0] req,
  input logic grant_accept, output logic grant_valid, output logic [$clog2(N)-1:0] grant
);
  logic [$clog2(N)-1:0] next_grant;
  integer i, idx;
  always_comb begin
    grant_valid = 1'b0; grant = next_grant;
    for (i = 0; i < N; i = i + 1) begin
      idx = next_grant + i;
      if (idx >= N) idx = idx - N;
      if (!grant_valid && req[idx]) begin grant_valid = 1'b1; grant = idx[$clog2(N)-1:0]; end
    end
  end
  always_ff @(posedge clk) begin
    if (!rst_n) next_grant <= '0;
    else if (grant_valid && grant_accept) next_grant <= (grant == N-1) ? '0 : grant + 1'b1;
  end
endmodule
