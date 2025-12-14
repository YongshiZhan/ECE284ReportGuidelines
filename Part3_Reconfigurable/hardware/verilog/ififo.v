module ififo (clk, in, out, rd, wr, o_full, reset, o_ready);

  parameter row  = 8;
  parameter bw = 4;

  input  clk;
  input  wr;
  input  rd;
  input  reset;
  input  [row*bw-1:0] in;
  output [row*bw-1:0] out;
  output o_full;
  output o_ready;

  wire [row-1:0] full;
  wire [row-1:0] empty; // not used
  wire [row-1:0] rd_chain_d; // read signals per row
  reg  [row-1:0] rd_chain_q;

  // ------------------------------------------------------------------
  // Status
  // ------------------------------------------------------------------
  wire any_full  = |full;
  assign o_full  = any_full;     // any FIFO full -> stop writes
  assign o_ready = ~any_full;    // at least one has room -> ready

  // ------------------------------------------------------------------
  // Write enable: all rows written together if all not full
  // ------------------------------------------------------------------
  wire wr_en_all = wr & ~any_full;

  // ------------------------------------------------------------------
  // Read propagation chain:
  // rd_chain[0] = rd
  // rd_chain[i] = delayed version of rd_chain[i-1]
  // ------------------------------------------------------------------
  assign rd_chain_d = {rd_chain_q[row-2:0], rd};
  always @(posedge clk or posedge reset) begin
    if (reset)
      rd_chain_q <= 0;
    else
      rd_chain_q <= rd_chain_d;
  end

  // ------------------------------------------------------------------
  // Instantiate FIFOs
  // ------------------------------------------------------------------
  genvar i;
  generate
    for (i = 0; i < row; i = i + 1) begin : row_num
      fifo_depth64 #(.bw(bw)) fifo_instance (
         .rd_clk(clk),
         .wr_clk(clk),
         .rd(rd_chain_q[i]),
         .wr(wr_en_all),
         .o_empty(empty[i]),  // connected but unused
         .o_full(full[i]),
         .in(in[(i+1)*bw-1 : i*bw]),
         .out(out[(i+1)*bw-1 : i*bw]),
         .reset(reset)
      );
    end
  endgenerate

endmodule
