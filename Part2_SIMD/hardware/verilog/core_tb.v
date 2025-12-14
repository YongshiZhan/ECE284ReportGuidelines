// Created by prof. Mingu Kang @VVIP Lab in UCSD ECE department
// Please do not spread this code without permission 
`timescale 1ns/1ps
`define MAX_LINE 1024  // max characters per line

module core_tb;

parameter bw = 4;
parameter col = 8; // Output channel
parameter row = 8; // Input channel for 2_bit activation mode
parameter psum_bw = 16; // configurable as 16/8?
parameter act_bw = 4; // activation bitwidth: bigger of 2/4
parameter KERNEL_SIZE = 3;
parameter IMAGE_SIZE  = 6;
parameter len_kij = KERNEL_SIZE*KERNEL_SIZE;
parameter IMAGE_SIZE_O = IMAGE_SIZE - KERNEL_SIZE + 1;
parameter len_nij = IMAGE_SIZE*IMAGE_SIZE;


parameter ACT_DEPTH   = IMAGE_SIZE * IMAGE_SIZE;
parameter WGT_DEPTH   = len_kij * col * 2; // doubled for 2b mode
parameter PSUM_DEPTH  = ACT_DEPTH * len_kij * 2; // doubled for 2b mode 2 tiles
parameter OUT_DEPTH   = ACT_DEPTH * 2; // doubled for 2b mode 2 tiles


parameter W_ADDR_W    = $clog2(WGT_DEPTH);
parameter X_ADDR_W    = $clog2(ACT_DEPTH);
parameter PSUM_ADDR_W = $clog2(PSUM_DEPTH);
parameter OUT_ADDR_W  = $clog2(OUT_DEPTH);

reg clk = 0;
reg reset = 1;

reg cfg_2b;

reg [bw*row-1:0] D_wmem_q = 0;
reg [act_bw*row-1:0] D_xmem_q = 0;
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
reg ififo_wr_q = 0;
reg ififo_rd_q = 0;
reg l0_rd_q = 0;
reg l0_wr_q = 0;
reg execute_q = 0;
reg load_q = 0;
reg acc = 0;
integer tile = 0;

reg [1:0]  inst_w; 
reg [bw*row-1:0] D_wmem;
reg [2*bw*row-1:0] D_wmem_2b;
reg [act_bw*row-1:0] D_xmem;
reg [col*psum_bw-1:0] D_pmem;
reg [col*psum_bw-1:0] D_omem;
reg [psum_bw*col-1:0] answer, answer_tile;


reg ofifo_rd;
reg ififo_wr;
reg ififo_rd;
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
wire [act_bw*row-1:0] Q_xmem;
wire [col*psum_bw-1:0] Q_pmem;
wire [col*psum_bw-1:0] Q_omem;
wire [row*bw-1:0] l0_din = load_q ? Q_wmem : Q_xmem; // In the case of cfg_2b==1, Q_wmem is twice the length of Q_xmem, assume design parses Q_Xmem from the last 32 bits of l0_din
reg sfu_write_en;

integer x_file, x_scan_file ; // file_handler
integer w_file, w_scan_file ; // file_handler
integer acc_file, acc_scan_file ; // file_handler
integer out_file, out_scan_file ; // file_handler
integer captured_data; 
integer t, i, j, k, kij, t_i, t_j, k_i, k_j;
integer error;
reg [8*`MAX_LINE:1] line;

integer debug;

wire [col*psum_bw-1:0] ofifo_dout;

core #(
  .bw(bw),
  .psum_bw(psum_bw),
  .col(col),
  .row(row),
  .KERNEL_SIZE(KERNEL_SIZE),
  .IMAGE_SIZE(IMAGE_SIZE),
  .ACT_DEPTH(ACT_DEPTH),
  .WGT_DEPTH(WGT_DEPTH),
  .PSUM_DEPTH(PSUM_DEPTH),
  .OUT_DEPTH(OUT_DEPTH),
  .W_ADDR_W(W_ADDR_W),
  .X_ADDR_W(X_ADDR_W),
  .PSUM_ADDR_W(PSUM_ADDR_W),
  .OUT_ADDR_W(OUT_ADDR_W)
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
  .cfg_2b(cfg_2b) // check port connection
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
  ififo_wr = 0;
  ififo_rd = 0;
  l0_rd    = 0;
  l0_wr    = 0;
  execute  = 0;
  load     = 0;
  acc      = 0;
  sfu_write_en = 0;
  cfg_2b   = 1;

  $dumpfile("core_tb.vcd");
  $dumpvars(0,core_tb);

  x_file = $fopen("../datafiles/data_2b_act.txt", "r");
  if (x_file == 0) begin
    $display("Error opening activation file data_2b_act.txt");
    $finish;
  end
  // Following three lines are to remove the first three comment lines of the file
  x_scan_file = $fgets(line, x_file);
  x_scan_file = $fgets(line, x_file);
  x_scan_file = $fgets(line, x_file);

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
  $display("############ 4w2a: Writing activation data to memory #############");
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
        //$display("Reading activation data for position (%0d, %0d): %b", t_i, t_j, D_xmem);
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

  

  for (tile = 0; tile < 2; tile = tile+1) begin // tile loop
    for (kij=0; kij<len_kij; kij=kij+1) begin  // kij loop
      k_i = kij / KERNEL_SIZE;
      k_j = kij % KERNEL_SIZE;

      case(kij)
      0: w_file_name = tile ? "data_2b_wgt_otile1_kij0.txt" : "data_2b_wgt_otile0_kij0.txt";
      1: w_file_name = tile ? "data_2b_wgt_otile1_kij1.txt" : "data_2b_wgt_otile0_kij1.txt";
      2: w_file_name = tile ? "data_2b_wgt_otile1_kij2.txt" : "data_2b_wgt_otile0_kij2.txt";
      3: w_file_name = tile ? "data_2b_wgt_otile1_kij3.txt" : "data_2b_wgt_otile0_kij3.txt";
      4: w_file_name = tile ? "data_2b_wgt_otile1_kij4.txt" : "data_2b_wgt_otile0_kij4.txt";
      5: w_file_name = tile ? "data_2b_wgt_otile1_kij5.txt" : "data_2b_wgt_otile0_kij5.txt";
      6: w_file_name = tile ? "data_2b_wgt_otile1_kij6.txt" : "data_2b_wgt_otile0_kij6.txt";
      7: w_file_name = tile ? "data_2b_wgt_otile1_kij7.txt" : "data_2b_wgt_otile0_kij7.txt";
      8: w_file_name = tile ? "data_2b_wgt_otile1_kij8.txt" : "data_2b_wgt_otile0_kij8.txt";
      endcase
      
      weight_fullpath = $sformatf("../datafiles/%s", w_file_name);
      w_file = $fopen(weight_fullpath, "r");
      if (w_file == 0) begin
        $display("Error opening weight file %s", w_file_name);
        $finish;
      end
        // Following three lines are to remove the first three comment lines of the file
      w_scan_file = $fgets(line, w_file);
      w_scan_file = $fgets(line, w_file);
      w_scan_file = $fgets(line, w_file);

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





      /////// Kernel data writing to memory ///////
      $display("############ 4w2a: Writing kernel data to memory #############");

      A_wmem = 0;

      for (t=0; t<col; t=t+1) begin  
        #0.5 clk = 1'b0;  
        w_scan_file = $fscanf(w_file,"%64b", D_wmem_2b);
        //$display("Reading weight data for position (%0d, %0d): %b", kij, t, D_wmem_2b);
        WEN_wmem = 0; CEN_wmem = 0; 
        // 14,12,10,8,6,4,2,0
        D_wmem = {D_wmem_2b[ (row*2-2)*bw +: bw ],
                   D_wmem_2b[ (row*2-4)*bw +: bw ],
                   D_wmem_2b[ (row*2-6)*bw +: bw ],
                   D_wmem_2b[ (row*2-8)*bw +: bw ],
                   D_wmem_2b[ (row*2-10)*bw +: bw ],
                   D_wmem_2b[ (row*2-12)*bw +: bw ],
                   D_wmem_2b[ (row*2-14)*bw +: bw ],
                   D_wmem_2b[ (row*2-16)*bw +: bw ]};
        if (t>0) begin
          A_wmem = A_wmem + 1; 
        end
        #0.5 clk = 1'b1;
        #0.5 clk = 1'b0;
        // 15,13,11,9,7,5,3,1
        D_wmem = {D_wmem_2b[ (row*2-1)*bw +: bw ],
                   D_wmem_2b[ (row*2-3)*bw +: bw ],
                   D_wmem_2b[ (row*2-5)*bw +: bw ],
                   D_wmem_2b[ (row*2-7)*bw +: bw ],
                   D_wmem_2b[ (row*2-9)*bw +: bw ],
                   D_wmem_2b[ (row*2-11)*bw +: bw ],
                   D_wmem_2b[ (row*2-13)*bw +: bw ],
                   D_wmem_2b[ (row*2-15)*bw +: bw ]};
        A_wmem = A_wmem + 1; 
        #0.5 clk = 1'b1;
      end

      #0.5 clk = 1'b0;  WEN_wmem = 1;  CEN_wmem = 1; A_wmem = 0;
      #0.5 clk = 1'b1; 
      /////////////////////////////////////



      /////// Kernel data writing to L0 ///////
      // read from wmem into L0 by asserting load=1 and pulsing l0_wr
      // we enable wmem read by setting CEN_wmem=0 & WEN_wmem=1, and step A_wmem
      $display("############ 4w2a: Writing Kernel data to L0 #############"); 
      
      A_wmem = 0;
      load = 1; // selects Q_wmem into l0_din

      for (t=0; t < col * 2 + 1; t=t+1) begin
        #0.5 clk = 1'b0; 
        if (t < col) begin
          CEN_wmem = 0; WEN_wmem = 1; 
        end 
        if (t>0) begin 
          A_wmem = A_wmem + 1; l0_wr = 1;
        end
        #0.5 clk = 1'b1;

        #0.5 clk = 1'b0;
          l0_wr = 0; // avoid coinciding with clock edge
        #0.5 clk = 1'b1;
      end

      // finish wmem read
      #0.5 clk = 1'b0; CEN_wmem = 1; WEN_wmem = 1; A_wmem = 0; load = 0;
      #0.5 clk = 1'b1;
      /////////////////////////////////////



      /////// Kernel loading to PEs ///////
      // set inst_w[0] = 1 for one cycle to tell PEs to load kernel from L0
      $display("############ 4w2a: Loading Kernel data to PEs #############"); 
      for (i=0; i<16 ; i=i+1) begin
        #0.5 clk = 1'b0; 
        l0_rd = 1;
        if (i > 0) inst_w = 2'b01;
        #0.5 clk = 1'b1;
      end
      /////////////////////////////////////


      ////// provide some intermission to clear up the kernel loading ///
      #0.5 clk = 1'b0;  
      #0.5 clk = 1'b1;  
      #0.5 clk = 1'b0;  inst_w = 2'b00;
      #0.5 clk = 1'b1;  
      #0.5 clk = 1'b0;  load = 0; l0_rd = 0; 
      #0.5 clk = 1'b1;  
    

      for (i=0; i<10 ; i=i+1) begin
        #0.5 clk = 1'b0;
        #0.5 clk = 1'b1;  
      end
      /////////////////////////////////////



      /////// Activation data writing to L0 ///////
      // writing into xmem
      CEN_xmem = 0;
      WEN_xmem = 1;
      A_xmem = 0;
      load = 0; // selects Q_xmem into l0_din
      $display("############ 4w2a: Writing Activation data to L0 #############");

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



      /////// Execution ///////
      // assert execute instruction (inst_w[1]) and set execute signal for a while
      // The exact number of cycles required depends on core internals; use a safe window here
      #0.5 clk = 1'b0; l0_rd = 1; // execute asserted
      execute = 1;
      #0.5 clk = 1'b1;

      // hold execute for several cycles to allow computation to progress
      // choose IMAGE_SIZE*IMAGE_SIZE cycles as a conservative window (adjust if needed)
      $display("############ 4w2a: Execution #############"); 
      for (t=0; t<IMAGE_SIZE_O*IMAGE_SIZE_O; t=t+1) begin
        #0.5 clk = 1'b0;
        if (t == 0) begin
          inst_w = 2'b10;
        end 
        if (t == IMAGE_SIZE_O*IMAGE_SIZE_O -1) begin
          l0_rd = 0;
        end
        #0.5 clk = 1'b1;
      end

      // de-assert execute
      #0.5 clk = 1'b0;
        inst_w = 2'b00;
        execute = 0;
      #0.5 clk = 1'b1;
      /////////////////////////////////////



      //////// OFIFO READ ////////
      // Ideally, OFIFO should be read while execution, but we have enough ofifo
      // depth so we can fetch out after execution.
      // Read OFIFO outputs after execution. Pulse ofifo_rd whenever ofifo_valid is asserted.
      // Put a bounded loop so testbench doesn't hang in case of issues.
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
          A_pmem = tile * len_kij * IMAGE_SIZE_O * IMAGE_SIZE_O + (kij * IMAGE_SIZE_O*IMAGE_SIZE_O) + t;
          D_pmem = ofifo_dout;
        #0.5 clk = 1'b1;
      end
      /////////////////////////////////////
    end // end of kij loop

  


    ////////// Accumulation /////////

    error = 0;

    $display("Debug: psum checking...");
    for (kij=0; kij<len_kij; kij=kij+1) begin 
      case(kij)
        0: acc_file_name = "data_2b_psum_kij0.txt";
        1: acc_file_name = "data_2b_psum_kij1.txt";
        2: acc_file_name = "data_2b_psum_kij2.txt";
        3: acc_file_name = "data_2b_psum_kij3.txt";
        4: acc_file_name = "data_2b_psum_kij4.txt";
        5: acc_file_name = "data_2b_psum_kij5.txt";
        6: acc_file_name = "data_2b_psum_kij6.txt";
        7: acc_file_name = "data_2b_psum_kij7.txt";
        8: acc_file_name = "data_2b_psum_kij8.txt";
        default: $error("Invalid kij index");
      endcase

      acc_file = $fopen({"../datafiles/",acc_file_name}, "r");
      // Following three lines are to remove the first three comment lines of the file
      acc_scan_file = $fgets(line, acc_file);
      acc_scan_file = $fgets(line, acc_file);
      acc_scan_file = $fgets(line, acc_file);

      
      for (j=0; j<IMAGE_SIZE_O*IMAGE_SIZE_O+2; j=j+1) begin
        #0.5 clk = 1'b0;
        // Read from psum memory and compare with golden psum
        // addr = kij * IMAGE_SIZE_O * IMAGE_SIZE_O + j
        if (j < IMAGE_SIZE_O*IMAGE_SIZE_O) begin
          CEN_pmem = 0; WEN_pmem = 1; 
          A_pmem = tile * len_kij * IMAGE_SIZE_O * IMAGE_SIZE_O + (kij * IMAGE_SIZE_O*IMAGE_SIZE_O) + j;
        end else begin
          CEN_pmem = 1; WEN_pmem = 1; 
          A_pmem = 0;
        end
        if (j > 1) begin
          if (tile == 0) begin
            acc_scan_file = $fscanf(acc_file,"%128b", answer_tile); // reading from acc file to answer
            acc_scan_file = $fscanf(acc_file,"%128b", answer); // reading from acc file to answer
          end else begin
            acc_scan_file = $fscanf(acc_file,"%128b", answer); // reading from acc file to answer
            acc_scan_file = $fscanf(acc_file,"%128b", answer_tile); // reading from acc file to answer
          end
          if (Q_pmem !== answer) begin
            $display("psum Data ERROR!!"); 
            $display("kij=%0d, j=%0d", kij, j-2);
            $display("psum_q: %32h", Q_pmem);
            $display("answer: %32h", answer); 
            error += 1;
          end
        end
        #0.5 clk = 1'b1;
      end
      $fclose(acc_file);   
    end

    if (error == 0) begin
      $display("############ Psum check passed on tile %d! #############", tile); 
    end else begin
      $display("############ 4w2a: Psum check failed at tile %d with %0d errors #############", tile, error);
      $finish;
    end
  


    $display("############ 4w2a: Verification Start during accumulation #############");
    out_file = $fopen("../datafiles/data_2b_psum_relu.txt", "r");  

    // Following three lines are to remove the first three comment lines of the file
    out_scan_file = $fgets(line, out_file);
    out_scan_file = $fgets(line, out_file);
    out_scan_file = $fgets(line, out_file);

    for (i=0; i<IMAGE_SIZE_O*IMAGE_SIZE_O; i=i+1) begin 

      #0.5 clk = 1'b0; 
      #0.5 clk = 1'b1;

      for (kij = 0; kij < len_kij + 2; kij = kij + 1) begin
        // enable accumulation in SFU
        #0.5 clk = 1'b0; 
        if (kij > 1) begin
          acc = 1;
        end else begin
          acc = 0;
        end
        // set up psum memory read
        if (kij < len_kij) begin
          CEN_pmem = 0; WEN_pmem = 1; 
          A_pmem = tile * len_kij * IMAGE_SIZE_O * IMAGE_SIZE_O + (kij * IMAGE_SIZE_O*IMAGE_SIZE_O) + i;
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
      // Write SFP out to output memory
      CEN_omem = 0; WEN_omem = 0;
      A_omem = IMAGE_SIZE_O*IMAGE_SIZE_O * tile + i;
      D_omem = sfp_out;

      if (tile == 0) begin
        out_scan_file = $fscanf(out_file,"%128b", answer_tile); // reading from acc file to answer
        out_scan_file = $fscanf(out_file,"%128b", answer); // reading from acc file to answer
      end else begin
        out_scan_file = $fscanf(out_file,"%128b", answer); // reading from acc file to answer
        out_scan_file = $fscanf(out_file,"%128b", answer_tile); // reading from acc file to answer
      end
      if (sfp_out === answer)
        $display("%2d-th output featuremap Data matched! :D", i); 
      else begin
        $display("%2d-th output featuremap Data ERROR in 2bit activation config!!", i); 
        $display("sfpout: %4h %4h %4h %4h %4h %4h %4h %4h", sfp_out[127:112], sfp_out[111:96], sfp_out[95:80], sfp_out[79:64], sfp_out[63:48], sfp_out[47:32], sfp_out[31:16], sfp_out[15:0]);
        $display("answer: %4h %4h %4h %4h %4h %4h %4h %4h", answer[127:112], answer[111:96], answer[95:80], answer[79:64], answer[63:48], answer[47:32], answer[31:16], answer[15:0]);
        error = error + 1;
      end
      #0.5 clk = 1'b1;

      #0.5 clk = 1'b0;
      // Disable output memory write
      CEN_omem = 1; WEN_omem = 1;
      #0.5 clk = 1'b1;
    end
    $fclose(out_file);
  end  // end of tile loop


  if (error == 0) begin
  	$display("############ No error detected in 2bit activation config ##############"); 
  end else begin
    $display("############ 4w2a: Verification failed at SFP with %0d errors #############", error);
    $finish;
  end

  
  //////////////////////////////////

  for (t=0; t<10; t=t+1) begin  
    #0.5 clk = 1'b0;  
    #0.5 clk = 1'b1;  
  end

  /////////////////////////////////
  // ################ 4bit activation verification begin #################
  ////////////////////////////////

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
  ififo_wr = 0;
  ififo_rd = 0;
  l0_rd    = 0;
  l0_wr    = 0;
  execute  = 0;
  load     = 0;
  acc      = 0;
  sfu_write_en = 0;
  cfg_2b   = 0;


  x_file = $fopen("../datafiles/data_4b_act.txt", "r");
  // Following three lines are to remove the first three comment lines of the file
  x_scan_file = $fgets(line, x_file);
  x_scan_file = $fgets(line, x_file);
  x_scan_file = $fgets(line, x_file);

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
  $display("############ 4w4a: Writing activation data to memory #############");
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


  for (kij=0; kij<len_kij; kij=kij+1) begin  // kij loop
    k_i = kij / KERNEL_SIZE;
    k_j = kij % KERNEL_SIZE;

    case(kij)
     0: w_file_name = "data_4b_wgt_otile0_kij0.txt";
     1: w_file_name = "data_4b_wgt_otile0_kij1.txt";
     2: w_file_name = "data_4b_wgt_otile0_kij2.txt";
     3: w_file_name = "data_4b_wgt_otile0_kij3.txt";
     4: w_file_name = "data_4b_wgt_otile0_kij4.txt";
     5: w_file_name = "data_4b_wgt_otile0_kij5.txt";
     6: w_file_name = "data_4b_wgt_otile0_kij6.txt";
     7: w_file_name = "data_4b_wgt_otile0_kij7.txt";
     8: w_file_name = "data_4b_wgt_otile0_kij8.txt";
    endcase
    

    w_file = $fopen({"../datafiles/",w_file_name}, "r");
    if (w_file == 0) begin
      $display("Error opening weight file %s", w_file_name);
      $finish;
    end
    // Following three lines are to remove the first three comment lines of the file
    w_scan_file = $fgets(line, w_file);
    w_scan_file = $fgets(line, w_file);
    w_scan_file = $fgets(line, w_file);

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





    /////// Kernel data writing to memory ///////
    $display("############ 4w4a: Writing kernel data to memory #############");

    A_wmem = 0;

    for (t=0; t<col; t=t+1) begin  
      #0.5 clk = 1'b0;  w_scan_file = $fscanf(w_file,"%32b", D_wmem); WEN_wmem = 0; CEN_wmem = 0; if (t>0) A_wmem = A_wmem + 1; 
      #0.5 clk = 1'b1;  
    end

    #0.5 clk = 1'b0;  WEN_wmem = 1;  CEN_wmem = 1; A_wmem = 0;
    #0.5 clk = 1'b1; 
    /////////////////////////////////////



    /////// Kernel data writing to L0 ///////
    // read from wmem into L0 by asserting load=1 and pulsing l0_wr
    // we enable wmem read by setting CEN_wmem=0 & WEN_wmem=1, and step A_wmem
    $display("############ 4w4a: Writing Kernel data to L0 #############"); 
    
    A_wmem = 0;
    load = 1; // selects Q_wmem into l0_din

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
        l0_wr = 0; // avoid coinciding with clock edge
      #0.5 clk = 1'b1;
    end

    // finish wmem read
    #0.5 clk = 1'b0; CEN_wmem = 1; WEN_wmem = 1; A_wmem = 0; load = 0;
    #0.5 clk = 1'b1;
    /////////////////////////////////////



    /////// Kernel loading to PEs ///////
    // set inst_w[0] = 1 for one cycle to tell PEs to load kernel from L0
    $display("############ 4w4a: Loading Kernel data to PEs #############"); 
    for (i=0; i<8 ; i=i+1) begin
      #0.5 clk = 1'b0; 
      l0_rd = 1; // kernel-loading instruction asserted
      if (i > 0) inst_w = 2'b01;
      #0.5 clk = 1'b1;
    end
    for (i=0; i<8 ; i=i+1) begin
      #0.5 clk = 1'b0;
      if (i > 0) inst_w = 2'b00;
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
    // writing into xmem
    CEN_xmem = 0;
    WEN_xmem = 1;
    A_xmem = 0;
    load = 0; // selects Q_xmem into l0_din
    $display("############ 4w4a: Writing Activation data to L0 #############");

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



    /////// Execution ///////
    // assert execute instruction (inst_w[1]) and set execute signal for a while
    // The exact number of cycles required depends on core internals; use a safe window here
    #0.5 clk = 1'b0; l0_rd = 1; // execute asserted
    execute = 1;
    #0.5 clk = 1'b1;

    // hold execute for several cycles to allow computation to progress
    // choose IMAGE_SIZE*IMAGE_SIZE cycles as a conservative window (adjust if needed)
    $display("############ 4w4a: Execution #############"); 
    for (t=0; t<IMAGE_SIZE_O*IMAGE_SIZE_O; t=t+1) begin
      #0.5 clk = 1'b0;
      if (t == 0) begin
        inst_w = 2'b10;
      end 
      if (t == IMAGE_SIZE_O*IMAGE_SIZE_O -1) begin
        l0_rd = 0;
      end
      #0.5 clk = 1'b1;
    end

    // de-assert execute
    #0.5 clk = 1'b0;
      inst_w = 2'b00;
      execute = 0;
    #0.5 clk = 1'b1;
    /////////////////////////////////////



    //////// OFIFO READ ////////
    // Ideally, OFIFO should be read while execution, but we have enough ofifo
    // depth so we can fetch out after execution.
    // Read OFIFO outputs after execution. Pulse ofifo_rd whenever ofifo_valid is asserted.
    // Put a bounded loop so testbench doesn't hang in case of issues.
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
    /////////////////////////////////////


  end  // end of kij loop


  ////////// Accumulation /////////
  

  error = 0;

  $display("Debug: psum checking...");
  for (kij=0; kij<len_kij; kij=kij+1) begin 
    case(kij)
      0: acc_file_name = "data_4b_psum_kij0.txt";
      1: acc_file_name = "data_4b_psum_kij1.txt";
      2: acc_file_name = "data_4b_psum_kij2.txt";
      3: acc_file_name = "data_4b_psum_kij3.txt";
      4: acc_file_name = "data_4b_psum_kij4.txt";
      5: acc_file_name = "data_4b_psum_kij5.txt";
      6: acc_file_name = "data_4b_psum_kij6.txt";
      7: acc_file_name = "data_4b_psum_kij7.txt";
      8: acc_file_name = "data_4b_psum_kij8.txt";
      default: $error("Invalid kij index");
    endcase

    acc_file = $fopen({"../datafiles/",cc_file_name}, "r");
    // Following three lines are to remove the first three comment lines of the file
    acc_scan_file = $fgets(line, acc_file);
    acc_scan_file = $fgets(line, acc_file);
    acc_scan_file = $fgets(line, acc_file);

    
    for (j=0; j<IMAGE_SIZE_O*IMAGE_SIZE_O+2; j=j+1) begin
      #0.5 clk = 1'b0;
      // Read from psum memory and compare with golden psum
      // addr = kij * IMAGE_SIZE_O * IMAGE_SIZE_O + j
      if (j < IMAGE_SIZE_O*IMAGE_SIZE_O) begin
        CEN_pmem = 0; WEN_pmem = 1; 
        A_pmem = (kij * IMAGE_SIZE_O*IMAGE_SIZE_O) + j;
      end else begin
        CEN_pmem = 1; WEN_pmem = 1; 
        A_pmem = 0;
      end
      if (j > 1) begin
        acc_scan_file = $fscanf(acc_file,"%128b", answer); // reading from acc file to answer
        if (Q_pmem !== answer) begin
          $display("psum Data ERROR!!"); 
          $display("kij=%0d, j=%0d", kij, j-1);
          $display("psum_q: %16h", Q_pmem);
          $display("answer: %16h", answer); 
          error += 1;
        end
      end
      #0.5 clk = 1'b1;
    end
    $fclose(acc_file);   
  end

  if (error == 0) begin
    $display("############ 4bit activation Psum check passed! #############"); 
  end else begin
    $display("############ 4w4a: Psum check failed with %0d errors #############", error); 
    $finish;
  end


  $display("############ 4w4a: Verification Start during accumulation #############"); 
  out_file = $fopen("../datafiles/data_4b_psum_relu.txt", "r");  

  // Following three lines are to remove the first three comment lines of the file
  out_scan_file = $fgets(line, out_file);
  out_scan_file = $fgets(line, out_file);
  out_scan_file = $fgets(line, out_file);

  for (i=0; i<IMAGE_SIZE_O*IMAGE_SIZE_O; i=i+1) begin 

    #0.5 clk = 1'b0; 
    #0.5 clk = 1'b1;

    for (kij = 0; kij < len_kij + 2; kij = kij + 1) begin
      // enable accumulation in SFU
      #0.5 clk = 1'b0; 
      if (kij > 1) begin
        acc = 1;
      end else begin
        acc = 0;
      end
      // set up psum memory read
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
    // Write SFP out to output memory
    CEN_omem = 0; WEN_omem = 0;
    A_omem = i;
    D_omem = sfp_out;

    out_scan_file = $fscanf(out_file,"%128b", answer); // reading from out file to answer
    if (sfp_out === answer)
      $display("%2d-th output featuremap Data matched! :D", i); 
    else begin
      $display("%2d-th output featuremap Data ERROR in 4bit activation config!!", i); 
      $display("sfpout: %4h %4h %4h %4h %4h %4h %4h %4h", sfp_out[127:112], sfp_out[111:96], sfp_out[95:80], sfp_out[79:64], sfp_out[63:48], sfp_out[47:32], sfp_out[31:16], sfp_out[15:0]);
      $display("answer: %4h %4h %4h %4h %4h %4h %4h %4h", answer[127:112], answer[111:96], answer[95:80], answer[79:64], answer[63:48], answer[47:32], answer[31:16], answer[15:0]);
      error = 1;
    end
    #0.5 clk = 1'b1;

    #0.5 clk = 1'b0;
    // Disable output memory write
    CEN_omem = 1; WEN_omem = 1;
    #0.5 clk = 1'b1;
  end


  if (error == 0) begin
  	$display("############ No error detected in 4bit activation config ##############"); 
  	$display("########### Project Completed !! ############"); 

  end

  
  //////////////////////////////////

  for (t=0; t<10; t=t+1) begin  
    #0.5 clk = 1'b0;  
    #0.5 clk = 1'b1;  
  end

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
