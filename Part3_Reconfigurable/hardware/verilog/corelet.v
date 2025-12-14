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

module corelet #(
  parameter bw = 4,
  parameter psum_bw = 16,
  parameter row = 8,
  parameter col = 8,
  parameter inst_bw = 3,
  parameter KERNEL_SIZE = 9  // kernel size for OS mode
)(
  input  clk,
  input  reset,


  // L0 / MAC array interface
  input  [row*bw-1:0] l0_din,
  input  l0_wr,
  input  l0_rd,
  input  [inst_bw-1:0] inst_w,
  input  flush_in,
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

  // IFIFO interface
  input  [row*bw-1:0] ififo_din,
  input  ififo_wr,
  input  ififo_rd,
  output ififo_full,
  output ififo_ready
);

  // ---------------------------------------------------------------------------
  // L0 buffer for activations
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
  // Input FIFO for weights
  // ---------------------------------------------------------------------------
  wire [row*bw-1:0] ififo_out;
  ififo #(.row(row), .bw(bw)) ififo_inst (
    .clk(clk),
    .in(ififo_din),
    .out(ififo_out),
    .rd(ififo_rd),
    .wr(ififo_wr),
    .o_full(ififo_full),
    .o_ready(ififo_ready),
    .reset(reset)
  );

  // ---------------------------------------------------------------------------
  // MAC array
  // ---------------------------------------------------------------------------
  wire [col*psum_bw-1:0] mac_psum;
  wire [col-1:0]         mac_valid;
  wire [col*psum_bw-1:0] zero_chain = {col*psum_bw{1'b0}};
  wire [col*psum_bw-1:0] mux_in_n;
  // Generate flush signal for MAC array based on mode and inst_w
  // TODO: double check the flush timing
  reg [col-1:0] os_mac_cnt;
  always @(posedge clk) begin
    if (reset) begin
        os_mac_cnt <= 0;
    end else if (inst_w[2] && inst_w[1]) begin  
        // inst_w[2] = OS mode
        // inst_w[1] = execute bit
        if (os_mac_cnt == KERNEL_SIZE - 1)  
            os_mac_cnt <= 0;
        else
            os_mac_cnt <= os_mac_cnt + 1;
    end
    // $display("mode=%b execute=%b os_mac_cnt=%d", inst_w[2], inst_w[1], os_mac_cnt);
end
  wire mux_flush = inst_w[2] ? (os_mac_cnt == KERNEL_SIZE - 1) : 1'b0; // only flush in OS mode
  // In OS mode, feed forwarded weights from IFIFO as psum input
  wire [col*psum_bw-1:0] in_n_os;
  genvar j;
  generate
    for (j = 0; j < col; j = j + 1) begin : gen_in_n_os
      assign in_n_os[psum_bw*j +: psum_bw] = {
        {(psum_bw-bw){1'b0}},
        ififo_out[bw*j +: bw]
      };
    end
  endgenerate
  assign mux_in_n = inst_w[2] ? in_n_os : zero_chain;

  mac_array #(.bw(bw), .psum_bw(psum_bw), .col(col), .row(row)) mac_array_inst (
    .clk(clk),
    .reset(reset),
    .out_s(mac_psum),
    .in_w(l0_out),
    .in_n(mux_in_n), // zero psum input
    .inst_w(inst_w),
    .valid(mac_valid), 
    .flush(flush_in) //mux_flush
  );

  // ---------------------------------------------------------------------------
  // Output FIFO for psums
  // ---------------------------------------------------------------------------
  ofifo #(.col(col), .bw(psum_bw)) ofifo_inst (
    .clk(clk),
    .in(mac_psum),
    .out(ofifo_dout),
    .rd(ofifo_rd),
    .wr(inst_w[2] ? {col{flush_in}} : mac_valid), //mac_valid
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
