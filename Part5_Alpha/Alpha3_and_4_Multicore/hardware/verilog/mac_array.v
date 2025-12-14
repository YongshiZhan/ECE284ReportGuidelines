// Created by prof. Mingu Kang @VVIP Lab in UCSD ECE department
// Please do not spread this code without permission 

// 2bit merge: add
// 4bit merge: left shift 2bit & add
module mac_array (clk, reset, out_s, in_w, in_n, inst_w, valid, cfg_2b);

  parameter bw = 4;
  parameter psum_bw = 16;
  parameter col = 8;
  parameter row = 8;

  input  clk, reset;
  output [psum_bw*col-1:0] out_s;
  input  [row*bw-1:0] in_w; // inst[1]:execute, inst[0]: kernel loading
  input  [1:0] inst_w;
  input  [psum_bw*col-1:0] in_n;
  output [col-1:0] valid;
  input  cfg_2b; // new port to indicate 2b mode


  reg    [2*row-1:0] inst_w_temp;
  wire   [psum_bw*col*(row+1)-1:0] temp0, temp1;
  wire   [row*col-1:0] valid_temp;


  genvar i;

  generate
    for (i=0; i < col; i=i+1) begin : col_num
      assign out_s[psum_bw*i +: psum_bw] = 
        cfg_2b ? 
        (temp0[psum_bw*col*8 + psum_bw*i +: psum_bw] + temp1[psum_bw*col*8 + psum_bw*i +: psum_bw]) : 
        (temp0[psum_bw*col*8 + psum_bw*i +: psum_bw] + (temp1[psum_bw*col*8 + psum_bw*i +: psum_bw] << 2));
    end
  endgenerate
 
  assign temp0[psum_bw*col*1-1:psum_bw*col*0] = 0;
  assign temp1[psum_bw*col*1-1:psum_bw*col*0] = 0;
  assign valid = valid_temp[row*col-1:row*col-8];

  generate
    for (i=1; i < row+1 ; i=i+1) begin : row_num
        mac_row #(.bw(bw), .psum_bw(psum_bw)) mac_row_instance (
          .clk(clk),
          .reset(reset),
          .in_w(in_w[bw*i-1:bw*(i-1)]),
          .inst_w(inst_w_temp[2*i-1:2*(i-1)]),
          .in_n0(temp0[psum_bw*col*i-1:psum_bw*col*(i-1)]),
          .in_n1(temp1[psum_bw*col*i-1:psum_bw*col*(i-1)]),
          .valid(valid_temp[col*i-1:col*(i-1)]),
          .out_s0(temp0[psum_bw*col*(i+1)-1:psum_bw*col*(i)]),
          .out_s1(temp1[psum_bw*col*(i+1)-1:psum_bw*col*(i)]),
          .cfg_2b(cfg_2b)
        );
    end
  endgenerate

  always @ (posedge clk) begin
    //valid <= valid_temp[row*col-1:row*col-8];
    inst_w_temp[1:0]   <= inst_w; 
    inst_w_temp[3:2]   <= inst_w_temp[1:0]; 
    inst_w_temp[5:4]   <= inst_w_temp[3:2]; 
    inst_w_temp[7:6]   <= inst_w_temp[5:4]; 
    inst_w_temp[9:8]   <= inst_w_temp[7:6]; 
    inst_w_temp[11:10] <= inst_w_temp[9:8]; 
    inst_w_temp[13:12] <= inst_w_temp[11:10]; 
    inst_w_temp[15:14] <= inst_w_temp[13:12]; 
  end



endmodule
