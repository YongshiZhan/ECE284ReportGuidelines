/*
SFP is for special function processing, which in our cases includes accumulation and ReLU.
SFP is initiated under corelet.v
input through corelet.v from psum SRAM
output through corelet.v to output SRAM
As part of a systolic array, SFP should process data in a pipelined manner,
    e.g. each critical path does 1 addition per cycle.

SFP Control Flow:
corelet.v issues input enable: read from psum SRAM, read address given from corelet
    The stored data += psum read from psum SRAM
corelet.v issues output enable: write to output SRAM, write address given from corelet
    Apply ReLU for the stored data before writing to output SRAM
    Clear the stored data after writing to output SRAM

*/

module sfp #(
  parameter col = 8,
  parameter psum_bw = 16
)(
  input  clk,
  input  reset,
  input  acc_en,                          // accumulate incoming psum vector
  input  write_en,                        // emit ReLUed vector and clear
  input  [col*psum_bw-1:0] in,
  output reg [col*psum_bw-1:0] out
);

  reg [col*psum_bw-1:0] store_q, store_d;
  reg [col*psum_bw-1:0] out_d;

  integer i;

  // combinational next-state logic
  always @(*) begin
    store_d = store_q;
    out_d   = {col*psum_bw{1'b0}};

    if (write_en) begin
      // ReLU per lane
      for (i = 0; i < col; i = i + 1) begin
        if (store_q[psum_bw*i + psum_bw-1]) // negative
          out_d[psum_bw*i +: psum_bw] = {psum_bw{1'b0}};
        else
          out_d[psum_bw*i +: psum_bw] = store_q[psum_bw*i +: psum_bw];
      end
      store_d = {col*psum_bw{1'b0}};
    end

    if (acc_en) begin
      // accumulate after any clear for the required priority
      for (i = 0; i < col; i = i + 1) begin
        store_d[psum_bw*i +: psum_bw] = store_d[psum_bw*i +: psum_bw] + in[psum_bw*i +: psum_bw];
      end
    end
  end

  always @(posedge clk) begin
    if (reset) begin
      store_q <= {col*psum_bw{1'b0}};
      out     <= {col*psum_bw{1'b0}};
    end else begin
      store_q <= store_d;
      out     <= out_d;
    end
  end

endmodule
