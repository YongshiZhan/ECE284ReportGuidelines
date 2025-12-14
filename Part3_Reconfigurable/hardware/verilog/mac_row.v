// Created by prof. Mingu Kang @VVIP Lab in UCSD ECE department
// Please do not spread this code without permission 
module mac_row (
  clk, reset,
  out_s, in_w, in_n, valid, inst_w,
  flush
);

  parameter bw = 4;
  parameter psum_bw = 16;
  parameter col = 8;
  parameter inst_bw = 3;

  input  clk, reset;
  output [psum_bw*col-1:0] out_s;
  output [col-1:0] valid;
  input  [bw-1:0] in_w; // inst[1]:execute, inst[0]: kernel loading
  input  [inst_bw-1:0] inst_w;
  input  [psum_bw*col-1:0] in_n;
  input flush; // flush signal to send internal psum out

  // ------------------------------------------------------------
  // Internal signals
  // ------------------------------------------------------------
  wire  [(col+1)*bw-1:0] temp;      // activation east chain
  wire  [2*col-1:0]       inst_temp; // instruction east chain
  wire  [psum_bw*col-1:0] out_s_int;
  wire  [(col+1)*inst_bw:0] inst_wire;    // helper array
  assign temp[bw-1:0]   = in_w;
  assign inst_wire[2:0]   = inst_w;

  genvar i;
  generate
    for (i=0; i<col; i=i+1) begin : col_num
      mac_tile #(.bw(bw), .psum_bw(psum_bw)) mac_tile_instance (
        .clk(clk),
        .reset(reset),
        .in_w( temp[bw*i +: bw] ),
        .out_e( temp[bw*(i+1) +: bw] ),
        .inst_w( inst_wire[inst_bw*i+:inst_bw] ),
        .inst_e( inst_wire[inst_bw*(i+1)+:inst_bw] ),
        .in_n( in_n[psum_bw*i +: psum_bw] ),
        .out_s( out_s_int[psum_bw*i +: psum_bw] ),
        .flush(flush)
      );
      assign valid[i] = inst_wire[inst_bw*(i+1)+1]; // ?: Do we need to gate valid with flush?
    end
  endgenerate

  assign out_s = out_s_int;

endmodule
