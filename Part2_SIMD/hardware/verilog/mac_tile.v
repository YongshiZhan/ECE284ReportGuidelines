module mac_tile (
  clk, reset,
  in_w, out_e,
  in_n0, in_n1,
  out_s0, out_s1,
  inst_w, inst_e,
  cfg_2b
);

parameter bw = 4;
parameter psum_bw = 16;

// ---------------- Ports ----------------
input  clk, reset;
input  [bw-1:0] in_w;
input  [psum_bw-1:0] in_n0, in_n1;
input  [1:0] inst_w;
input  cfg_2b;

output [bw-1:0] out_e;
output [psum_bw-1:0] out_s0, out_s1;
output [1:0] inst_e;

// ---------------- Registers ----------------
reg  [1:0] inst_q, inst_d;
reg  [bw/2-1:0] a0_q, a0_d, a1_q, a1_d;
reg  [bw-1:0] b0_q, b0_d, b1_q, b1_d;
reg  [psum_bw-1:0] c0_q, c0_d, c1_q, c1_d;
reg  load_ready0_q, load_ready0_d, load_ready1_q, load_ready1_d;
reg  [1:0] inst_w_d, inst_w_q;

wire [psum_bw-1:0] mac_out0, mac_out1;

// ---------------- Connections ----------------
assign out_e  = {a1_q, a0_q};
assign inst_e = inst_q;
assign out_s0  = mac_out0;
assign out_s1  = mac_out1;

// ---------------- MAC Block ----------------
mac #(.a_bw(bw/2), .b_bw(bw), .psum_bw(psum_bw)) mac_instance_0 (
  .a(a0_q),
  .b(b0_q),
  .c(c0_q),
  .out(mac_out0)
);

mac #(.a_bw(bw/2), .b_bw(bw), .psum_bw(psum_bw)) mac_instance_1 (
  .a(a1_q),
  .b(b1_q),
  .c(c1_q),
  .out(mac_out1)
);

// ---------------- Combinational logic ----------------
always @(*) begin
  // defaults
  inst_d       = inst_q;
  a0_d          = a0_q;
  a1_d          = a1_q;
  b0_d          = b0_q;
  b1_d          = b1_q;
  c0_d          = c0_q;
  c1_d          = c1_q;
  load_ready0_d = load_ready0_q;
  load_ready1_d = load_ready1_q;
  inst_w_d = inst_w;

  // always forward execute bit
  inst_d[1] = inst_w_d[1];

  if (cfg_2b) begin // TODO: 2bit mode
    // latch activation on kernel_load or execute
    if ((inst_w_d[0] & !load_ready1_q ) | inst_w_d[1]) begin
      {a1_d, a0_d} = in_w;
    end

    // kernel load when ready
    if (inst_w_d[0]) begin
      if (load_ready0_q) begin // load b0
        b0_d          = in_w;
        load_ready0_d = 1'b0;
      end else if (load_ready1_q) begin // load b1
        b1_d          = in_w;
        load_ready1_d = 1'b0;
      end
    end

    // after kernel load, forward inst_w[0] and re-arm load_ready
    if (!load_ready1_q) begin
      inst_d[0]    = inst_w_d[0];
      // Re-enable load at falling edge of inst_w[1], which is end of execute round
      if (inst_w_q[1] && !inst_w_d[1]) begin
        load_ready0_d = 1'b1;
        load_ready1_d = 1'b1;
      end
    end else begin
      inst_d[0]    = 1'b0;
    end

    // during execute, latch psum input
    if (inst_w[1]) begin
      c0_d = in_n0;
      c1_d = in_n1;
    end
  end else begin // 4bit mode
    // latch activation on kernel_load or execute
    if (inst_w_d[0] | inst_w_d[1]) begin
      {a1_d, a0_d} = in_w;
    end

    // kernel load when ready
    if (inst_w_d[0] && load_ready0_q && load_ready1_q) begin
      // broadcast input to both b0 and b1
      b0_d          = in_w;
      b1_d          = in_w;
      load_ready0_d = 1'b0;
      load_ready1_d = 1'b0;
    end

    // after kernel load, forward inst_w[0] and re-arm load_ready
    if (!load_ready0_q && !load_ready1_q) begin
      inst_d[0]    = inst_w_d[0];
      // Re-enable load at falling edge of inst_w[1], which is end of execute round
      if (inst_w_q[1] && !inst_w_d[1]) begin
        load_ready0_d = 1'b1;
        load_ready1_d = 1'b1;
      end
    end else begin
      inst_d[0]    = 1'b0;
    end

    // during execute, latch psum input
    if (inst_w[1]) begin
      c0_d = in_n0;
      c1_d = in_n1;
    end
  end
end

// ---------------- Sequential logic ----------------
always @(posedge clk) begin
  if (reset) begin
    inst_q       <= 2'b00;
    a0_q         <= {bw/2{1'b0}};
    a1_q         <= {bw/2{1'b0}};
    b0_q         <= {bw{1'b0}};
    b1_q         <= {bw{1'b0}};
    c0_q         <= {psum_bw{1'b0}};
    c1_q         <= {psum_bw{1'b0}};
    load_ready0_q <= 1'b1;
    load_ready1_q <= 1'b1;
    inst_w_q     <= 2'b00;
  end else begin
    inst_q       <= inst_d;
    a0_q         <= a0_d;
    a1_q         <= a1_d;
    b0_q         <= b0_d;
    b1_q         <= b1_d;
    c0_q         <= c0_d;
    c1_q         <= c1_d;
    load_ready0_q <= load_ready0_d;
    load_ready1_q <= load_ready1_d;
    inst_w_q     <= inst_w_d;
  end
end

endmodule
