/*
initiates sram_32b_w2048 modules
parameters:
  data width (multiple of 32 bits)
  word depth

Issues R/W on SRAM arrays.

*/

module sram(CLK, D, Q, CEN, WEN, A);
    parameter num = 2048; // number of words
    parameter data_width = 32; // data width in bits
  input  CLK;
  input  WEN;
  input  CEN;
  input  [data_width-1:0] D;
  input  [$clog2(num)-1:0] A;
  output [data_width-1:0] Q;

  localparam sram_width = data_width / 32; // number of sram blocks can be used in parallel
  localparam sram_depth = num / 2048; // number of sram blocks needed in depth

  localparam ADDR_W = $clog2(num);
  localparam DEPTH_BLOCKS = (num + 2047) / 2048;
  localparam BANK_W = (DEPTH_BLOCKS <= 1) ? 1 : $clog2(DEPTH_BLOCKS);

  wire [ADDR_W-1:0] addr_int = A;
  wire [10:0] addr_low;
  wire [BANK_W-1:0] bank_sel;

  generate
    if (DEPTH_BLOCKS == 1) begin
      assign bank_sel = 0;
      assign addr_low = addr_int[ADDR_W-1:0];
    end else begin
      assign bank_sel = addr_int[ADDR_W-1:11];
      assign addr_low = addr_int[10:0];
    end
  endgenerate

  // banked Qs: depth first, then width slices
  wire [data_width-1:0] q_per_bank [0:DEPTH_BLOCKS-1];

  genvar d, w;
  generate
    for (d = 0; d < DEPTH_BLOCKS; d = d + 1) begin : depth_blk
      wire cen_bank = CEN | ((DEPTH_BLOCKS > 1) ? (bank_sel != d[BANK_W-1:0]) : 1'b0);
      for (w = 0; w < sram_width; w = w + 1) begin : width_blk
        sram_32b_w2048 mem (
          .CLK(CLK),
          .D(D[w*32 +: 32]),
          .Q(q_per_bank[d][w*32 +: 32]),
          .CEN(cen_bank),
          .WEN(WEN),
          .A(addr_low)
        );
      end
    end
  endgenerate

  assign Q = q_per_bank[bank_sel];

endmodule
