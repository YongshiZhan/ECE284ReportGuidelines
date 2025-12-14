/*
What is a corelet?
corelet.v is just a wrapper that includes all blocks you designed so far (L0/Input
FIFO, OFIFO, MAC Array). For part4, only corelet (not core) is required to be
implemented.


Workflow: Load kernel
control signals: host/testbench (through core.v) -> corelet.v
input from: weight SRAM
output to: N/A
dataflow: input -(vertical)-> L0 -(Diagonal)-> MAC Array (PE, Processing Element)

Workflow: Load activation and compute psum
control signals: host/testbench (through core.v) -> corelet.v
input from: activation SRAM
output to: psum SRAM
dataflow: input -(vertical)-> L0 -(Diagonal)-> MAC Array (PE, Processing Element) -(Diagonal)-> ofifo -(vertical)-> output

Workflow: SFP (special function processing, e.g. ReLU, accumulation)
# Theoretically SFP can be done parallely with MAC Array computation, but for now for simplicity
# we do it sequentially after MAC Array computation is done.
control signals: host/testbench (through core.v) -> corelet.v
input from: psum SRAM
output to: output SRAM
dataflow: input -(vertical)-> SFP -(vertical)-> output

For each workflow valid/ready signals should be properly designed to ensure correct
dataflow without data loss or corruption.
*/

module ece284_final_project_alpha4_corelet #(
  parameter bw = 4,
  parameter psum_bw = 16,
  parameter row = 16,
  parameter col = 8,
  parameter half_row = row / 2
)(
  input  clk,
  input  reset,

  // core0
  // L0 / MAC array interface
  input  [row*bw-1:0] l0_din,
  input  l0_wr,
  input  l0_rd,
  input  [1:0] inst_w,
  output l0_full,
  output l0_ready,

  // OFIFO interface
  input  ofifo_rd,
  output ofifo_valid,
  output ofifo_ready,
  output ofifo_full,
  output [col*psum_bw-1:0] ofifo_dout,

  // SFP interface
  input  sfu_acc_en,
  input  sfu_write_en,
  input  [col*psum_bw-1:0] psum_in,
  output [col*psum_bw-1:0] sfp_out,

  input  cfg_2b // new port to indicate 2b mode
);


  // ---------------------------------------------------------------------------
  // L0 buffer
  // ---------------------------------------------------------------------------
  wire [row*bw-1:0] l0_out;
  l0 #(.row(row), .bw(bw)) l0_buffer (
    .clk(clk),
    .in(l0_din),
    .out(l0_out),
    .rd(l0_rd),
    .wr(l0_wr),
    .o_full(l0_full),
    .o_ready(l0_ready),
    .reset(reset)
  );

  // ---------------------------------------------------------------------------
  // MAC array
  // ---------------------------------------------------------------------------
  wire [col*psum_bw-1:0] mac_psum0, mac_psum1;
  wire [col-1:0]         mac_valid0, mac_valid1;
  wire [col*psum_bw-1:0] zero_chain = {col*psum_bw{1'b0}};

  mac_array #(.bw(bw), .psum_bw(psum_bw), .col(col), .row(half_row)) mac_array_inst0 (
    .clk(clk),
    .reset(reset),
    .out_s(mac_psum0),
    .in_w(l0_out[half_row*bw-1:0]),
    .in_n(zero_chain), // zero psum input
    .inst_w(inst_w),
    .valid(mac_valid0),
    .cfg_2b(cfg_2b)
  );

  mac_array #(.bw(bw), .psum_bw(psum_bw), .col(col), .row(half_row)) mac_array_inst1 (
    .clk(clk),
    .reset(reset),
    .out_s(mac_psum1),
    .in_w(l0_out[row*bw-1:half_row*bw]),
    .in_n(zero_chain), // zero psum input
    .inst_w(inst_w),
    .valid(mac_valid1),
    .cfg_2b(cfg_2b)
  );

  // ---------------------------------------------------------------------------
  // Output FIFO for psums
  // ---------------------------------------------------------------------------
  ofifo #(.col(col), .bw(psum_bw)) ofifo_inst (
    .clk(clk),
    .in({mac_psum1, mac_psum0}),
    .out(ofifo_dout),
    .rd(ofifo_rd),
    .wr({mac_valid1, mac_valid0}),
    .o_full(ofifo_full),
    .reset(reset),
    .o_ready(ofifo_ready),
    .o_valid(ofifo_valid)
  );

  // ---------------------------------------------------------------------------
  // Special function processor
  // ---------------------------------------------------------------------------
  sfp #(.col(col), .psum_bw(psum_bw)) sfp_inst (
    .clk(clk),
    .reset(reset),
    .acc_en(sfu_acc_en),
    .write_en(sfu_write_en),
    .in(psum_in),
    .out(sfp_out)
  );

endmodule
