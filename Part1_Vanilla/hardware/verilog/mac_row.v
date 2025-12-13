// Created by prof. Mingu Kang @VVIP Lab in UCSD ECE department
// Please do not spread this code without permission 
module mac_row (
  clk, reset,
  out_s, in_w, in_n, valid, inst_w
);

  parameter bw = 4;
  parameter psum_bw = 16;
  parameter col = 8;

  input  clk, reset;
  output [psum_bw*col-1:0] out_s;
  output [col-1:0] valid;
  input  [bw-1:0] in_w; // inst[1]:execute, inst[0]: kernel loading
  input  [1:0] inst_w;
  input  [psum_bw*col-1:0] in_n;

  // ------------------------------------------------------------
  // Internal signals
  // ------------------------------------------------------------
  wire  [(col+1)*bw-1:0] temp;      // activation east chain
  wire  [2*col-1:0]       inst_temp; // instruction east chain
  wire  [psum_bw*col-1:0] out_s_int;
  wire  [col*2+1:0] inst_wire;    // helper array
  assign temp[bw-1:0]   = in_w;
  assign inst_wire[1:0]   = inst_w;

  genvar i;
  generate
    for (i=0; i<col; i=i+1) begin : col_num
      mac_tile #(.bw(bw), .psum_bw(psum_bw)) mac_tile_instance (
        .clk(clk),
        .reset(reset),
        .in_w( temp[bw*i +: bw] ),
        .out_e( temp[bw*(i+1) +: bw] ),
        .inst_w( inst_wire[2*i+:2] ),
        .inst_e( inst_wire[2*(i+1)+:2] ),
        .in_n( in_n[psum_bw*i +: psum_bw] ),
        .out_s( out_s_int[psum_bw*i +: psum_bw] )
      );
      assign valid[i] = inst_wire[2*(i+1)+1]; // valid = execute bit
    end
  endgenerate

  assign out_s = out_s_int;

endmodule
