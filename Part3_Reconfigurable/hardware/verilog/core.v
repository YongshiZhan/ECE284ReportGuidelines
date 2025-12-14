/*
  core.v: thin wrapper that instantiates the four SRAMs and corelet datapath.

  All control is now driven externally (e.g., from the testbench). The host/testbench
  is responsible for sequencing load/execute/accumulate, steering L0 writes/reads,
  and explicitly writing/reading each SRAM.
*/

module core #(
  parameter bw         = 4,
  parameter psum_bw    = 16,
  parameter row        = 8,
  parameter col        = 8,
  parameter KERNEL_SIZE = 3,
  parameter IMAGE_SIZE  = 28,
  parameter inst_bw = 3
)(
  input  clk,
  input  reset,

  // Weight SRAM
  input                         w_cen,
  input                         w_wen,
  input  [$clog2(KERNEL_SIZE*KERNEL_SIZE*col)-1:0] w_addr,
  input  [row*bw-1:0]           w_d,
  output [row*bw-1:0]           w_q,

  // Activation SRAM
  input                         x_cen,
  input                         x_wen,
  input  [$clog2(IMAGE_SIZE*IMAGE_SIZE)-1:0]       x_addr,
  input  [row*bw-1:0]           x_d,
  output [row*bw-1:0]           x_q,

  // Psum SRAM
  input                         psum_cen,
  input                         psum_wen,
  input  [$clog2((KERNEL_SIZE*KERNEL_SIZE)*(IMAGE_SIZE*IMAGE_SIZE))-1:0] psum_addr,
  input  [col*psum_bw-1:0]      psum_d,
  output [col*psum_bw-1:0]      psum_q,

  // Output SRAM
  input                         out_cen,
  input                         out_wen,
  input  [$clog2(IMAGE_SIZE*IMAGE_SIZE)-1:0]       out_addr,
  input  [col*psum_bw-1:0]      out_d,
  output [col*psum_bw-1:0]      out_q,

  // Corelet / datapath controls
  input  [row*bw-1:0]           l0_din,
  input                         l0_wr,
  input                         l0_rd,
  input  [inst_bw-1:0]                  inst_w,
  output                        l0_full,
  output                        l0_ready,

  input                         ofifo_rd,
  output                        ofifo_valid,
  output                        ofifo_ready,
  output                        ofifo_full,
  output [col*psum_bw-1:0]      ofifo_dout,

  input                         sfu_acc_en,
  input                         sfu_write_en,
  output [col*psum_bw-1:0]      sfp_out,

  input  [row*bw-1:0]           ififo_din,
  input                         ififo_wr,
  input                         ififo_rd,
  input                         flush_in,
  output                        ififo_full,
  output                        ififo_ready
);

  localparam KIJ         = KERNEL_SIZE * KERNEL_SIZE;
  localparam ACT_DEPTH   = IMAGE_SIZE * IMAGE_SIZE;
  localparam WGT_DEPTH   = KIJ * col;
  localparam PSUM_DEPTH  = ACT_DEPTH * KIJ;
  localparam OUT_DEPTH   = ACT_DEPTH;

  // ---------------------------------------------------------------------------
  // SRAM instances
  // ---------------------------------------------------------------------------
  sram #(.num(WGT_DEPTH), .data_width(row*bw)) weight_sram (
    .CLK(clk), .D(w_d), .Q(w_q), .CEN(w_cen), .WEN(w_wen), .A(w_addr)
  );

  sram #(.num(ACT_DEPTH), .data_width(row*bw)) activation_sram (
    .CLK(clk), .D(x_d), .Q(x_q), .CEN(x_cen), .WEN(x_wen), .A(x_addr)
  );

  sram #(.num(PSUM_DEPTH), .data_width(col*psum_bw)) psum_sram (
    .CLK(clk), .D(psum_d), .Q(psum_q), .CEN(psum_cen), .WEN(psum_wen), .A(psum_addr)
  );

  sram #(.num(OUT_DEPTH), .data_width(col*psum_bw)) output_sram (
    .CLK(clk), .D(out_d), .Q(out_q), .CEN(out_cen), .WEN(out_wen), .A(out_addr)
  );

  // ---------------------------------------------------------------------------
  // Corelet datapath
  // ---------------------------------------------------------------------------
  corelet #(.bw(bw), .psum_bw(psum_bw), .row(row), .col(col)) corelet_inst (
    .clk(clk),
    .reset(reset),
    .l0_din(l0_din),
    .l0_wr(l0_wr),
    .l0_rd(l0_rd),
    .inst_w(inst_w),
    .l0_full(l0_full),
    .l0_ready(l0_ready),
    .ofifo_rd(ofifo_rd),
    .ofifo_valid(ofifo_valid),
    .ofifo_ready(ofifo_ready),
    .ofifo_full(ofifo_full),
    .ofifo_dout(ofifo_dout),
    .sfu_acc_en(sfu_acc_en),
    .sfu_write_en(sfu_write_en),
    .psum_in(psum_q),
    .sfp_out(sfp_out),
    .ififo_din  (ififo_din),
    .ififo_wr   (ififo_wr),
    .ififo_rd   (ififo_rd),
    .ififo_full (ififo_full),
    .ififo_ready(ififo_ready),
    .flush_in(flush_in)
  );

endmodule
