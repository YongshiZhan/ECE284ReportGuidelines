module mac_tile (
  clk, reset,
  in_w, out_e,
  in_n, out_s,
  inst_w, inst_e
);

parameter bw = 4;
parameter psum_bw = 16;

// ---------------- Ports ----------------
input  clk, reset;
input  [bw-1:0] in_w;
input  [psum_bw-1:0] in_n;
input  [1:0] inst_w;

output [bw-1:0] out_e;
output [psum_bw-1:0] out_s;
output [1:0] inst_e;

// ---------------- Registers ----------------
reg  [1:0] inst_q, inst_d;
reg  [bw-1:0] a_q, a_d;
reg  [bw-1:0] b_q, b_d;
reg  [psum_bw-1:0] c_q, c_d;
reg  load_ready_q, load_ready_d;
reg  [1:0] inst_w_d, inst_w_q;

wire [psum_bw-1:0] mac_out;

// ---------------- Connections ----------------
assign out_e  = a_q;
assign inst_e = inst_q;
assign out_s  = mac_out;

// ---------------- MAC Block ----------------
mac #(.bw(bw), .psum_bw(psum_bw)) mac_instance (
  .a(a_q),
  .b(b_q),
  .c(c_q),
  .out(mac_out)
);

// ---------------- Combinational logic ----------------
always @(*) begin
  // defaults
  inst_d       = inst_q;
  a_d          = a_q;
  b_d          = b_q;
  c_d          = c_q;
  load_ready_d = load_ready_q;
  inst_w_d = inst_w;

  // always forward execute bit
  inst_d[1] = inst_w_d[1];

  // latch activation on kernel_load or execute
  if (inst_w_d[0] | inst_w_d[1])
    a_d = in_w;

  // kernel load when ready
  if (inst_w_d[0] && load_ready_q) begin
    b_d          = in_w;
    load_ready_d = 1'b0;
  end

  // after kernel load, forward inst_w[0] and re-arm load_ready
  if (!load_ready_q) begin
    inst_d[0]    = inst_w_d[0];
    // Re-enable load at falling edge of inst_w[1], which is end of execute round
    if (inst_w_q[1] && !inst_w_d[1]) begin
      load_ready_d = 1'b1;
    end
  end else begin
    inst_d[0]    = 1'b0;
  end

  // during execute, latch psum input
  if (inst_w[1])
    c_d = in_n;
end

// ---------------- Sequential logic ----------------
always @(posedge clk) begin
  if (reset) begin
    inst_q       <= 2'b00;
    a_q          <= {bw{1'b0}};
    b_q          <= {bw{1'b0}};
    c_q          <= {psum_bw{1'b0}};
    load_ready_q <= 1'b1;
    inst_w_q     <= 2'b00;
  end else begin
    inst_q       <= inst_d;
    a_q          <= a_d;
    b_q          <= b_d;
    c_q          <= c_d;
    load_ready_q <= load_ready_d;
    inst_w_q     <= inst_w_d;
  end
end

endmodule
