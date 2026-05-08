`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2021/05/27 20:16:58
// Design Name: 
// Module Name: fmcadda_9250_9144_top
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////
module top (   
        input refclk_p, //GTX参考时钟 ref clk = 125M
        input refclk_n,
        input glblclk_p, ////jesd204b参考时钟 = lane_rate / 40 = 125MHz 
        input glblclk_n,
        input sysref_p,
        input sysref_n, 
        output o_rx_sync_p,
        output o_rx_sync_n,

        input adc_rxp_a0,
        input adc_rxn_a0,
        input adc_rxp_a1,
        input adc_rxn_a1,

        input i_tx_sync_p,
        input i_tx_sync_n,
        output dac_txp_d0,
        output dac_txp_d1,
        output dac_txp_d2,
        output dac_txp_d3,
//        output dac_txp_d4,
//        output dac_txp_d5,
//        output dac_txp_d6,
//        output dac_txp_d7,
        output dac_txn_d0,
        output dac_txn_d1,
        output dac_txn_d2,
        output dac_txn_d3,
//        output dac_txn_d4,
//        output dac_txn_d5,
//        output dac_txn_d6,
//        output dac_txn_d7,
        
        inout ads_sda, //adc spi引脚
        output ads_sclk,
        output ads_sen_n,
        output ads_rstn,
        
        inout  das_sda, //dac spi引脚
        output das_sclk,
        output das_sen_n,
        output das_rstn,
        output das_txen0,
        output das_txen1,
                
        inout lmk_sda, //lmk04828 spi引脚
        output  lmk_sclk,
        output  lmk_cs_n,
        output  lmk_rst,
        input key0,
        input key1,
        output [1:0] led
`ifdef AWG_UART_CONTROL
        ,
        input uart_rxd,
        output uart_txd
`endif
        //output  trig_io_free
      );
   wire sys_clk, sys_clk_bufg;
   wire clk_25m;
   wire clk_ila_250m;
   wire clk_axi_100m;
   wire w_rst_n, w_rst2_n;
   wire EOS_n;
   wire mmcm_locked;
   // 使用STARTUPE原语提供的fpga片上振荡器时钟，对于ultra+系列，CFGMCLK时钟为50M，对于7series系列，CFGMCLK时钟为65M
   // 此处使用fpga片上振荡器是仅仅为了方便demo演示，避免形形色色的客户板卡上的晶振各不相同，造成移植测试负担
   STARTUPE2 #(
      .PROG_USR("FALSE"),  // Activate program event security feature. Requires encrypted bitstreams.
      .SIM_CCLK_FREQ(0.0)  // Set the Configuration Clock Frequency(ns) for simulation.
   )
   STARTUPE2_inst (
      .CFGMCLK(sys_clk),     // 1-bit output: Configuration internal oscillator clock output
      .EOS(EOS_n),             // 1-bit output: Active high output signal indicating the End Of Startup.
      .USRCCLKO(1'b0),   // 1-bit input: User CCLK input
                             // For Zynq-7000 devices, this input must be tied to GND
      .USRCCLKTS(1'b1) // 1-bit input: User CCLK 3-state enable input
                             // For Zynq-7000 devices, this input must be tied to VCC
   );
   BUFG BUFG_inst (
      .O(sys_clk_bufg), // 1-bit output: Clock output
      .I(sys_clk)  // 1-bit input: Clock input
   );
   // 全局复位模块
   rst_module rst_module_inst(
						.i_sys_clk      (clk_25m),
						.i_sys_rst_async (EOS_n),
						.o_mod1_rstn (w_rst_n),
						.o_mod2_rstn ()
    );

  // 异步时钟产生，产生SPI时钟和AXI配置时钟
  clk_sys_mmcm clk_sys_mmcm_inst
   (
    .clk_out1(clk_25m),     // output clk_out1 25M for other
    .clk_out2(clk_axi_100m),     // output clk_out3 100M for jesd204_AXI
    .locked(mmcm_locked),       // output locked
    .clk_in1(sys_clk_bufg));      // input clk_in1      
    

reg lmk_datain_valid;
wire lmk_datain_ready;
reg ads_datain_valid;
wire ads_datain_ready;
reg das_datain_valid;
wire das_datain_ready;

// 各个设备SPI控制模块，采用仿AXI的握手机制，顺序依次控制初始化
lmk_spi_wr_config lmk_spi_wr_config_inst(
                        .clk_in(clk_25m),
                        .rst_n(w_rst_n),
                        
                        .o_sclk(lmk_sclk),
                        .io_sda(lmk_sda),
                        .o_cs_n(lmk_cs_n),
                        .o_lmk_rst(lmk_rst),
                        .datain_valid(lmk_datain_valid),
                        .datain_ready(lmk_datain_ready)
                        );           
ad9250_spi_config ad9250_spi_config_inst(
                        .clk_in(clk_25m),
                        .rst_n(w_rst_n),
                        
                        .o_sclk(ads_sclk),
                        .io_sda(ads_sda),
                        .o_sen_n(ads_sen_n),
                        .o_reset(ads_rstn),
                        .datain_valid(ads_datain_valid),
                        .datain_ready(ads_datain_ready)
                        );    
ad9144_spi_config ad9144_spi_config_inst(
                        .clk_in(clk_25m),
                        .rst_n(w_rst_n),
                        
                        .o_sclk(das_sclk),
                        .io_sda(das_sda),
                        .o_sen_n(das_sen_n),
                        .o_reset(das_rstn),
                        .datain_valid(das_datain_valid),
                        .datain_ready(das_datain_ready)
                        );                         

assign das_txen0 = 1'b1;
assign das_txen1 = 1'b1;
reg init_done;
wire rx_core_clk_out;   
wire[63:0] w_rx_tdata;
wire w_rx_tvalid;
wire[3:0] w_rx_start_of_frame, w_rx_end_of_frame;
wire[3:0] w_rx_start_of_multiframe, w_rx_end_of_multiframe;
wire[7:0] w_rx_frame_error;
wire[3:0] w_tx_start_of_multiframe, w_tx_start_of_frame;
wire[127:0] w_tx_tdata;
wire w_tx_tready;
wire w_tx_aresetn;

wire w_common0_qpll_lock_out;
wire w_rx_sync;
wire w_tx_sync;
wire w_sysref;
wire w_rx_core_clk, w_tx_core_clk;
      IBUFDS  IBUFDS_inst2 (
      .O(w_sysref),  // Buffer output
      .I(sysref_p),  // Diff_p buffer input (connect directly to top-level port)
      .IB(sysref_n) // Diff_n buffer input (connect directly to top-level port)
   );
wire w_qpll_refclk; 
wire w_tx_reset_gt, w_rx_reset_gt;
wire w_tx_sys_reset, w_rx_sys_reset;
reg r_jesd_tx_sys_reset, r_jesd_rx_sys_reset;
wire w_jesd_tx_sys_reset_vio, w_jesd_rx_sys_reset_vio;
assign w_tx_sys_reset = r_jesd_tx_sys_reset | w_jesd_tx_sys_reset_vio;
assign w_rx_sys_reset = r_jesd_rx_sys_reset | w_jesd_rx_sys_reset_vio;
wire w_rx_axi_ena;
// vio调试ip核观察，默认可不使用
vio_for_jesd_rst vio_for_jesd_rst_debug (
  .clk(clk_axi_100m),                // input wire clk
  .probe_out0(w_jesd_tx_sys_reset_vio),  // output wire [0 : 0] probe_out0
  .probe_out1(w_jesd_rx_sys_reset_vio),  // output wire [0 : 0] probe_out1
  .probe_out2(w_rx_axi_ena)  // output wire [0 : 0] probe_out1
);
wire w_rxencommaalign_out;
wire w_tx_reset_done, w_rx_reset_done;
wire[3:0] w_gt_prbssel;
wire[31:0] gt0_txdata, gt1_txdata, gt2_txdata, gt3_txdata;
wire[3:0] gt0_txcharisk, gt1_txcharisk,gt2_txcharisk, gt3_txcharisk;
wire[31:0] gt0_rxdata, gt1_rxdata;
wire[3:0] gt0_rxcharisk, gt1_rxcharisk;
wire[3:0] gt0_rxdisperr, gt1_rxdisperr;
wire[3:0] gt0_rxnotintable, gt1_rxnotintable;
wire[15:0] w_dds_tdata;
wire w_tx_s_axi_awready;
wire w_tx_s_axi_wready;
wire w_tx_s_axi_bvalid;
wire[1:0] w_tx_s_axi_bresp;
wire[11:0] w_tx_s_axi_awaddr;
wire w_tx_s_axi_awvalid;
wire[31:0] w_tx_s_axi_wdata;
wire w_tx_s_axi_wvalid;
wire w_tx_s_axi_bready;
wire w_tx_axi_write_done;
reg w_tx_axi_ena;

wire w_rx_s_axi_arready ;
wire w_rx_s_axi_rvalid  ;
wire[1:0] w_rx_s_axi_rresp   ;
wire[11:0] w_rx_s_axi_araddr  ;
wire w_rx_s_axi_arvalid ;
wire[31:0] w_rx_s_axi_rdata   ;
wire w_rx_s_axi_rready  ;

jesd_axi_write jesd_axi_write_for_tx(
    .s_axi_aclk      (clk_axi_100m)   ,   //时钟
    .s_axi_aresetn   (w_rst_n & w_tx_axi_ena),   //低电平复位
    .s_axi_awready   (w_tx_s_axi_awready),   //写入地址就绪
    .s_axi_wready    (w_tx_s_axi_wready),   //写入数据就绪
    .s_axi_bvalid    (w_tx_s_axi_bvalid),   //写入响应有效
    .s_axi_bresp     (w_tx_s_axi_bresp),   //写入响应
    .s_axi_awaddr    (w_tx_s_axi_awaddr),   //写入地址
    .s_axi_awvalid   (w_tx_s_axi_awvalid),   //写入地址有效
    .s_axi_wdata     (w_tx_s_axi_wdata),   //写入数据
    .s_axi_wvalid    (w_tx_s_axi_wvalid),   //写入数据有效
    .s_axi_bready    (w_tx_s_axi_bready),      //写入数据就绪
    .axi_write_done  ()    //数据全部写入
    );
jesd_axi_read jesd_axi_read_for_rx(
    .s_axi_aclk      (clk_axi_100m)   ,   //时钟
    .s_axi_aresetn   (w_rst_n & w_rx_axi_ena),   //低电平复位
    .s_axi_arready   (w_rx_s_axi_arready),   //读地址就绪
    .s_axi_rvalid    (w_rx_s_axi_rvalid ),   //读数据有效
    .s_axi_rresp     (w_rx_s_axi_rresp  ),   //读响应
    .s_axi_araddr    (w_rx_s_axi_araddr ),   //读地址
    .s_axi_arvalid   (w_rx_s_axi_arvalid),   //读地址有效
    .s_axi_rdata     (w_rx_s_axi_rdata  ),   //读数据
    .s_axi_rready    (w_rx_s_axi_rready )      //读数据就绪
    );          
   IBUFDS_GTE2 #(
      .CLKCM_CFG("TRUE"),   // Refer to Transceiver User Guide
      .CLKRCV_TRST("TRUE"), // Refer to Transceiver User Guide
      .CLKSWING_CFG(2'b11)  // Refer to Transceiver User Guide
   )
   IBUFDS_GTE2_inst (
      .O(w_qpll_refclk),         // 1-bit output: Refer to Transceiver User Guide
      .ODIV2(), // 1-bit output: Refer to Transceiver User Guide
      .CEB(1'b0),     // 1-bit input: Refer to Transceiver User Guide
      .I(refclk_p),         // 1-bit input: Refer to Transceiver User Guide
      .IB(refclk_n)        // 1-bit input: Refer to Transceiver User Guide
   );
   wire w_glblclk, w_glblclk_glb;
   wire w_glbclk_mmcm_locked;
     clk_for_glbclk clk_for_glbclk_inst
   (
    // Clock out ports
    .clk_out1(w_rx_core_clk),     // output clk_out1
    .clk_out2(w_tx_core_clk),     // output clk_out2
    .resetn(w_rst_n), // input resetn
    .locked(w_glbclk_mmcm_locked),       // output locked
   // Clock in ports
    .clk_in1_p(glblclk_p),    // input clk_in1_p
    .clk_in1_n(glblclk_n));    // input clk_in1_n

wire signed [15:0] awg_sample0, awg_sample1, awg_sample2, awg_sample3;
wire [11:0] awg_phase_addr0, awg_phase_addr1, awg_phase_addr2, awg_phase_addr3;
wire awg_sample_valid;
wire [127:0] awg_tx_tdata;
// 例化4个相同的ROM，通过地址错位读取，合并成一路信号给JESD204b的数据端口
// 4路DAC将输出相同的波形信号
reg key0_d, key0_dd, key0_stable, key0_stable_prev;
reg key1_d, key1_dd, key1_stable, key1_stable_prev;
reg[31:0] key0_cnt, key1_cnt, chord_cnt;
reg combo_seen, chord_latched;
reg[1:0] ui_mode;
reg[1:0] wave_sel;
reg[2:0] freq_sel, amp_sel, phase_sel;

localparam [31:0] KEY_DEBOUNCE_TICKS = 32'd5_000_000;
localparam [31:0] KEY_CHORD_TICKS    = 32'd62_500_000;

wire key0_release = !key0_stable_prev && key0_stable;
wire key1_release = !key1_stable_prev && key1_stable;
wire both_down    = !key0_stable && !key1_stable;

function [47:0] phase_inc_from_sel;
    input [2:0] sel;
    begin
        case (sel)
            3'd0: phase_inc_from_sel = 48'h028F5C28F5C3;
            3'd1: phase_inc_from_sel = 48'h051EB851EB85;
            3'd2: phase_inc_from_sel = 48'h07AE147AE148;
            3'd3: phase_inc_from_sel = 48'h0A3D70A3D70A;
            3'd4: phase_inc_from_sel = 48'h0CCCCCCCCCCD;
            3'd5: phase_inc_from_sel = 48'h147AE147AE14;
            3'd6: phase_inc_from_sel = 48'h19999999999A;
            default: phase_inc_from_sel = 48'h0CCCCCCCCCCD;
        endcase
    end
endfunction

function [15:0] amp_from_sel;
    input [2:0] sel;
    begin
        case (sel)
            3'd0: amp_from_sel = 16'h1000;
            3'd1: amp_from_sel = 16'h2000;
            3'd2: amp_from_sel = 16'h4000;
            3'd3: amp_from_sel = 16'h6000;
            3'd4: amp_from_sel = 16'h7fff;
            default: amp_from_sel = 16'h6000;
        endcase
    end
endfunction

function [47:0] phase_offset_from_sel;
    input [2:0] sel;
    begin
        case (sel)
            3'd0: phase_offset_from_sel = 48'h000000000000;
            3'd1: phase_offset_from_sel = 48'h200000000000;
            3'd2: phase_offset_from_sel = 48'h400000000000;
            3'd3: phase_offset_from_sel = 48'h800000000000;
            3'd4: phase_offset_from_sel = 48'hC00000000000;
            default: phase_offset_from_sel = 48'h000000000000;
        endcase
    end
endfunction

wire [47:0] key_phase_inc    = phase_inc_from_sel(freq_sel);
wire [15:0] key_amp_q15      = amp_from_sel(amp_sel);
wire [47:0] key_phase_offset = phase_offset_from_sel(phase_sel);
wire [1:0]  key_wave_mode    = wave_sel;

wire        awg_reg_output_enable;
wire        awg_reg_use_control;
wire [47:0] awg_reg_phase_inc;
wire [47:0] awg_reg_phase_offset;
wire [15:0] awg_reg_amplitude_q15;
wire signed [15:0] awg_reg_offset;
wire [1:0]  awg_reg_wave_mode;
wire        awg_reg_update_toggle;
wire [31:0] awg_reg_read_data;
wire        awg_cfg_wr_en;
wire        awg_cfg_rd_en;
wire [7:0]  awg_cfg_addr;
wire [31:0] awg_cfg_wdata;

// Calibration interface wires
wire [1:0]  awg_reg_range_sel;
wire        awg_reg_output_en;
wire        awg_reg_cal_enable;
wire        awg_reg_cal_wr_en;
wire [3:0]  awg_reg_cal_wr_addr;
wire [31:0] awg_reg_cal_wr_data;
wire        awg_reg_cal_rd_en;
wire [3:0]  awg_reg_cal_rd_addr;
wire [31:0] awg_reg_cal_rd_data;
wire [15:0] awg_cal_amplitude_q15;

`ifdef AWG_UART_CONTROL
wire awg_uart_activity;

ad9144_uart_reg_bridge #(
    .CLK_HZ(250000000),
    .BAUD(115200)
) u_ad9144_uart_reg_bridge (
    .clk             (w_tx_core_clk),
    .rst_n           (w_rst_n),
    .uart_rxd        (uart_rxd),
    .uart_txd        (uart_txd),
    .cfg_wr_en       (awg_cfg_wr_en),
    .cfg_rd_en       (awg_cfg_rd_en),
    .cfg_addr        (awg_cfg_addr),
    .cfg_wdata       (awg_cfg_wdata),
    .cfg_rdata       (awg_reg_read_data),
    .activity_toggle (awg_uart_activity)
);
`else
assign awg_cfg_wr_en = 1'b0;
assign awg_cfg_rd_en = 1'b0;
assign awg_cfg_addr  = 8'd0;
assign awg_cfg_wdata = 32'd0;
`endif

ad9144_awg_reg_bank u_ad9144_awg_reg_bank (
    .clk              (w_tx_core_clk),
    .rst_n            (w_rst_n),
    .cfg_wr_en        (awg_cfg_wr_en),
    .cfg_addr         (awg_cfg_addr),
    .cfg_wdata        (awg_cfg_wdata),
    .cfg_rd_en        (awg_cfg_rd_en),
    .cfg_rdata        (awg_reg_read_data),
    .output_enable    (awg_reg_output_enable),
    .use_reg_control  (awg_reg_use_control),
    .phase_inc        (awg_reg_phase_inc),
    .phase_offset     (awg_reg_phase_offset),
    .amplitude_q15    (awg_reg_amplitude_q15),
    .offset           (awg_reg_offset),
    .wave_mode        (awg_reg_wave_mode),
    .update_toggle    (awg_reg_update_toggle),
    .button_ui_mode   (ui_mode),
    .button_freq_sel  (freq_sel),
    .button_amp_sel   (amp_sel),
    .button_phase_sel (phase_sel),
    .button_wave_sel  (wave_sel),
    .tx_ready         (w_tx_tready),
    .tx_sync          (w_tx_sync),
    .sysref_seen      (w_sysref),
    .sample_valid     (awg_sample_valid),
    // Calibration/range control outputs
    .range_sel        (awg_reg_range_sel),
    .output_en        (awg_reg_output_en),
    .cal_enable       (awg_reg_cal_enable),
    .cal_wr_en        (awg_reg_cal_wr_en),
    .cal_wr_addr      (awg_reg_cal_wr_addr),
    .cal_wr_data      (awg_reg_cal_wr_data),
    .cal_rd_en        (awg_reg_cal_rd_en),
    .cal_rd_addr      (awg_reg_cal_rd_addr),
    .cal_rd_data      (awg_reg_cal_rd_data)
);

// Digital calibration module: applies freq-dependent gain/offset compensation
ad9144_awg_cal u_ad9144_awg_cal (
    .clk               (w_tx_core_clk),
    .rst_n             (w_rst_n),
    .cal_enable        (awg_reg_cal_enable),
    .range_sel         (awg_reg_range_sel),
    .phase_inc         (awg_reg_use_control ? awg_reg_phase_inc : key_phase_inc),
    .amplitude_q15_in  (awg_reg_amplitude_q15),
    .amplitude_q15_out (awg_cal_amplitude_q15),
    .cal_wr_en         (awg_reg_cal_wr_en),
    .cal_wr_addr       (awg_reg_cal_wr_addr),
    .cal_wr_data       (awg_reg_cal_wr_data),
    .cal_rd_en         (awg_reg_cal_rd_en),
    .cal_rd_addr       (awg_reg_cal_rd_addr),
    .cal_rd_data       (awg_reg_cal_rd_data)
);

wire [47:0] phase_inc    = awg_reg_use_control ? awg_reg_phase_inc : key_phase_inc;
wire [15:0] amp_q15      = awg_reg_use_control ? awg_cal_amplitude_q15 : key_amp_q15;
wire [47:0] phase_offset = awg_reg_use_control ? awg_reg_phase_offset : key_phase_offset;
wire [1:0]  wave_mode    = awg_reg_use_control ? awg_reg_wave_mode : key_wave_mode;
wire signed [15:0] awg_offset = awg_reg_use_control ? awg_reg_offset : 16'sd0;

(* keep = "true", mark_debug = "true" *) wire [63:0] awg_debug_ctrl = {
    8'hA5,
    w_common0_qpll_lock_out,
    w_tx_reset_done,
    w_tx_tready,
    w_tx_sync,
    w_sysref,
    awg_sample_valid,
    awg_reg_output_enable,
    awg_reg_use_control,
    2'b00, ui_mode,
    2'b00, wave_sel,
    1'b0,  freq_sel,
    1'b0,  amp_sel,
    1'b0,  phase_sel,
    key0_stable,
    key1_stable,
    key0_release,
    key1_release,
    awg_phase_addr0,
    awg_phase_addr1
};
(* keep = "true", mark_debug = "true" *) wire [63:0] awg_debug_samples = {awg_sample3, awg_sample2, awg_sample1, awg_sample0};
(* keep = "true", mark_debug = "true" *) wire [63:0] awg_debug_tdata_lo = w_tx_tdata[63:0];
(* keep = "true", mark_debug = "true" *) wire [63:0] awg_debug_tdata_hi = w_tx_tdata[127:64];
(* keep = "true", mark_debug = "true" *) wire [63:0] awg_debug_phase_inc = {16'd0, phase_inc};
(* keep = "true", mark_debug = "true" *) wire [63:0] awg_debug_phase_offset = {16'd0, phase_offset};

ad9144_awg_dds4 u_ad9144_awg_dds4 (
    .clk           (w_tx_core_clk),
    .rst_n         (w_rst_n),
    .phase_inc     (phase_inc),
    .phase_offset  (phase_offset),
    .wave_mode     (wave_mode),
    .amplitude_q15 (amp_q15),
    .offset        (awg_offset),
    .sample0       (awg_sample0),
    .sample1       (awg_sample1),
    .sample2       (awg_sample2),
    .sample3       (awg_sample3),
    .phase_addr0   (awg_phase_addr0),
    .phase_addr1   (awg_phase_addr1),
    .phase_addr2   (awg_phase_addr2),
    .phase_addr3   (awg_phase_addr3),
    .sample_valid  (awg_sample_valid)
);

ad9144_sample_packer u_ad9144_sample_packer (
    .sample0 (awg_sample0),
    .sample1 (awg_sample1),
    .sample2 (awg_sample2),
    .sample3 (awg_sample3),
    .tx_tdata(awg_tx_tdata)
);

assign w_tx_tdata = awg_reg_output_enable ? awg_tx_tdata : 128'd0;

always@ (posedge w_tx_core_clk or negedge w_rst_n) begin
    if(~w_rst_n) begin
        key0_d           <= 1'b1;
        key0_dd          <= 1'b1;
        key0_stable      <= 1'b1;
        key0_stable_prev <= 1'b1;
        key1_d           <= 1'b1;
        key1_dd          <= 1'b1;
        key1_stable      <= 1'b1;
        key1_stable_prev <= 1'b1;
        key0_cnt         <= 32'd0;
        key1_cnt         <= 32'd0;
        chord_cnt        <= 32'd0;
        combo_seen       <= 1'b0;
        chord_latched    <= 1'b0;
        ui_mode          <= 2'd1;
        wave_sel         <= 2'd0;
        freq_sel         <= 3'd4;
        amp_sel          <= 3'd3;
        phase_sel        <= 3'd0;
    end else begin
        key0_d  <= key0;
        key0_dd <= key0_d;
        key1_d  <= key1;
        key1_dd <= key1_d;

        if(key0_d != key0_dd)
            key0_cnt <= 32'd0;
        else if(key0_cnt < KEY_DEBOUNCE_TICKS)
            key0_cnt <= key0_cnt + 1'b1;
        else
            key0_stable <= key0_dd;

        if(key1_d != key1_dd)
            key1_cnt <= 32'd0;
        else if(key1_cnt < KEY_DEBOUNCE_TICKS)
            key1_cnt <= key1_cnt + 1'b1;
        else
            key1_stable <= key1_dd;

        key0_stable_prev <= key0_stable;
        key1_stable_prev <= key1_stable;

        if(both_down) begin
            combo_seen <= 1'b1;
            if(chord_cnt < KEY_CHORD_TICKS)
                chord_cnt <= chord_cnt + 1'b1;
            else if(!chord_latched) begin
                if(ui_mode == 2'd3)
                    ui_mode <= 2'd0;
                else
                    ui_mode <= ui_mode + 1'b1;
                chord_latched <= 1'b1;
            end
        end else begin
            chord_cnt <= 32'd0;
            if(key0_stable && key1_stable) begin
                combo_seen    <= 1'b0;
                chord_latched <= 1'b0;
            end
        end

        if(key0_release && !combo_seen) begin
            case(ui_mode)
                2'd0: freq_sel  <= (freq_sel  == 3'd6) ? 3'd0 : freq_sel + 1'b1;
                2'd1: amp_sel   <= (amp_sel   == 3'd4) ? 3'd0 : amp_sel + 1'b1;
                2'd2: phase_sel <= (phase_sel == 3'd4) ? 3'd0 : phase_sel + 1'b1;
                2'd3: wave_sel  <= wave_sel + 1'b1;
                default: begin end
            endcase
        end

        if(key1_release && !combo_seen) begin
            case(ui_mode)
                2'd0: freq_sel  <= (freq_sel  == 3'd0) ? 3'd6 : freq_sel - 1'b1;
                2'd1: amp_sel   <= (amp_sel   == 3'd0) ? 3'd4 : amp_sel - 1'b1;
                2'd2: phase_sel <= (phase_sel == 3'd0) ? 3'd4 : phase_sel - 1'b1;
                2'd3: wave_sel  <= wave_sel - 1'b1;
                default: begin end
            endcase
        end
    end
end

`ifdef AWG_UART_CONTROL
assign led = awg_reg_use_control ? {awg_reg_output_enable, awg_uart_activity} : ui_mode;
`else
assign led = ui_mode;
`endif

jesd204_phy_0 jesd204_phy_txrx_inst (
  .cpll_refclk(w_qpll_refclk),                          // input wire cpll_refclk
  .qpll_refclk(w_qpll_refclk),                          // input wire qpll_refclk
  .drpclk(clk_axi_100m),                                      // input wire drpclk
  .tx_reset_gt(w_tx_reset_gt),                            // input wire tx_reset_gt
  .rx_reset_gt(w_rx_reset_gt),                            // input wire rx_reset_gt
  .tx_sys_reset(w_tx_sys_reset),                          // input wire tx_sys_reset
  .rx_sys_reset(w_rx_sys_reset),                          // input wire rx_sys_reset
  .txp_out({dac_txp_d3, dac_txp_d2,dac_txp_d1, dac_txp_d0}),                                    // output wire [3 : 0] txp_out
  .txn_out({dac_txn_d3, dac_txn_d2,dac_txn_d1, dac_txn_d0}),                                    // output wire [3 : 0] txn_out
  .rxp_in({adc_rxp_a1, adc_rxp_a0}),                                      // input wire [3 : 0] rxp_in
  .rxn_in({adc_rxn_a1, adc_rxn_a0}),                                      // input wire [3 : 0] rxn_in
  .tx_core_clk(w_tx_core_clk),                            // input wire tx_core_clk
  .rx_core_clk(w_rx_core_clk),                            // input wire rx_core_clk
  .txoutclk(),                                  // output wire txoutclk
  .rxoutclk(),                                  // output wire rxoutclk
  .gt_prbssel(w_gt_prbssel),                              // input wire [3 : 0] gt_prbssel
  .gt0_txdata(gt0_txdata),                              // input wire [31 : 0] gt0_txdata
  .gt0_txcharisk(gt0_txcharisk),                        // input wire [3 : 0] gt0_txcharisk
  .gt1_txdata(gt1_txdata),                              // input wire [31 : 0] gt1_txdata
  .gt1_txcharisk(gt1_txcharisk),                        // input wire [3 : 0] gt1_txcharisk
  .gt2_txdata(gt2_txdata),                              // input wire [31 : 0] gt2_txdata
  .gt2_txcharisk(gt2_txcharisk),                        // input wire [3 : 0] gt2_txcharisk
  .gt3_txdata(gt3_txdata),                              // input wire [31 : 0] gt3_txdata
  .gt3_txcharisk(gt3_txcharisk),                        // input wire [3 : 0] gt3_txcharisk
  .tx_reset_done(w_tx_reset_done),                        // output wire tx_reset_done
  .gt0_rxdata(gt0_rxdata),                              // output wire [31 : 0] gt0_rxdata
  .gt0_rxcharisk(gt0_rxcharisk),                        // output wire [3 : 0] gt0_rxcharisk
  .gt0_rxdisperr(gt0_rxdisperr),                        // output wire [3 : 0] gt0_rxdisperr
  .gt0_rxnotintable(gt0_rxnotintable),                  // output wire [3 : 0] gt0_rxnotintable
  .gt1_rxdata(gt1_rxdata),                              // output wire [31 : 0] gt1_rxdata
  .gt1_rxcharisk(gt1_rxcharisk),                        // output wire [3 : 0] gt1_rxcharisk
  .gt1_rxdisperr(gt1_rxdisperr),                        // output wire [3 : 0] gt1_rxdisperr
  .gt1_rxnotintable(gt1_rxnotintable),                  // output wire [3 : 0] gt1_rxnotintable
  .gt2_rxdata(),                              // output wire [31 : 0] gt2_rxdata
  .gt2_rxcharisk(),                        // output wire [3 : 0] gt2_rxcharisk
  .gt2_rxdisperr(),                        // output wire [3 : 0] gt2_rxdisperr
  .gt2_rxnotintable(),                  // output wire [3 : 0] gt2_rxnotintable
  .gt3_rxdata(),                              // output wire [31 : 0] gt3_rxdata
  .gt3_rxcharisk(),                        // output wire [3 : 0] gt3_rxcharisk
  .gt3_rxdisperr(),                        // output wire [3 : 0] gt3_rxdisperr
  .gt3_rxnotintable(),                  // output wire [3 : 0] gt3_rxnotintable
  .rx_reset_done(w_rx_reset_done),                        // output wire rx_reset_done
  .rxencommaalign(w_rxencommaalign_out),                      // input wire rxencommaalign
  .common0_qpll_clk_out(),        // output wire common0_qpll0_clk_out
  .common0_qpll_refclk_out(),  // output wire common0_qpll0_refclk_out
  .common0_qpll_lock_out(w_common0_qpll_lock_out)      // output wire common0_qpll0_lock_out
);
jesd204_rx jesd204_rx_inst (
  .gt0_rxdata(gt0_rxdata),                          // input wire [31 : 0] gt0_rxdata
  .gt0_rxcharisk(gt0_rxcharisk),                    // input wire [3 : 0] gt0_rxcharisk
  .gt0_rxdisperr(gt0_rxdisperr),                    // input wire [3 : 0] gt0_rxdisperr
  .gt0_rxnotintable(gt0_rxnotintable),              // input wire [3 : 0] gt0_rxnotintable
  .gt1_rxdata(gt1_rxdata),                          // input wire [31 : 0] gt1_rxdata
  .gt1_rxcharisk(gt1_rxcharisk),                    // input wire [3 : 0] gt1_rxcharisk
  .gt1_rxdisperr(gt1_rxdisperr),                    // input wire [3 : 0] gt1_rxdisperr
  .gt1_rxnotintable(gt1_rxnotintable),              // input wire [3 : 0] gt1_rxnotintable
  .rx_reset_done(w_rx_reset_done),                    // input wire rx_reset_done
  .rxencommaalign_out(w_rxencommaalign_out),          // output wire rxencommaalign_out
  .rx_reset_gt(w_rx_reset_gt),                        // output wire rx_reset_gt
  .rx_core_clk(w_rx_core_clk),                        // input wire rx_core_clk
  .s_axi_aclk(clk_axi_100m),                          // input wire s_axi_aclk
  .s_axi_aresetn(w_rst_n),                    // input wire s_axi_aresetn
  .s_axi_awaddr(0),                      // input wire [11 : 0] s_axi_awaddr
  .s_axi_awvalid(0),                    // input wire s_axi_awvalid
  .s_axi_awready(),                    // output wire s_axi_awready                                
  .s_axi_wdata(0),                        // input wire [31 : 0] s_axi_wdata
  .s_axi_wstrb(0),                        // input wire [3 : 0] s_axi_wstrb
  .s_axi_wvalid(0),                      // input wire s_axi_wvalid
  .s_axi_wready(),                      // output wire s_axi_wready
  .s_axi_bresp(),                        // output wire [1 : 0] s_axi_bresp
  .s_axi_bvalid(),                      // output wire s_axi_bvalid
  .s_axi_bready(0),                      // input wire s_axi_bready
  .s_axi_araddr(0),                      // input wire [11 : 0] s_axi_araddr
  .s_axi_arvalid(0),                    // input wire s_axi_arvalid
  .s_axi_arready(),                    // output wire s_axi_arready
  .s_axi_rdata(),                        // output wire [31 : 0] s_axi_rdata
  .s_axi_rresp(),                        // output wire [1 : 0] s_axi_rresp
  .s_axi_rvalid(),                      // output wire s_axi_rvalid
  .s_axi_rready(0),                      // input wire s_axi_rready
  .rx_reset(w_rx_sys_reset),                              // input wire rx_reset
  .rx_aresetn(),                          // output wire rx_aresetn
  .rx_tdata(w_rx_tdata),                              // output wire [63 : 0] rx_tdata
  .rx_tvalid(w_rx_tvalid),                            // output wire rx_tvalid
  .rx_start_of_frame(w_rx_start_of_frame),            // output wire [3 : 0] rx_start_of_frame
  .rx_end_of_frame(w_rx_end_of_frame),                // output wire [3 : 0] rx_end_of_frame
  .rx_start_of_multiframe(w_rx_start_of_multiframe),  // output wire [3 : 0] rx_start_of_multiframe
  .rx_end_of_multiframe(w_rx_end_of_multiframe),      // output wire [3 : 0] rx_end_of_multiframe
  .rx_frame_error(w_rx_frame_error),                  // output wire [7 : 0] rx_frame_error
  .rx_sysref(w_sysref),                            // input wire rx_sysref
  .rx_sync(w_rx_sync)                                // output wire rx_sync
);

jesd204_tx jesd204_tx_inst (
  .gt0_txdata(gt0_txdata),                          // output wire [31 : 0] gt0_txdata
  .gt0_txcharisk(gt0_txcharisk),                    // output wire [3 : 0] gt0_txcharisk
  .gt1_txdata(gt1_txdata),                          // output wire [31 : 0] gt1_txdata
  .gt1_txcharisk(gt1_txcharisk),                    // output wire [3 : 0] gt1_txcharisk
  .gt2_txdata(gt2_txdata),                          // output wire [31 : 0] gt2_txdata
  .gt2_txcharisk(gt2_txcharisk),                    // output wire [3 : 0] gt2_txcharisk
  .gt3_txdata(gt3_txdata),                          // output wire [31 : 0] gt3_txdata
  .gt3_txcharisk(gt3_txcharisk),                    // output wire [3 : 0] gt3_txcharisk
  .tx_reset_done(w_tx_reset_done),                    // input wire tx_reset_done
  .gt_prbssel_out(w_gt_prbssel),                      // output wire [3 : 0] gt_prbssel_out
  .tx_reset_gt(w_tx_reset_gt),                        // output wire tx_reset_gt
  .tx_core_clk(w_tx_core_clk),                        // input wire tx_core_clk
  .s_axi_aclk(clk_axi_100m),                          // input wire s_axi_aclk
  .s_axi_aresetn(w_rst_n),                            // input wire s_axi_aresetn              
  .s_axi_awaddr(w_tx_s_axi_awaddr),                      // input wire [11 : 0] s_axi_awaddr           
  .s_axi_awvalid(w_tx_s_axi_awvalid),                    // input wire s_axi_awvalid                    
  .s_axi_awready(w_tx_s_axi_awready),                    // output wire s_axi_awready                      
  .s_axi_wdata(w_tx_s_axi_wdata),                        // input wire [31 : 0] s_axi_wdata              
  .s_axi_wstrb(4'b1111),                                       // input wire [3 : 0] s_axi_wstrb              
  .s_axi_wvalid(w_tx_s_axi_wvalid),                      // input wire s_axi_wvalid                    
  .s_axi_wready(w_tx_s_axi_wready),                      // output wire s_axi_wready                     
  .s_axi_bresp(w_tx_s_axi_bresp),                        // output wire [1 : 0] s_axi_bresp             
  .s_axi_bvalid(w_tx_s_axi_bvalid),                      // output wire s_axi_bvalid           
  .s_axi_bready(w_tx_s_axi_bready),                      // input wire s_axi_bready                    
  .s_axi_araddr(w_rx_s_axi_araddr),                      // input wire [11 : 0] s_axi_araddr           
  .s_axi_arvalid(w_rx_s_axi_arvalid),                    // input wire s_axi_arvalid                    
  .s_axi_arready(w_rx_s_axi_arready),                    // output wire s_axi_arready                    
  .s_axi_rdata(w_rx_s_axi_rdata),                        // output wire [31 : 0] s_axi_rdata           
  .s_axi_rresp(w_rx_s_axi_rresp),                        // output wire [1 : 0] s_axi_rresp            
  .s_axi_rvalid(w_rx_s_axi_rvalid),                      // output wire s_axi_rvalid
  .s_axi_rready(w_rx_s_axi_rready),                      // input wire s_axi_rready
  .tx_reset(w_tx_sys_reset),                              // input wire tx_reset
  .tx_sysref(w_sysref),                            // input wire tx_sysref
  .tx_start_of_frame(w_tx_start_of_frame),            // output wire [3 : 0] tx_start_of_frame
  .tx_start_of_multiframe(w_tx_start_of_multiframe),  // output wire [3 : 0] tx_start_of_multiframe
  .tx_aresetn(w_tx_aresetn),                          // output wire tx_aresetn
  .tx_tdata(w_tx_tdata),                              // input wire [127 : 0] tx_tdata
  .tx_tready(w_tx_tready),                            // output wire tx_tready
  .tx_sync(w_tx_sync)                                // input wire tx_sync
);
   IBUFDS  IBUFDS_inst_dac (
      .O(w_tx_sync),     // Diff_p output (connect directly to top-level port)
      .IB(i_tx_sync_n),   // Diff_n output (connect directly to top-level port)
      .I(i_tx_sync_p)      // Buffer input
   );
   OBUFDS  OBUFDS_inst (
      .O(o_rx_sync_p),     // Diff_p output (connect directly to top-level port)
      .OB(o_rx_sync_n),   // Diff_n output (connect directly to top-level port)
      .I(w_rx_sync)      // Buffer input
   );
reg[31:0] trig_cnt;
reg r_trig_in;
//产生触发脉冲信号r_trig_in，每个触发脉冲为高电平时，触发FIFO逻辑，将jesd204b的数据存储入FIFO，后读出
always@ (posedge w_rx_core_clk or negedge w_rst_n) begin
    if(!w_rst_n) begin
        trig_cnt <= 16'd0;
        r_trig_in <= 1'b0;
        end
     else if(trig_cnt < 16'd10) begin
        r_trig_in <= 1'b1;
        trig_cnt <= trig_cnt + 1'd1;
        end
     else if(trig_cnt < 32'd40000000) begin
        r_trig_in <= 1'b0;
        trig_cnt <= trig_cnt + 1'd1;
        end
     else begin
        trig_cnt <= 1'd0;
        r_trig_in <= 1'b0;
        end
end
wire[15:0] w_sample_0, w_sample_1, w_sample_2, w_sample_3;
wire [13:0] w_adc_sample_ch1, w_adc_sample_ch2;
wire w_fifo_wr_done1, w_fifo_wr_done2;
// jesd204b ip核数据输出解析模块，解析后输出为adc波形数据
jesd_data_parse  jesd_data_parse_ch1(
    .wr_clk  (w_rx_core_clk),
    .rd_clk  (clk_25m),
    .rst_n  (w_rst_n),
    .i_jesd_data  (w_rx_tdata[31:0]),
    .trig_in  (r_trig_in),
    .fifo_wr_done  (w_fifo_wr_done1),
    
    .o_adc_sample  (w_adc_sample_ch1)
    );
jesd_data_parse  jesd_data_parse_ch2(
    .wr_clk  (w_rx_core_clk),
    .rd_clk  (clk_25m),
    .rst_n  (w_rst_n),
    .i_jesd_data  (w_rx_tdata[63:32]),
    .trig_in  (r_trig_in),
    .fifo_wr_done  (w_fifo_wr_done2),
    
    .o_adc_sample  (w_adc_sample_ch2)
    );
reg[3:0] state;
reg[15:0] jesd_rst_delay_cnt = 0;
/********************************************************************************************************************************************/
// 系统状态机：控制各个芯片的初始化以及JESD204B复位顺序，JESD204B复位应当保证接收数据的一方后复位，发送方先复位
//
// 初始化顺序：初始化时钟芯片lmk04828 -> 初始化adc芯片ad9250 -> 复位jesd tx ip -> 配置jesd tx ip axi寄存器 -> 初始化dac芯片ad9144 -> 复位jesd rx ip
//
// 注意：jesd204 ip的axi-lite接口寄存器不是必须要配置，通常是当jesd204ip 的GUI界面参数不满足需求或者需要进一步观察调试时候，才会访问axi-lite寄存器
//
// 本demo开发过程中对jesd tx ip核（ad9144）进行过寄存器调试观察，故保留了axi-lite的配置接口
/********************************************************************************************************************************************/

always@ (posedge clk_25m) begin
    if(!w_rst_n)  begin
        state <= 4'd0;
        lmk_datain_valid <= 1'b0; 
        ads_datain_valid <= 1'b0; 
        init_done <= 0; 
        r_jesd_rx_sys_reset <= 1'b0;
        r_jesd_tx_sys_reset <= 1'b0; 
        jesd_rst_delay_cnt <= 16'd0;
        w_tx_axi_ena <= 1'b1;
        end
    else begin
        case(state)
            4'd0: begin     
                            lmk_datain_valid <= 1'b0; 
                            ads_datain_valid <= 1'b0; 
                            init_done <= 0; 
                            state <= 3'd1; 
                            end
            4'd1: begin    
                            if(lmk_datain_ready) begin
                                lmk_datain_valid <= 1'b1; 
                                state <= 3'd2;
                                end
                            else begin
                                lmk_datain_valid <= 1'b0; 
                                state <= 3'd1;
                                end
                            end
            4'd2:  begin state <= 3'd3;end              
            4'd3: begin    
                            if(!lmk_datain_ready) begin
                                lmk_datain_valid <= 1'b0; // 至此完成lmk时钟芯片初始化
                                state <= 3'd4;//
                                end
                           else begin
                                lmk_datain_valid <= 1'b1; 
                                state <= 3'd3;
                                end
                            end
            4'd4: begin     
                            if(lmk_datain_ready && ads_datain_ready) begin
                                ads_datain_valid <= 1'b1;
                                state <= 3'd5;
                                end
                            else begin
                                ads_datain_valid <= 1'b0;
                                state <= 3'd4;
                                end
                        end
            4'd5: begin     
                            if(!ads_datain_ready) begin
                                ads_datain_valid <= 1'b0;  // 至此完成adc初始化
                                state <= 3'd6;//6
                                end
                            else begin
                                ads_datain_valid <= 1'b1;
                                state <= 3'd5;
                                end
                        end
            4'd6: begin     
                            if(jesd_rst_delay_cnt < 16'd1000) begin
                                r_jesd_tx_sys_reset <= 1'b1;  // 延时 待ip核复位结束
                                w_tx_axi_ena <= 1'b1;
                                jesd_rst_delay_cnt <= jesd_rst_delay_cnt + 16'd1;
                                state <= 3'd6;
                                end
                            else if(jesd_rst_delay_cnt < 16'd20000) begin
                                r_jesd_tx_sys_reset <= 1'b0;  
                                w_tx_axi_ena <= 1'b1;
                                jesd_rst_delay_cnt <= jesd_rst_delay_cnt + 16'd1;
                                state <= 3'd6;
                                end                                                                                        
                            else if(jesd_rst_delay_cnt < 16'd60000) begin
                                r_jesd_tx_sys_reset <= 1'b0;  
                                w_tx_axi_ena <= 1'b0; //
                                jesd_rst_delay_cnt <= jesd_rst_delay_cnt + 16'd1;
                                state <= 3'd6;
                                end
                            else begin
                               r_jesd_tx_sys_reset <= 1'b0;
                                w_tx_axi_ena <= 1'b1;
                                jesd_rst_delay_cnt <= 16'd0;
                                state <= 3'd7;
                                end
                        end                        
            4'd7: begin     
                            if(das_datain_ready ) begin
                                das_datain_valid <= 1'b1;
                                state <= 4'd8;
                                end
                            else begin
                                das_datain_valid <= 1'b0;
                                state <= 4'd7;
                                end
                        end    
            4'd8: begin     
                            if(!das_datain_ready) begin
                                das_datain_valid <= 1'b0;
                                state <= 4'd9;
                                end
                            else begin
                                das_datain_valid <= 1'b1;
                                state <= 4'd8;
                                end
                        end                                            
            4'd9: begin     
                            if(das_datain_ready) begin
                                if(jesd_rst_delay_cnt < 16'd100) begin
                                    r_jesd_rx_sys_reset <= 1;
                                    jesd_rst_delay_cnt <= jesd_rst_delay_cnt + 16'd1;
                                    state <= 4'd9;
                                    end  
                                else begin
                                    r_jesd_rx_sys_reset <= 0;
                                    jesd_rst_delay_cnt <= 0;
                                    state <= 4'd10;
                                    end                                 
                                end
                            else begin
                                init_done <= 0;
                                state <= 4'd9;
                                end
                        end     
            4'd10: begin     
                            init_done <= 1;
                            state <= 4'd10;
                        end                                    
        endcase
    end  
end 

// fifo读取AD9250输出的双通道采样数据
ila_for_adc_data ila_for_adc_data_inst (
	.clk(clk_25m), // input wire clk
	
	.probe0(w_fifo_wr_done1), // input wire [0:0]  probe0  
	.probe1(w_fifo_wr_done2), // input wire [0:0]  probe1 
	.probe2(w_adc_sample_ch1), // input wire [13:0]  probe2 
	.probe3(w_adc_sample_ch2)  // input wire [13:0]  probe3 
);

//观察ad9250 jesd204b rx ip核输出的各个信号
my_ila_jesd my_ila_jesd_rx (
	.clk(w_rx_core_clk), // input wire clk
	.probe0({1'b0,1'b0}), // input wire [0:0]  probe0  
	.probe1(w_rx_reset_done), // input wire [0:0]  probe1 
	.probe2(w_rx_tvalid), // input wire [0:0]  probe2 
	.probe3(w_rx_sync), // input wire [0:0]  probe3 
	.probe4(w_sysref), // input wire [0:0]  probe4 
	.probe5(w_rx_start_of_frame), // input wire [3:0]  probe5 
	.probe6(w_rx_end_of_frame), // input wire [3:0]  probe6 
	.probe7(w_rx_start_of_multiframe), // input wire [3:0]  probe7 
	.probe8(w_rx_end_of_multiframe), // input wire [3:0]  probe8 
	.probe9(w_rx_frame_error), // input wire [7:0]  probe9 
	.probe10(w_rx_tdata), // input wire [63:0]  probe10 
	.probe11({64'b0}), // input wire [63:0]  probe11 
	.probe12({8'b0}), // input wire [7:0]  probe12 
	.probe13({8'b0}), // input wire [7:0]  probe13 
	.probe14({8'b0}), // input wire [7:0]  probe14 
	.probe15({8'b0}) // input wire [7:0]  probe15
);

//观察ad9144 jesd204b tx ip核输出的各个信号
my_ila_jesd my_ila_jesd_tx (
	.clk(w_tx_core_clk), // input wire clk
	.probe0({1'b0,w_common0_qpll_lock_out}), // input wire [0:0]  probe0  
	.probe1(w_tx_reset_done), // input wire [0:0]  probe1 
	.probe2(w_tx_tready), // input wire [0:0]  probe2 
	.probe3(w_tx_sync), // input wire [0:0]  probe3 
	.probe4(w_sysref), // input wire [0:0]  probe4 
	.probe5(w_tx_start_of_frame), // input wire [3:0]  probe5 
	.probe6({4'b0}), // input wire [3:0]  probe6 
	.probe7(w_tx_start_of_multiframe), // input wire [3:0]  probe7 
	.probe8({4'b0}), // input wire [3:0]  probe8 
	.probe9({9'b0}), // input wire [7:0]  probe9 
	.probe10(w_tx_tdata[63:0]), // input wire [63:0]  probe10 
	.probe11(w_tx_tdata[127:64]), // input wire [63:0]  probe11 
	.probe12({4'b0,awg_phase_addr0[7:0]}), // input wire [7:0]  probe12 
	.probe13({4'b0,awg_phase_addr1[7:0]}), // input wire [7:0]  probe13 
	.probe14({4'b0,awg_phase_addr2[7:0]}), // input wire [7:0]  probe14 
	.probe15({4'b0,awg_phase_addr3[7:0]}) // input wire [7:0]  probe15	
	
);

// ip核AXI-lite调试信号  默认不使用
//ila_for_jesd_axi_debug ila_for_jesd_axi_debug_read(
//	.clk(clk_axi_100m), // input wire clk
//	.probe0(w_rx_axi_ena), // input wire [0:0]  probe0  
//	.probe1(w_rx_s_axi_arready), // input wire [0:0]  probe1 
//	.probe2(w_rx_s_axi_rvalid), // input wire [0:0]  probe2 
//	.probe3(w_rx_s_axi_rresp), // input wire [0:0]  probe3 
//	.probe4(w_rx_s_axi_araddr), // input wire [0:0]  probe4
//	.probe5(w_rx_s_axi_arvalid), // input wire [3:0]  probe5 
//	.probe6(w_rx_s_axi_rdata), // input wire [3:0]  probe6 
//	.probe7(w_rx_s_axi_rready)
//	);
// ip核AXI-lite调试信号  默认不使用
//ila_for_jesd_axi_debug ila_for_jesd_axi_debug_wr (
//	.clk(clk_axi_100m), // input wire clk
//	.probe0(w_tx_axi_ena), // input wire [0:0]  probe0  
//	.probe1(w_tx_s_axi_awready), // input wire [0:0]  probe1 
//	.probe2(w_tx_s_axi_wvalid), // input wire [0:0]  probe2 
//	.probe3(w_tx_s_axi_bresp), // input wire [0:0]  probe3 
//	.probe4(w_tx_s_axi_awaddr), // input wire [0:0]  probe4
//	.probe5(w_tx_s_axi_awvalid), // input wire [3:0]  probe5 
//	.probe6(w_tx_s_axi_wdata), // input wire [3:0]  probe6 
//	.probe7(w_tx_s_axi_wready)
//	);
endmodule



