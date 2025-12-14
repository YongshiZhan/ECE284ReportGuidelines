module mac_tile (
  clk, reset,
  in_w, out_e,
  in_n, out_s,
  inst_w, inst_e,
  flush
);

  parameter bw = 4;
  parameter psum_bw = 16;

  // ---------------- Ports ----------------
  input  clk, reset;
  input  [bw-1:0] in_w;
  input  [psum_bw-1:0] in_n;
  input  [2:0] inst_w; // inst[2]: mode, 0 if weight stationary, 1 if output stationary, inst[1]:execute, inst[0]: kernel loading
  input flush; // flush signal to send internal psum out

  output [bw-1:0] out_e;
  output [psum_bw-1:0] out_s;
  output [2:0] inst_e;

  // ---------------- Registers ----------------
  reg  [2:0] inst_q, inst_d;
  reg  [bw-1:0] a_q, a_d;
  reg  [bw-1:0] b_q, b_d;
  reg  [psum_bw-1:0] c_q, c_d;
  reg  load_ready_q, load_ready_d;
  reg  [2:0] inst_w_d, inst_w_q;
  // reg  flush_d, flush_q; // ?: does flush need to be registered?
  reg  [psum_bw-1:0] c_accumulate = 0;
  reg  flush_prev, flush_first_1;
  reg [psum_bw-1:0] out_s_os;

  wire [psum_bw-1:0] mac_out;
  // OS vertical weight forwarding
  wire [psum_bw-1:0] weight_ext = {{(psum_bw-bw){1'b0}}, b_q};
  wire flush_first;
  assign flush_first = ~flush_prev & flush; 
  // ---------------- Connections ----------------
  assign out_e  = a_q;
  assign inst_e = inst_q;
  assign out_s  = inst_w[2] ? out_s_os : mac_out; // on the first flush indicated by flush_first, wire out_s to c_accumulate. Then in all subsequent flushes, wire out_s to in_n


// ---------------- MAC Block ----------------
mac #(.bw(bw), .psum_bw(psum_bw)) mac_instance (
  .a(a_q),
  .b(b_q),
  .c(inst_w_d[2] ? c_accumulate : c_q),
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
  // flush_d = flush;

  // always forward execute bit
  inst_d[1] = inst_w_d[1];
  inst_d[2] = inst_w_d[2];

  

  if (!inst_w_d[2]) begin
      // weight stationary mode

      // latch activation on kernel_load or execute
      if (inst_w_d[0] || inst_w_d[1])
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
      if (inst_w_d[1]) begin
        c_d = in_n;
      end

  end else begin
  // output stationary mode
    inst_d[0] = inst_w_d[0];

    if (inst_w_d[1] && !flush) begin
    // during normal operation, latch weight input
      a_d = in_w;
      b_d = in_n[bw-1:0];
      c_d = mac_out;
      // $display("[debug] MAC_TILE OS mode: a=%d, b=%d, c=%d", a_d, b_d, c_d);
    end else if (flush) begin
      // FLUSH behavior: just forward current psum out
      c_d = c_accumulate; // = in_n before edit
      // $display("[debug] MAC_TILE OS flush: psum=%d", c_d);
    end
    // else begin
    //   c_d = in_n;
    // or set c_d to 0?
    // end

    end

end

// ---------------- Sequential logic ----------------
always @(posedge clk) begin
  if (reset) begin
    inst_q       <= 3'b000;
    a_q          <= {bw{1'b0}};
    b_q          <= {bw{1'b0}};
    c_q          <= {psum_bw{1'b0}};
    load_ready_q <= 1'b1;
    inst_w_q     <= 3'b000;
    flush_prev  <= 0;
    flush_first_1 <= 0;
    out_s_os <= 0;
    //c_accumulate <= 0;
  end else begin
    inst_q       <= inst_d;
    a_q          <= a_d;
    b_q          <= b_d;
    c_q          <= c_d;
    load_ready_q <= load_ready_d;
    inst_w_q     <= inst_w_d;
    c_accumulate <= inst_w_d[1] && !flush ? mac_out : c_accumulate;
    flush_prev  <= flush;
    flush_first_1 <= flush_first;
    out_s_os <= (flush ? (flush_first_1 ? c_accumulate : in_n) : weight_ext);
  end
end

endmodule
