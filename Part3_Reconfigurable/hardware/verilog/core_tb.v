// Created by prof. Mingu Kang @VVIP Lab in UCSD ECE department
// Please do not spread this code without permission 
`timescale 1ns/1ps

module core_tb;

parameter bw = 4;
parameter psum_bw = 16;
parameter col = 8;
parameter row = 8;
parameter KERNEL_SIZE = 3;
parameter IMAGE_SIZE  = 6;
parameter len_kij = KERNEL_SIZE*KERNEL_SIZE;
parameter IMAGE_SIZE_O = IMAGE_SIZE - KERNEL_SIZE + 1;
parameter len_nij = IMAGE_SIZE*IMAGE_SIZE;
// New: inst_bw is now 3, to select either WS(weight-stationary) or OS (output-stationary)
// inst_w[2:0] — {mode, execute, load}, default mode (inst_w[2]=0) is WS, otherwise OS
parameter inst_bw = 3;

localparam W_ADDR_W    = $clog2(KERNEL_SIZE*KERNEL_SIZE*col);
localparam X_ADDR_W    = $clog2(IMAGE_SIZE*IMAGE_SIZE);
localparam PSUM_ADDR_W = $clog2((KERNEL_SIZE*KERNEL_SIZE)*(IMAGE_SIZE*IMAGE_SIZE));
localparam OUT_ADDR_W  = $clog2(IMAGE_SIZE*IMAGE_SIZE);

// New limit: only the first 8 output channels and first 8 nij
localparam OUT_CH = 8;
localparam OUT_NIJ = 8;

reg clk = 0;
reg reset = 1;

reg [bw*row-1:0] D_wmem_q = 0;
reg [bw*row-1:0] D_xmem_q = 0;
reg [col*psum_bw-1:0] D_pmem_q = 0;
reg [col*psum_bw-1:0] D_omem_q = 0;
reg CEN_xmem = 1;
reg WEN_xmem = 1;
reg [X_ADDR_W-1:0] A_xmem = 0;
reg CEN_xmem_q = 1;
reg WEN_xmem_q = 1;
reg [X_ADDR_W-1:0] A_xmem_q = 0;
reg CEN_wmem = 1;
reg WEN_wmem = 1;
reg [W_ADDR_W-1:0] A_wmem = 0;
reg CEN_wmem_q = 1;
reg WEN_wmem_q = 1;
reg [W_ADDR_W-1:0] A_wmem_q = 0;
reg CEN_pmem = 1;
reg WEN_pmem = 1;
reg [PSUM_ADDR_W-1:0] A_pmem = 0;
reg CEN_pmem_q = 1;
reg WEN_pmem_q = 1;
reg [PSUM_ADDR_W-1:0] A_pmem_q = 0;
reg CEN_omem = 1;
reg WEN_omem = 1;
reg [OUT_ADDR_W-1:0] A_omem = 0;
reg CEN_omem_q = 1;
reg WEN_omem_q = 1;
reg [OUT_ADDR_W-1:0] A_omem_q = 0;
reg ofifo_rd_q = 0;

// register IFIFO port
reg ififo_wr_q = 0;
reg ififo_rd_q = 0;

reg l0_rd_q = 0;
reg l0_wr_q = 0;
reg execute_q = 0;
reg load_q = 0;
reg acc = 0;

reg [inst_bw-1:0]  inst_w; 
reg [bw*row-1:0] D_wmem;
reg [bw*row-1:0] D_xmem;
reg [col*psum_bw-1:0] D_pmem;
reg [col*psum_bw-1:0] D_omem;
reg [psum_bw*col-1:0] answer;

reg ofifo_rd;

// IFIFO signals: sending weights into PE array via IFIFO
reg ififo_wr;
reg ififo_rd;
reg [bw*row-1:0] ififo_din;
wire [bw*row-1:0] ififo_q;
wire ififo_full;
wire ififo_ready;

reg l0_rd;
reg l0_wr;
wire l0_ready;
reg execute;
reg load;
reg [8*100:1] stringvar;
reg [8*100:1] w_file_name;
reg [8*100:1] acc_file_name;
wire ofifo_valid;
wire [col*psum_bw-1:0] sfp_out;
wire [bw*row-1:0] Q_wmem;
wire [bw*row-1:0] Q_xmem;
wire [col*psum_bw-1:0] Q_pmem;
wire [col*psum_bw-1:0] Q_omem;
wire [row*bw-1:0] l0_din = load_q ? Q_wmem : Q_xmem;
reg sfu_write_en;


integer x_file, x_scan_file ; // file_handler
integer w_file, w_scan_file ; // file_handler
integer acc_file, acc_scan_file ; // file_handler
integer out_file, out_scan_file ; // file_handler
integer captured_data; 
integer t, i, j, k, nij, kij, t_i, t_j, k_i, k_j;
integer error;
integer os_in_ch = 8; // TODO
integer warm;

integer debug;
integer test_mode;
integer base;

wire [col*psum_bw-1:0] ofifo_dout;

reg [8*32-1:0] weight_data_str;
reg flush_in;

core #(
  .bw(bw),
  .psum_bw(psum_bw),
  .col(col),
  .row(row),
  .KERNEL_SIZE(KERNEL_SIZE),
  .IMAGE_SIZE(IMAGE_SIZE),
  .inst_bw(inst_bw)
) core_instance (
  .clk(clk),
  .reset(reset),
  .w_cen(CEN_wmem_q),
  .w_wen(WEN_wmem_q),
  .w_addr(A_wmem_q),
  .w_d(D_wmem_q),
  .w_q(Q_wmem),
  .x_cen(CEN_xmem_q),
  .x_wen(WEN_xmem_q),
  .x_addr(A_xmem_q),
  .x_d(D_xmem_q),
  .x_q(Q_xmem),
  .psum_cen(CEN_pmem_q),
  .psum_wen(WEN_pmem_q),
  .psum_addr(A_pmem_q),
  .psum_d(D_pmem_q),
  .psum_q(Q_pmem),
  .out_cen(CEN_omem_q),
  .out_wen(WEN_omem_q),
  .out_addr(A_omem_q),
  .out_d(D_omem_q),
  .out_q(Q_omem),
  .l0_din(l0_din),
  .l0_wr(l0_wr_q),
  .l0_rd(l0_rd_q),
  .inst_w(inst_w),
  .l0_full(),
  .l0_ready(l0_ready),
  .ofifo_rd(ofifo_rd_q),
  .ofifo_valid(ofifo_valid),
  .ofifo_ready(),
  .ofifo_full(),
  .ofifo_dout(ofifo_dout),
  .sfu_acc_en(acc),
  .sfu_write_en(sfu_write_en),
  .sfp_out(sfp_out),

  // IFIFO ports
  .ififo_din(ififo_din),
  .ififo_wr(ififo_wr_q),
  .ififo_rd(ififo_rd_q),
  .ififo_full(ififo_full),
  .ififo_ready(ififo_ready),
  .flush_in(flush_in)
); 


initial begin 

  inst_w   = 0; 
  D_wmem   = 0;
  D_xmem   = 0;
  D_pmem   = 0;
  D_omem   = 0;
  CEN_xmem = 1;
  WEN_xmem = 1;
  A_xmem   = 0;
  CEN_wmem = 1;
  WEN_wmem = 1;
  A_wmem   = 0;
  CEN_omem = 1;
  WEN_omem = 1;
  A_omem   = 0;
  ofifo_rd = 0;

  // ififo initialization
  ififo_wr = 0;
  ififo_rd = 0;
  ififo_din = 0;

  l0_rd    = 0;
  l0_wr    = 0;
  execute  = 0;
  load     = 0;
  acc      = 0;
  sfu_write_en = 0;
  flush_in = 0;


  $dumpfile("core_tb.vcd");
  $dumpvars(0,core_tb);

  x_file = $fopen("../datafiles/activation.txt", "r");

  // Following three lines are to remove the first three comment lines of the file
  x_scan_file = $fscanf(x_file,"%s", captured_data);
  x_scan_file = $fscanf(x_file,"%s", captured_data);
  x_scan_file = $fscanf(x_file,"%s", captured_data);

  //////// Reset /////////
  #0.5 clk = 1'b0;   reset = 1;
  #0.5 clk = 1'b1; 

  for (i=0; i<10 ; i=i+1) begin
    #0.5 clk = 1'b0;
    #0.5 clk = 1'b1;  
  end

  #0.5 clk = 1'b0;   reset = 0;
  #0.5 clk = 1'b1; 

  #0.5 clk = 1'b0;   
  #0.5 clk = 1'b1;   
  /////////////////////////

  /////// Activation data writing to memory ///////
  $display("############ Writing activation data to memory #############");
  for (t_i = 0; t_i < IMAGE_SIZE; t_i = t_i + 1) begin
    for (t_j = 0; t_j < IMAGE_SIZE; t_j = t_j + 1) begin
      #0.5 clk = 1'b0;
      A_xmem = t_i * IMAGE_SIZE + t_j;
      if (t_i == 0 || t_j == 0 || t_i == IMAGE_SIZE-1 || t_j == IMAGE_SIZE-1) begin
        // zero-padding
        D_xmem = 0;
      end else begin
        // read from file
        x_scan_file = $fscanf(x_file,"%32b", D_xmem);
      end
      WEN_xmem = 0;
      CEN_xmem = 0;
      #0.5 clk = 1'b1;
    end
  end

  #0.5 clk = 1'b0;  WEN_xmem = 1;  CEN_xmem = 1; A_xmem = 0;
  #0.5 clk = 1'b1; 

  $fclose(x_file);
  /////////////////////////////////////////////////


  //////////////////////////////////////////////////////////
  ////////////// TEST MODE SELECTION ///////////////////////
  //////////////////////////////////////////////////////////
  // Set test_mode = 0 for WS mode, test_mode = 1 for OS mode
  
  for (test_mode = 0; test_mode <= 1; test_mode = test_mode + 1) begin
    // full WS or OS test
  if (test_mode == 0) begin
    $display("############ Testing WS Mode #############");
  end else begin
    $display("############ Testing OS Mode #############");
  end
  //////////////////////////////////////////////////////////

  for (kij=0; kij<len_kij; kij=kij+1) begin  // kij loop
    k_i = kij / KERNEL_SIZE;
    k_j = kij % KERNEL_SIZE;

    case(kij)
     0: w_file_name = "../datafiles/weight_itile0_otile0_kij0_fixed.txt";
     1: w_file_name = "../datafiles/weight_itile0_otile0_kij1_fixed.txt";
     2: w_file_name = "../datafiles/weight_itile0_otile0_kij2_fixed.txt";
     3: w_file_name = "../datafiles/weight_itile0_otile0_kij3_fixed.txt";
     4: w_file_name = "../datafiles/weight_itile0_otile0_kij4_fixed.txt";
     5: w_file_name = "../datafiles/weight_itile0_otile0_kij5_fixed.txt";
     6: w_file_name = "../datafiles/weight_itile0_otile0_kij6_fixed.txt";
     7: w_file_name = "../datafiles/weight_itile0_otile0_kij7_fixed.txt";
     8: w_file_name = "../datafiles/weight_itile0_otile0_kij8_fixed.txt";
    endcase
    
    w_file = $fopen(w_file_name, "r");
    if (w_file == 0) begin
      $display("Error opening weight file %s", w_file_name);
      $finish;
    end

    #0.5 clk = 1'b0;   reset = 1;
    #0.5 clk = 1'b1; 

    for (i=0; i<10 ; i=i+1) begin
      #0.5 clk = 1'b0;
      #0.5 clk = 1'b1;  
    end

    #0.5 clk = 1'b0;   reset = 0;
    #0.5 clk = 1'b1; 

    #0.5 clk = 1'b0;   
    #0.5 clk = 1'b1;   

    if (test_mode == 0) begin
      //========================================
      // WEIGHT-STATIONARY (WS) MODE
      //========================================
      
      /////// Kernel data writing to memory ///////
      $display("############ [WS] Writing kernel data to memory #############");

      A_wmem = 0;

      for (t=0; t<col; t=t+1) begin  
        #0.5 clk = 1'b0;  
        w_scan_file = $fscanf(w_file,"%32b", D_wmem); 
        WEN_wmem = 0; CEN_wmem = 0; if (t>0) A_wmem = A_wmem + 1;
        #0.5 clk = 1'b1;  
      end

      #0.5 clk = 1'b0;  WEN_wmem = 1;  CEN_wmem = 1; A_wmem = 0;
      #0.5 clk = 1'b1; 
      
      /////////////////////////////////////

      /////// Kernel data writing to L0 //////s/
      // WS mode: read from wmem into L0 by asserting load=1 and pulsing l0_wr
      $display("############ [WS] Writing Kernel data to L0 #############"); 
      
      A_wmem = 0;
      load = 1; // selects Q_wmem into l0_din
      inst_w = 3'b000; // WS mode (inst_w[2]=0)

      for (t=0; t < col + 1; t=t+1) begin
        #0.5 clk = 1'b0; 
        if (t < col) begin
          CEN_wmem = 0; WEN_wmem = 1; 
        end 
        if (t>0) begin 
          A_wmem = A_wmem + 1; l0_wr = 1;
        end
        #0.5 clk = 1'b1;

        #0.5 clk = 1'b0;
          l0_wr = 0;
        #0.5 clk = 1'b1;
      end

      // finish wmem read
      #0.5 clk = 1'b0; CEN_wmem = 1; WEN_wmem = 1; A_wmem = 0; load = 0;
      #0.5 clk = 1'b1;
      /////////////////////////////////////

      /////// Kernel loading to PEs (WS Mode) ///////
      $display("############ [WS] Loading Kernel data to PEs #############"); 
      for (i=0; i<8 ; i=i+1) begin
        #0.5 clk = 1'b0; 
        l0_rd = 1;
        if (i > 0) inst_w = 3'b001; // {mode=0(WS), execute=0, load=1}
        #0.5 clk = 1'b1;
      end
      for (i=0; i<8 ; i=i+1) begin
        #0.5 clk = 1'b0;
        if (i > 0) inst_w = 3'b000;
        #0.5 clk = 1'b1;
      end
      /////////////////////////////////////

      ////// provide some intermission to clear up the kernel loading ///
      #0.5 clk = 1'b0;  load = 0; l0_rd = 0;
      #0.5 clk = 1'b1;  
    
      for (i=0; i<10 ; i=i+1) begin
        #0.5 clk = 1'b0;
        #0.5 clk = 1'b1;  
      end
      /////////////////////////////////////

      /////// Activation data writing to L0 ///////
      CEN_xmem = 0;
      WEN_xmem = 1;
      A_xmem = 0;
      load = 0; // selects Q_xmem into l0_din
      $display("############ [WS] Writing Activation data to L0 #############");

      for (t_i=0; t_i < IMAGE_SIZE_O; t_i = t_i + 1) begin
        for (t_j=0; t_j < IMAGE_SIZE_O; t_j = t_j + 1) begin
          #0.5 clk = 1'b0; 
          if (t_i != 0 || t_j != 0) l0_wr = 1;
          
          A_xmem = (t_i + k_i) * IMAGE_SIZE + (t_j + k_j);
          #0.5 clk = 1'b1;

          #0.5 clk = 1'b0;
            l0_wr = 0;
          #0.5 clk = 1'b1;
        end
      end
      #0.5 clk = 1'b0;
        l0_wr = 1;
      #0.5 clk = 1'b1;
      #0.5 clk = 1'b0;
        l0_wr = 0;
      #0.5 clk = 1'b1;

      // finish xmem read
      #0.5 clk = 1'b0;
        CEN_xmem = 1;
        WEN_xmem = 1;
        A_xmem = 0;
      #0.5 clk = 1'b1;
      /////////////////////////////////////

      /////// Execution (WS Mode) ///////
      #0.5 clk = 1'b0; l0_rd = 1;
      execute = 1;
      #0.5 clk = 1'b1;

      $display("############ [WS] Execution #############"); 
      for (t=0; t<IMAGE_SIZE_O*IMAGE_SIZE_O; t=t+1) begin
        #0.5 clk = 1'b0;
        if (t == 0) begin
          inst_w = 3'b010; // {mode=0(WS), execute=1, load=0}
        end 
        if (t == IMAGE_SIZE_O*IMAGE_SIZE_O -1) begin
          l0_rd = 0;
        end
        #0.5 clk = 1'b1;
      end

      // de-assert execute
      #0.5 clk = 1'b0;
        inst_w = 3'b000;
        execute = 0;
      #0.5 clk = 1'b1;
      /////////////////////////////////////

      //////// OFIFO READ (WS Mode) ////////
      $display("############ [WS] Reading OFIFO #############");
      for (t=0; t< (IMAGE_SIZE_O*IMAGE_SIZE_O); t=t+1) begin
        #0.5 clk = 1'b0;
          if (ofifo_valid) begin
            ofifo_rd = 1;
          end else begin
            ofifo_rd = 0;
          end
        #0.5 clk = 1'b1;
        #0.5 clk = 1'b0;
          ofifo_rd = 0;
          // Write OFIFO output to psum memory
          CEN_pmem = 0;
          WEN_pmem = 0;
          A_pmem = (kij * IMAGE_SIZE_O*IMAGE_SIZE_O) + t;
          D_pmem = ofifo_dout;
        #0.5 clk = 1'b1;
      end
      
      #0.5 clk = 1'b0;
        CEN_pmem = 1;
        WEN_pmem = 1;
      #0.5 clk = 1'b1;
      /////////////////////////////////////
      
    end else begin
      //========================================
      // OUTPUT-STATIONARY (OS) MODE
      //========================================
      
      /////// Kernel data writing to memory ///////

       /////// Activation data writing to L0 ///////
      // For this nij position, we need the single activation value at [t_i+k_i,t_j+k_j]
      CEN_xmem = 0;
      WEN_xmem = 1;
      A_xmem = 0;
      load = 0; // selects Q_xmem into l0_din
      $display("############ [OS] Writing Activation data to L0 #############");

      for (t = 0; t < IMAGE_SIZE; t = t + 1) begin
        
          #0.5 clk = 1'b0; 
           

            A_xmem = t * IMAGE_SIZE + t_j; // TODO: wrong indexing?
            l0_wr = 0;
          #0.5 clk = 1'b1;

          #0.5 clk = 1'b0;
            l0_wr = 1;
          #0.5 clk = 1'b1;

          #0.5 clk = 1'b0;
            l0_wr = 0;
          #0.5 clk = 1'b1;
        
      end
      // #0.5 clk = 1'b0;
      //   l0_wr = 1;
      // #0.5 clk = 1'b1;
      // #0.5 clk = 1'b0;
      //   l0_wr = 0;
      // #0.5 clk = 1'b1;

      // finish xmem read
      #0.5 clk = 1'b0;
        CEN_xmem = 1;
        WEN_xmem = 1;
        A_xmem = 0;
      #0.5 clk = 1'b1;
      ////////////////////////////

      $display("############ [OS] Writing kernel data to memory #############");

      A_wmem = 0;

      for (t=0; t<col; t=t+1) begin  
        #0.5 clk = 1'b0;  
        base = t * 32;
        w_scan_file = $fscanf(w_file,"%32b", D_wmem); 
        WEN_wmem = 0; CEN_wmem = 0; if (t>0) A_wmem = A_wmem + 1; 
        weight_data_str[base +: 32] = D_wmem;
        #0.5 clk = 1'b1;  
      end

      #0.5 clk = 1'b0;  WEN_wmem = 1;  CEN_wmem = 1; A_wmem = 0;
      #0.5 clk = 1'b1; 
      /////////////////////////////////////
      
      /////// Send kernel data into IFIFO (OS mode) ///////
      // Read from wmem and stream into IFIFO
      $display("############ [OS] Streaming kernel data from wmem into IFIFO #############");
      
      inst_w = 3'b100; // OS mode (inst_w[2]=1)
      ififo_wr = 0;
      ififo_rd = 0;
      A_wmem = 0;
      
      #0.5 clk = 1'b0;
      #0.5 clk = 1'b1;

      // Push `OUT_NIJ` weight words into IFIFO (one output channel worth of weights)
      // Read from wmem and write to IFIFO
      for (t=0; t<OUT_NIJ; t=t+1) begin
        #0.5 clk = 1'b0;
        base = t * 4;
        if (!ififo_full) begin
          ififo_din = {
            weight_data_str[base + 224 +: 4],
            weight_data_str[base + 192 +: 4],
            weight_data_str[base + 160 +: 4],
            weight_data_str[base + 128 +: 4],
            weight_data_str[base +  96 +: 4],
            weight_data_str[base +  64 +: 4],
            weight_data_str[base +  32 +: 4],
            weight_data_str[base       +: 4]
          };
          ififo_wr = 1;
          // $display("Debug: wrote weight into IFIFO", ififo_din);
        end
        #0.5 clk = 1'b1;
        
        #0.5 clk = 1'b0;
          ififo_wr = 0;
        #0.5 clk = 1'b1;
      end

      // Finish wmem read
      #0.5 clk = 1'b0;
        CEN_wmem = 1; 
        WEN_wmem = 1; 
        A_wmem = 0;
      #0.5 clk = 1'b1;

      // Give some time for weights to propagate through IFIFO
      for (i=0; i<10; i=i+1) begin
        #0.5 clk = 1'b0;
        #0.5 clk = 1'b1;
      end
      /////////////////////////////////////



      /////// Activation data writing to L0 ///////
      // For this nij position, we need the single activation value at [t_i+k_i,t_j+k_j]
      CEN_xmem = 0;
      WEN_xmem = 1;
      A_xmem = 0;
      load = 0; // selects Q_xmem into l0_din
      $display("############ [OS] Writing Activation data to L0 #############");

      for (t_i=0; t_i < IMAGE_SIZE_O/2; t_i = t_i + 1) begin
        for (t_j=0; t_j < IMAGE_SIZE_O; t_j = t_j + 1) begin
          #0.5 clk = 1'b0; 
          if (t_i != 0 || t_j != 0) l0_wr = 1;

          A_xmem = (t_i + (k_i / 3)) * IMAGE_SIZE + (t_j + (k_j % 3));
          #0.5 clk = 1'b1;

          #0.5 clk = 1'b0;
            l0_wr = 0;
          #0.5 clk = 1'b1;
        end
      end
      #0.5 clk = 1'b0;
        l0_wr = 1;
      #0.5 clk = 1'b1;
      #0.5 clk = 1'b0;
        l0_wr = 0;
      #0.5 clk = 1'b1;

      // finish xmem read
      #0.5 clk = 1'b0;
        CEN_xmem = 1;
        WEN_xmem = 1;
        A_xmem = 0;
      #0.5 clk = 1'b1;
      ////////////////////////////
 

 

      /////// Execution (OS Mode) ///////
      $display("############ [OS] Execution with internal accumulation #############"); 
      #0.5 clk = 1'b0; 
      l0_rd = 1;
      #0.5 clk = 1'b1;

      for (t=0; t<5; t=t+1) begin
        #0.5 clk = 1'b0;
        #0.5 clk = 1'b1;
      end

      #0.5 clk = 1'b0; 
        execute = 1;
        ififo_rd = 1; // Start reading from IFIFO to feed weights
        //inst_w = 3'b110; // {mode=1(OS), execute=1, load=0}
      #0.5 clk = 1'b1;

      for (t=0; t<col+2; t=t+1) begin //t<IMAGE_SIZE_O*IMAGE_SIZE_O;
        #0.5 clk = 1'b0;
        if (t == 0) begin
          inst_w = 3'b110; // {mode=1(OS), execute=1, load=0}
        end 
        if (t == col+1) begin
          l0_rd = 0;
          ififo_rd = 0;
          inst_w = 3'b100; // Keep OS mode but stop execute
        end
        #0.5 clk = 1'b1;
      end

      // de-assert execute
      #0.5 clk = 1'b0;
        
      #0.5 clk = 1'b1;
      
      // Give some cycles for pipeline to drain
      for (i=0; i<row+2; i=i+1) begin
        #0.5 clk = 1'b0;
        #0.5 clk = 1'b1;
      end

      //inst_w = 3'b100; // Keep OS mode but stop execute
      execute = 0;
      l0_rd = 0;
      ififo_rd = 0;
      /////////////////////////////////////



      
    end // end of test_mode if-else

    $fclose(w_file);

  end  // end of kij loop

  if (test_mode == 1) begin
    for (t=0; t<OUT_NIJ+1; t=t+1) begin
      #0.5 clk = 1'b0;
      flush_in = 1;
      #0.5 clk = 1'b1;  
    end
    #0.5 clk = 1'b0;
    flush_in = 0;
    #0.5 clk = 1'b1;

    for (t=0; t<10 ; t=t+1) begin
      #0.5 clk = 1'b0;
      #0.5 clk = 1'b1;  
    end

    for (t=0; t<OUT_NIJ+2; t=t+1) begin
      #0.5 clk = 1'b0;
      if (ofifo_valid) begin
        ofifo_rd = 1;
        CEN_pmem = 0;
        WEN_pmem = 0;
      end
      else begin
        ofifo_rd = 0;
      end
       
        // psum(out_ch, nij_out) += w(out_ch, in_ch, kij) * x(in_ch, nij')
        // where nij' = f(nij, kij) is the shifted index of nij for conv
      if (t>2) begin
        A_pmem = 8*(t-2);
        D_pmem = ofifo_dout;
      end 
      else if (t==OUT_NIJ) begin
        CEN_pmem = 1;
        WEN_pmem = 1;
      end
      #0.5 clk = 1'b1; 
    end
    #0.5 clk = 1'b0;
    ofifo_rd = 0;
    #0.5 clk = 1'b1;
  end

  

  error = 0;

  $display("############ Psum checking... #############");
  
  if (test_mode == 0) begin
    // WS mode: check all kij * nij outputs
    for (kij=0; kij<len_kij; kij=kij+1) begin 
      case(kij)
        0: acc_file_name = "../datafiles/psum_0.txt";
        1: acc_file_name = "../datafiles/psum_1.txt";
        2: acc_file_name = "../datafiles/psum_2.txt";
        3: acc_file_name = "../datafiles/psum_3.txt";
        4: acc_file_name = "../datafiles/psum_4.txt";
        5: acc_file_name = "../datafiles/psum_5.txt";
        6: acc_file_name = "../datafiles/psum_6.txt";
        7: acc_file_name = "../datafiles/psum_7.txt";
        8: acc_file_name = "../datafiles/psum_8.txt";
        default: $error("Invalid kij index");
      endcase

      acc_file = $fopen(acc_file_name, "r");
      if (acc_file == 0) begin
        $display("Error opening psum file %s", acc_file_name);
        $finish;
      end
      
      for (j=0; j<IMAGE_SIZE_O*IMAGE_SIZE_O+2; j=j+1) begin
        #0.5 clk = 1'b0;
        if (j < IMAGE_SIZE_O*IMAGE_SIZE_O) begin
          CEN_pmem = 0; WEN_pmem = 1; 
          A_pmem = (kij * IMAGE_SIZE_O*IMAGE_SIZE_O) + j;
        end else begin
          CEN_pmem = 1; WEN_pmem = 1; 
          A_pmem = 0;
        end
        if (j > 1) begin
          acc_scan_file = $fscanf(acc_file,"%128b", answer);
          if (Q_pmem !== answer) begin
            $display("[WS] Psum Data ERROR at kij=%0d, j=%0d", kij, j-2); 
            $display("psum_q: %32h", Q_pmem);
            $display("answer: %32h", answer); 
            error += 1;
          end
        end
        #0.5 clk = 1'b1;
      end
      $fclose(acc_file);   
    end
  end else begin
    // OS mode: not need this check
  

  end

  $display("############ Verification Start during accumulation #############"); 

  if (test_mode == 0) begin
    ////////// Accumulation /////////
    out_file = $fopen("../datafiles/psum_relu.txt", "r");  

    // Following three lines are to remove the first three comment lines of the file
    out_scan_file = $fscanf(out_file,"%s", answer); 
    out_scan_file = $fscanf(out_file,"%s", answer); 
    out_scan_file = $fscanf(out_file,"%s", answer); 
    // WS mode: accumulate across all kij for each nij
    for (i=0; i<IMAGE_SIZE_O*IMAGE_SIZE_O; i=i+1) begin 

      #0.5 clk = 1'b0; 
      #0.5 clk = 1'b1;

      for (kij = 0; kij < len_kij + 2; kij = kij + 1) begin
        #0.5 clk = 1'b0; 
        if (kij > 1) begin
          acc = 1;
        end else begin
          acc = 0;
        end
        if (kij < len_kij) begin
          CEN_pmem = 0; WEN_pmem = 1; 
          A_pmem = (kij * IMAGE_SIZE_O*IMAGE_SIZE_O) + i;
        end else begin
          CEN_pmem = 1; WEN_pmem = 1;
          A_pmem = 0;
        end
        #0.5 clk = 1'b1;
      end

      // acc -> store
      #0.5 clk = 1'b0; 
        acc = 0;
        sfu_write_en = 1;
      #0.5 clk = 1'b1;
      #0.5 clk = 1'b0; sfu_write_en = 0;
      CEN_omem = 0; WEN_omem = 0;
      A_omem = i;
      D_omem = sfp_out;

      out_scan_file = $fscanf(out_file,"%128b", answer);
      if (sfp_out === answer)
        $display("[WS] %2d-th output featuremap Data matched! :D", i); 
      else begin
        $display("[WS] %2d-th output featuremap Data ERROR!!", i); 
        $display("sfpout: %4h %4h %4h %4h %4h %4h %4h %4h", sfp_out[127:112], sfp_out[111:96], sfp_out[95:80], sfp_out[79:64], sfp_out[63:48], sfp_out[47:32], sfp_out[31:16], sfp_out[15:0]);
        $display("answer: %4h %4h %4h %4h %4h %4h %4h %4h", answer[127:112], answer[111:96], answer[95:80], answer[79:64], answer[63:48], answer[47:32], answer[31:16], answer[15:0]);
        error = 1;
      end
      #0.5 clk = 1'b1;

      #0.5 clk = 1'b0;
      CEN_omem = 1; WEN_omem = 1;
      #0.5 clk = 1'b1;
    end
  end else begin
    ////////// Accumulation /////////
    out_file = $fopen("../datafiles/psum_relu.txt", "r");  

    // Following three lines are to remove the first three comment lines of the file
    out_scan_file = $fscanf(out_file,"%s", answer); 
    out_scan_file = $fscanf(out_file,"%s", answer); 
    out_scan_file = $fscanf(out_file,"%s", answer); 
    // accumulate across all kij for each nij position (first 8)
  //for (nij=0; nij < 8; nij = nij +1) begin
  for (i=0; i<col; i=i+1) begin 

      #0.5 clk = 1'b0; 
      #0.5 clk = 1'b1;

      // Accumulate this PE's outputs across all kij for this nij
      
        
            
      
        #0.5 clk = 1'b0;
          CEN_pmem = 0; WEN_pmem = 1; 
          A_pmem = 8*i; //(nij*len_kij*col) + (kij * col) + i; 
        #0.5 clk = 1'b1; #0.5 clk = 1'b0;
          CEN_pmem = 1; WEN_pmem = 1;
          A_pmem = 0;
        #0.5 clk = 1'b1;

        #0.5 clk = 1'b0;  
          acc = 1;
        #0.5 clk = 1'b1; #0.5 clk = 1'b0;
          acc = 0;
           #0.5 clk = 1'b1;
      //end

      // acc -> store
      #0.5 clk = 1'b0; 
        acc = 0;
        sfu_write_en = 1;
      #0.5 clk = 1'b1;
      #0.5 clk = 1'b0; sfu_write_en = 0;
      // write sfp out to output memory
      CEN_omem = 0; WEN_omem = 0;
      A_omem = 8*i;
      D_omem = sfp_out;

      out_scan_file = $fscanf(out_file,"%128b", answer);
      if (sfp_out === answer)
        //$display("[OS] nij%0d, PE%0d output featuremap Data matched! :D", nij, i); 
        $display("[OS] PE%0d output featuremap Data matched! :D", i); 
      else begin
        //$display("[OS] nij%0d, PE%0d output featuremap Data ERROR!!", nij, i); 
        $display("[OS] PE%0d output featuremap Data ERROR!!", i); 
        $display("sfpout: %4h %4h %4h %4h %4h %4h %4h %4h", sfp_out[127:112], sfp_out[111:96], sfp_out[95:80], sfp_out[79:64], sfp_out[63:48], sfp_out[47:32], sfp_out[31:16], sfp_out[15:0]);
        $display("answer: %4h %4h %4h %4h %4h %4h %4h %4h", answer[127:112], answer[111:96], answer[95:80], answer[79:64], answer[63:48], answer[47:32], answer[31:16], answer[15:0]);
        error = 1;
      end
      #0.5 clk = 1'b1;

      #0.5 clk = 1'b0;
      CEN_omem = 1; WEN_omem = 1;
      #0.5 clk = 1'b1;
  end
  end
  

  $fclose(out_file);

  if (error == 0) begin
  	$display("############ No error detected ##############"); 
  	$display("########### Project Completed !! ############"); 
  end
  
  for (t=0; t<10; t=t+1) begin  
    #0.5 clk = 1'b0;  
    #0.5 clk = 1'b1;  
  end
  end // end of test_mode for loop

  #10 $finish;

end

always @ (posedge clk) begin
   D_wmem_q   <= D_wmem;
   D_xmem_q   <= D_xmem;
   D_pmem_q   <= D_pmem;
   D_omem_q   <= D_omem;
   CEN_wmem_q <= CEN_wmem;
   WEN_wmem_q <= WEN_wmem;
   A_wmem_q   <= A_wmem;
   CEN_xmem_q <= CEN_xmem;
   WEN_xmem_q <= WEN_xmem;
   A_xmem_q   <= A_xmem;
   A_pmem_q   <= A_pmem;
   CEN_pmem_q <= CEN_pmem;
   WEN_pmem_q <= WEN_pmem;
   CEN_omem_q <= CEN_omem;
   WEN_omem_q <= WEN_omem;
   A_omem_q   <= A_omem;
   ofifo_rd_q <= ofifo_rd;
   ififo_wr_q <= ififo_wr;
   ififo_rd_q <= ififo_rd;
   l0_rd_q    <= l0_rd;
   l0_wr_q    <= l0_wr ;
   execute_q  <= execute;
   load_q     <= load;
end

endmodule