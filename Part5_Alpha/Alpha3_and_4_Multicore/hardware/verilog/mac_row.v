// Created by prof. Mingu Kang @VVIP Lab in UCSD ECE department
// Please do not spread this code without permission 
module mac_row (
  clk, reset,
  out_s0, out_s1, in_w, in_n0, in_n1, valid, inst_w, cfg_2b
);

  parameter bw = 4;
  parameter psum_bw = 16;
  parameter col = 8;

  input  clk, reset;
  output [psum_bw*col-1:0] out_s0, out_s1;
  output [col-1:0] valid;
  input  [bw-1:0] in_w; // inst[1]:execute, inst[0]: kernel loading
  input  [1:0] inst_w;
  input  [psum_bw*col-1:0] in_n0, in_n1;
  input  cfg_2b; // new port to indicate 2b mode

  // ------------------------------------------------------------
  // Internal signals
  // ------------------------------------------------------------
  wire  [(col+1)*bw-1:0] temp;      // activation east chain
  wire  [2*col-1:0]       inst_temp; // instruction east chain
  wire  [psum_bw*col-1:0] out_s0_int, out_s1_int;
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
        .in_n0( in_n0[psum_bw*i +: psum_bw] ),
        .in_n1( in_n1[psum_bw*i +: psum_bw] ),
        .out_s0( out_s0_int[psum_bw*i +: psum_bw] ),
        .out_s1( out_s1_int[psum_bw*i +: psum_bw] ), 
        .cfg_2b(cfg_2b)
      );
      assign valid[i] = inst_wire[2*(i+1)+1]; // valid = execute bit
    end
  endgenerate

  assign out_s0 = out_s0_int;
  assign out_s1 = out_s1_int;

endmodule
