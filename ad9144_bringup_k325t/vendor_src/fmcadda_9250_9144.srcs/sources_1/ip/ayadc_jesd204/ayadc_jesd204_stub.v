// Copyright 1986-2018 Xilinx, Inc. All Rights Reserved.
// --------------------------------------------------------------------------------
// Tool Version: Vivado v.2018.3 (win64) Build 2405991 Thu Dec  6 23:38:27 MST 2018
// Date        : Wed Feb 22 23:08:52 2023
// Host        : DESKTOP-EC1OICA running 64-bit major release  (build 9200)
// Command     : write_verilog -force -mode synth_stub -rename_top ayadc_jesd204 -prefix
//               ayadc_jesd204_ ayadc_jesd204_stub.v
// Design      : ayadc_jesd204
// Purpose     : Stub declaration of top-level module interface
// Device      : xc7k325tffg676-2
// --------------------------------------------------------------------------------

// This empty module with port declaration file causes synthesis tools to infer a black box for IP.
// The synthesis directives are for Synopsys Synplify support to prevent IO buffer insertion.
// Please paste the declaration into a Verilog source file or add the file as an additional source.
(* X_CORE_INFO = "jesd204_v7_2_4,Vivado 2018.3" *)
module ayadc_jesd204(refclk_p, refclk_n, glblclk_p, glblclk_n, 
  rx_reset, rx_core_clk_out, rx_sysref, rx_sync, rxp, rxn, rx_aresetn, rx_start_of_frame, 
  rx_end_of_frame, rx_start_of_multiframe, rx_end_of_multiframe, rx_frame_error, rx_tvalid, 
  rx_tdata, s_axi_aclk, s_axi_aresetn, s_axi_awaddr, s_axi_awvalid, s_axi_awready, s_axi_wdata, 
  s_axi_wstrb, s_axi_wvalid, s_axi_wready, s_axi_bresp, s_axi_bvalid, s_axi_bready, 
  s_axi_araddr, s_axi_arvalid, s_axi_arready, s_axi_rdata, s_axi_rresp, s_axi_rvalid, 
  s_axi_rready)
/* synthesis syn_black_box black_box_pad_pin="refclk_p,refclk_n,glblclk_p,glblclk_n,rx_reset,rx_core_clk_out,rx_sysref,rx_sync,rxp[3:0],rxn[3:0],rx_aresetn,rx_start_of_frame[3:0],rx_end_of_frame[3:0],rx_start_of_multiframe[3:0],rx_end_of_multiframe[3:0],rx_frame_error[15:0],rx_tvalid,rx_tdata[127:0],s_axi_aclk,s_axi_aresetn,s_axi_awaddr[11:0],s_axi_awvalid,s_axi_awready,s_axi_wdata[31:0],s_axi_wstrb[3:0],s_axi_wvalid,s_axi_wready,s_axi_bresp[1:0],s_axi_bvalid,s_axi_bready,s_axi_araddr[11:0],s_axi_arvalid,s_axi_arready,s_axi_rdata[31:0],s_axi_rresp[1:0],s_axi_rvalid,s_axi_rready" */;
  input refclk_p;
  input refclk_n;
  input glblclk_p;
  input glblclk_n;
  input rx_reset;
  output rx_core_clk_out;
  input rx_sysref;
  output rx_sync;
  input [3:0]rxp;
  input [3:0]rxn;
  output rx_aresetn;
  output [3:0]rx_start_of_frame;
  output [3:0]rx_end_of_frame;
  output [3:0]rx_start_of_multiframe;
  output [3:0]rx_end_of_multiframe;
  output [15:0]rx_frame_error;
  output rx_tvalid;
  output [127:0]rx_tdata;
  input s_axi_aclk;
  input s_axi_aresetn;
  input [11:0]s_axi_awaddr;
  input s_axi_awvalid;
  output s_axi_awready;
  input [31:0]s_axi_wdata;
  input [3:0]s_axi_wstrb;
  input s_axi_wvalid;
  output s_axi_wready;
  output [1:0]s_axi_bresp;
  output s_axi_bvalid;
  input s_axi_bready;
  input [11:0]s_axi_araddr;
  input s_axi_arvalid;
  output s_axi_arready;
  output [31:0]s_axi_rdata;
  output [1:0]s_axi_rresp;
  output s_axi_rvalid;
  input s_axi_rready;
endmodule
