// Created by prof. Mingu Kang @VVIP Lab in UCSD ECE department
// Please do not spread this code without permission 
module ofifo (clk, in, out, rd, wr, o_full, reset, o_ready, o_valid);

  parameter col  = 8;
  parameter bw = 4;

  input  clk;
  input  [col-1:0] wr;                 // 1-bit per column
  input  rd;
  input  reset;
  input  [col*bw-1:0] in;              // packed vector of columns
  output [col*bw-1:0] out;             // packed vector of columns
  output o_full;
  output o_ready;
  output o_valid;

  wire [col-1:0] empty;
  wire [col-1:0] full;
  reg  rd_en;
  
  genvar i;

  wire any_full  = |full;
  wire any_empty = |empty;

  assign o_ready = ~any_full;          // room to receive more data
  assign o_full  =  any_full;          // any FIFO full
  assign o_valid = ~any_empty;         // full vector ready (all non-empty)

  generate
    for (i=0; i<col ; i=i+1) begin : col_num
      fifo_depth64 #(.bw(bw)) fifo_instance (
         .rd_clk(clk),
         .wr_clk(clk),
         .rd(rd_en),                   // read all columns at a time
         .wr(wr[i] & ~any_full),       // per-col write, globally stalled if any full
         .o_empty(empty[i]),
         .o_full(full[i]),
         .in(in[(i+1)*bw-1 : i*bw]),
         .out(out[(i+1)*bw-1 : i*bw]),
         .reset(reset)
      );
    end
  endgenerate


  always @ (posedge clk) begin
    if (reset) begin
      rd_en <= 0;
    end
    else begin
      // Read out all columns together only when a full vector is ready
      if (rd && o_valid)
        rd_en <= 1'b1;
      else
        rd_en <= 1'b0;
    end
  end

endmodule
