// Created by prof. Mingu Kang @VVIP Lab in UCSD ECE department
// Please do not spread this code without permission 
module mac_array (clk, reset, out_s, in_w, in_n, inst_w, valid, flush);

  parameter bw = 4;
  parameter psum_bw = 16;
  parameter col = 8;
  parameter row = 8;
  parameter inst_bw = 3;

  input  clk, reset;
  output [psum_bw*col-1:0] out_s;
  input  [row*bw-1:0] in_w; // inst[1]:execute, inst[0]: kernel loading
  input  [inst_bw-1:0] inst_w;
  input  [psum_bw*col-1:0] in_n;
  output [col-1:0] valid;
  input flush; // flush signal to send internal psum out


  reg    [inst_bw*row-1:0] inst_w_temp;
  wire   [psum_bw*col*(row+1)-1:0] temp;
  wire   [row*col-1:0] valid_temp;


  genvar i;
 
  assign out_s = temp[psum_bw*col*(row+1)-1:psum_bw*col*row];
  // assign temp[psum_bw*col*1-1:psum_bw*col*0] = 0;
  assign temp[psum_bw*col*1-1:psum_bw*col*0] = in_n;
  assign valid = valid_temp[row*col-1:row*col-8];

  for (i=1; i < row+1 ; i=i+1) begin : row_num
      mac_row #(.bw(bw), .psum_bw(psum_bw)) mac_row_instance (
        .clk(clk),
        .reset(reset),
        .in_w(in_w[bw*i-1:bw*(i-1)]),
        .inst_w(inst_w_temp[inst_bw*i-1:inst_bw*(i-1)]),
        .in_n(temp[psum_bw*col*i-1:psum_bw*col*(i-1)]),
        .valid(valid_temp[col*i-1:col*(i-1)]),
        .out_s(temp[psum_bw*col*(i+1)-1:psum_bw*col*(i)]),
        .flush(flush)
    );
  end

  always @ (posedge clk) begin


    //valid <= valid_temp[row*col-1:row*col-8];
    inst_w_temp[2:0]   <= inst_w; 
    inst_w_temp[5:3]    <= inst_w_temp[2:0]; 
    inst_w_temp[8:6]    <= inst_w_temp[5:3]; 
    inst_w_temp[11:9]   <= inst_w_temp[8:6]; 
    inst_w_temp[14:12]  <= inst_w_temp[11:9]; 
    inst_w_temp[17:15]  <= inst_w_temp[14:12]; 
    inst_w_temp[20:18]  <= inst_w_temp[17:15]; 
    inst_w_temp[23:21]  <= inst_w_temp[20:18];  
  end



endmodule
