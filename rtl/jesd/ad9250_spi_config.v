`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company:
// Engineer:
//
// Create Date: 2022/07/31 08:40:55
// Design Name:
// Module Name: ltc2175_14_spi_wr_config
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
module ad9250_spi_config(
                        input clk_in,
                        input rst_n,

                        output o_sclk,
                        //(* mark_debug = "true" *)output o_sda,
                        //(* mark_debug = "true" *)output o_sda_dir,
                        output o_sen_n,
                        output reg o_reset,

                        inout io_sda,
                        input datain_valid,
                        output reg datain_ready
                        );
localparam IDLE             = 8'd0;
localparam START            = 8'd1;
localparam PRE_REST_H         = 8'd46;
localparam PRE_REST_L         = 8'd47;
localparam WAIT_GAP       = 8'd2;
localparam WR_STA_0       = 8'd3  ;
localparam WR_STA_1       = 8'd4  ;
localparam WR_STA_2       = 8'd5  ;
localparam WR_STA_3       = 8'd6  ;
localparam WR_STA_4       = 8'd7  ;
localparam WR_STA_5       = 8'd8  ;
localparam WR_STA_6       = 8'd9  ;
localparam WR_STA_7       = 8'd10 ;
localparam WR_STA_8       = 8'd11 ;
localparam WR_STA_9       = 8'd12 ;
localparam WR_STA_10       = 8'd13 ;
localparam WR_STA_11       = 8'd14 ;
localparam WR_STA_12       = 8'd15 ;
localparam WR_STA_13       = 8'd16 ;
localparam WR_STA_14       = 8'd17 ;
localparam WR_STA_15       = 8'd18 ;
localparam WR_STA_16       = 8'd19 ;
localparam WR_STA_17       = 8'd20 ;
localparam WR_STA_18       = 8'd21 ;
localparam WR_STA_19       = 8'd22 ;
localparam WR_STA_20       = 8'd23 ;
localparam WR_STA_21       = 8'd24 ;
localparam WR_STA_22       = 8'd25 ;
localparam WR_STA_23       = 8'd26 ;
localparam WR_STA_24       = 8'd27 ;
localparam WR_STA_25       = 8'd28 ;
localparam WR_STA_26       = 8'd29 ;
localparam WR_STA_27       = 8'd30 ;
localparam WR_STA_28       = 8'd31 ;
localparam WR_STA_29       = 8'd32 ;
localparam WR_STA_30       = 8'd33 ;
localparam WR_STA_31       = 8'd34 ;
localparam WR_STA_32       = 8'd35 ;
localparam WR_STA_33       = 8'd36 ;
localparam WR_STA_34       = 8'd37 ;
localparam WR_STA_35       = 8'd38 ;
localparam WR_STA_36       = 8'd39 ;
localparam WR_STA_37       = 8'd40 ;
localparam WR_STA_38       = 8'd41 ;
localparam WR_STA_39       = 8'd42 ;
localparam WR_STA_40       = 8'd43 ;
localparam WR_STA_41       = 8'd44 ;
localparam END  = 8'd45;
localparam SPI_WRITE_MODE  = 2'b00;
localparam SPI_READ_MODE  = 2'b01;
localparam SPI_DELAY_MODE  = 2'b10;

reg dataout_valid;
reg delay_timer_valid;
reg[7:0] state_cur = 8'd0;
reg[7:0] state_next = 8'd0;

wire dataout_ready;
wire delay_timer_ready;
reg[31:0] rst_delay_cnt;

reg[15:0] r_dac_spi_delay_cnt;
reg[15:0] r_rd_info;
wire[7:0] w_rd_data;
reg[1:0] r_wrrd_mode_sel;
reg[23:0] r_wr_infodata;
always@ (posedge clk_in) begin
    if(!rst_n)
        state_cur <= IDLE;
    else
        state_cur <= state_next;
end
always@ (*) begin
case(state_cur)
        IDLE :     begin if(datain_valid) state_next = PRE_REST_H; else state_next = IDLE; end
        PRE_REST_L:  begin     if(rst_delay_cnt == 32'd10000) state_next = PRE_REST_H; else state_next = PRE_REST_L; end
        PRE_REST_H:  begin     if(rst_delay_cnt == 32'd30000) state_next = START; else state_next = PRE_REST_H; end
        START :    begin     if(dataout_ready) state_next = WAIT_GAP; else state_next = START;   end
        WAIT_GAP : begin    state_next = WR_STA_0; end
        WR_STA_0  :begin     if(dataout_ready) state_next = WR_STA_1  ; else state_next = WR_STA_0  ; end
        WR_STA_1  :begin     if(dataout_ready) state_next = WR_STA_2  ; else state_next = WR_STA_1  ; end
        WR_STA_2  :begin     if(dataout_ready) state_next = WR_STA_3  ; else state_next = WR_STA_2  ; end
        WR_STA_3  :begin     if(dataout_ready) state_next = WR_STA_4  ; else state_next = WR_STA_3  ; end
        WR_STA_4  :begin     if(dataout_ready) state_next = WR_STA_5  ; else state_next = WR_STA_4  ; end
        WR_STA_5  :begin     if(dataout_ready) state_next = WR_STA_6  ; else state_next = WR_STA_5  ; end
        WR_STA_6  :begin     if(dataout_ready) state_next = WR_STA_7  ; else state_next = WR_STA_6  ; end
        WR_STA_7  :begin     if(dataout_ready) state_next = WR_STA_8  ; else state_next = WR_STA_7  ; end
        WR_STA_8  :begin     if(dataout_ready) state_next = WR_STA_9  ; else state_next = WR_STA_8  ; end
        WR_STA_9  :begin     if(dataout_ready) state_next = WR_STA_10 ; else state_next = WR_STA_9  ; end
        WR_STA_10  :begin     if(dataout_ready) state_next = WR_STA_11 ; else state_next = WR_STA_10  ; end
        WR_STA_11  :begin     if(dataout_ready) state_next = WR_STA_12 ; else state_next = WR_STA_11  ; end
        WR_STA_12  :begin     if(dataout_ready) state_next = WR_STA_13 ; else state_next = WR_STA_12 ;  end
        WR_STA_13  :begin     if(dataout_ready) state_next = WR_STA_14 ; else state_next = WR_STA_13 ;  end
        WR_STA_14  :begin     if(dataout_ready) state_next = WR_STA_15 ; else state_next = WR_STA_14 ;  end
        WR_STA_15  :begin     if(dataout_ready) state_next = WR_STA_16 ; else state_next = WR_STA_15  ; end
        WR_STA_16  :begin     if(dataout_ready) state_next = WR_STA_17 ; else state_next = WR_STA_16  ; end
        WR_STA_17  :begin     if(dataout_ready) state_next = WR_STA_18 ; else state_next = WR_STA_17  ; end
        WR_STA_18  :begin     if(dataout_ready) state_next = WR_STA_19 ; else state_next = WR_STA_18  ; end
        WR_STA_19  :begin     if(dataout_ready) state_next = WR_STA_20 ; else state_next = WR_STA_19  ; end
        WR_STA_20  :begin     if(dataout_ready) state_next = WR_STA_21 ; else state_next = WR_STA_20  ; end
        WR_STA_21  :begin     if(dataout_ready) state_next = WR_STA_22 ; else state_next = WR_STA_21  ; end
        WR_STA_22  :begin     if(dataout_ready) state_next = WR_STA_23 ; else state_next = WR_STA_22 ;  end
        WR_STA_23  :begin     if(dataout_ready) state_next = WR_STA_24 ; else state_next = WR_STA_23 ;  end
        WR_STA_24  :begin     if(dataout_ready) state_next = WR_STA_25 ; else state_next = WR_STA_24 ;  end
        WR_STA_25  :begin     if(dataout_ready) state_next = WR_STA_26 ; else state_next = WR_STA_25 ;  end
        WR_STA_26  :begin     if(dataout_ready) state_next = WR_STA_27 ; else state_next = WR_STA_26 ;  end
        WR_STA_27  :begin     if(dataout_ready) state_next = WR_STA_28 ; else state_next = WR_STA_27  ; end
        WR_STA_28  :begin     if(dataout_ready) state_next = WR_STA_29 ; else state_next = WR_STA_28 ;  end
        WR_STA_29  :begin     if(dataout_ready) state_next = WR_STA_30 ; else state_next = WR_STA_29 ;  end
        WR_STA_30  :begin     if(dataout_ready) state_next = WR_STA_31 ; else state_next = WR_STA_30 ;  end
        WR_STA_31  :begin     if(dataout_ready) state_next = WR_STA_32 ; else state_next = WR_STA_31 ;  end
        WR_STA_32  :begin     if(dataout_ready) state_next = WR_STA_33 ; else state_next = WR_STA_32 ;  end
        WR_STA_33  :begin     if(dataout_ready) state_next = WR_STA_34 ; else state_next = WR_STA_33 ;  end
        WR_STA_34  :begin     if(dataout_ready) state_next = WR_STA_35 ; else state_next = WR_STA_34 ;  end
        WR_STA_35  :begin     if(dataout_ready) state_next = WR_STA_36 ; else state_next = WR_STA_35 ;  end
        WR_STA_36  :begin     if(dataout_ready) state_next = WR_STA_37 ; else state_next = WR_STA_36 ;  end
        WR_STA_37  :begin     if(dataout_ready) state_next = WR_STA_38 ; else state_next = WR_STA_37 ;  end
        WR_STA_38  :begin     if(dataout_ready) state_next = WR_STA_39 ; else state_next = WR_STA_38 ;  end
        WR_STA_39  :begin     if(dataout_ready) state_next = WR_STA_40 ; else state_next = WR_STA_39 ;  end
        WR_STA_40  :begin     if(dataout_ready) state_next = END ; else state_next = WR_STA_40 ;  end
        END : begin state_next = IDLE; end
    endcase
end

always@ (posedge clk_in) begin
    if(!rst_n) begin
       datain_ready <= 1'b0;
       dataout_valid <= 1'b0;
       rst_delay_cnt <= 10'd0;
       o_reset <= 1'b1;
       r_wrrd_mode_sel <= 1'b0;//select spi_write_mode
       delay_timer_valid <= 1'b0;
    end
    else begin
        case(state_cur)
                IDLE : begin  dataout_valid <= 1'b0; datain_ready <= 1'b1; rst_delay_cnt <= 10'd0; o_reset <= 1'b1; delay_timer_valid <= 1'b0;end
                PRE_REST_L: begin o_reset <= 1'b0; rst_delay_cnt <= rst_delay_cnt + 1'd1; end
                PRE_REST_H: begin o_reset <= 1'b1; rst_delay_cnt <= rst_delay_cnt + 1'd1; end
                START : begin dataout_valid <= 1'b1; datain_ready <= 1'b0; end
                WAIT_GAP : begin dataout_valid <= dataout_valid; datain_ready <= datain_ready; end
                    //For spi write: bit23 = 0 , bit22~bit21=0, bit20~8 : reg address(13bit), bit7~0 : reg data
                WR_STA_0   : begin r_wr_infodata <= {4'b0000,12'h000,8'h3C};  r_wrrd_mode_sel <= SPI_WRITE_MODE;  end  // reset, MSB first
                WR_STA_1   : begin  r_dac_spi_delay_cnt <= 16'd100;        r_wrrd_mode_sel <= SPI_DELAY_MODE;  end
                WR_STA_2   : begin r_wr_infodata <= {3'b000,13'h05F,8'h15};  r_wrrd_mode_sel <= SPI_WRITE_MODE;  end   // disable jesd204b phy
                WR_STA_3   : begin r_wr_infodata <= {3'b000,13'h005,8'h03}; end  // wirte to chA and chB
                WR_STA_4   : begin r_wr_infodata <= {3'b000,13'h009,8'h01}; end  // Nyquist clock, DCS on
                WR_STA_5   : begin r_wr_infodata <= {3'b000,13'h018,8'h0F}; end  // full-scale Vref 2.087Vpp
                WR_STA_6  :  begin r_wr_infodata <= {3'b000,13'h0FF,8'h01};end  // Transfer update
                WR_STA_7  :  begin r_wr_infodata <= {3'b000,13'h00B,8'h00}; end// input clock devide-1
                WR_STA_8 : begin r_wr_infodata <= {3'b000,13'h0FF,8'h01};end  //
                WR_STA_9 : begin r_wr_infodata <= {3'b000,13'h05E,8'h22};end  // M = 2, L = 2
                WR_STA_10: begin r_wr_infodata <= {3'b000,13'h0EE,8'h80};end  // enable internal
                WR_STA_11: begin r_wr_infodata <= {3'b000,13'h021,8'h00};end  // pll set, lane rate >2Gbps
                WR_STA_12: begin r_wr_infodata <= {3'b000,13'h014,8'h01};end  // no inverted adc data, twos complement
                WR_STA_13: begin r_wr_infodata <= {3'b000,13'h015,8'h03};end  //  jesd204b cml level 588mV
                WR_STA_14: begin r_wr_infodata <= {3'b000,13'h066,8'h00};end  // set lane0 and lane1 LID
                WR_STA_15: begin r_wr_infodata <= {3'b000,13'h067,8'h01};end  // set lane0 and lane1 LID
                WR_STA_16: begin r_wr_infodata <= {3'b000,13'h06E,8'h81};end  // L = 2, enable SCR
                WR_STA_17: begin r_wr_infodata <= {3'b000,13'h070,8'h1F};end  // K = 32
                WR_STA_18: begin r_wr_infodata <= {3'b000,13'h08B,8'h00};end  // LMFC offset = 0
                WR_STA_19: begin r_wr_infodata <= {3'b000,13'h0FF,8'h01};end  //
                WR_STA_20: begin r_wr_infodata <= {3'b000,13'h03A,8'h13};end  // sysref buffer enable and use sysref pins continuies mode
                WR_STA_21: begin r_wr_infodata <= {3'b000,13'h0FF,8'h01};end  //
                WR_STA_22: begin r_wr_infodata <= {3'b000,13'h03A,8'h03};end  // conutiues sysref mode, SYNCIN normal mode
                WR_STA_23: begin r_wr_infodata <= {3'b000,13'h0FF,8'h01};end  //
                WR_STA_24: begin r_rd_info <= {3'b100,13'h00A};r_wrrd_mode_sel <= SPI_READ_MODE; end  // read if pll locked
                WR_STA_25: begin r_wr_infodata <= {3'b000,13'h05F,8'h14};r_wrrd_mode_sel <= SPI_WRITE_MODE; end  // enable jesd204b PHY , begin CGS link
                WR_STA_26: begin r_wr_infodata <= {3'b000,13'h0F3,8'hFF};end  // force a internal fifo alignment
                WR_STA_27: begin r_wr_infodata <= {3'b000,13'h0FF,8'h01};end  // force a internal fifo alignment
                WR_STA_28: begin r_wr_infodata <= {3'b000,13'h0EE,8'h81};end  //
                WR_STA_29: begin r_wr_infodata <= {3'b000,13'h0EF,8'h81};end  //
                WR_STA_30: begin r_wr_infodata <= {3'b000,13'h0EE,8'h82};end  //
                WR_STA_31: begin r_wr_infodata <= {3'b000,13'h0EF,8'h82};end  //
                WR_STA_32: begin r_wr_infodata <= {3'b000,13'h0EE,8'h83};end  //
                WR_STA_33: begin r_wr_infodata <= {3'b000,13'h0EF,8'h83};end  //
                WR_STA_34: begin r_wr_infodata <= {3'b000,13'h0EE,8'h84};end  //
                WR_STA_35: begin r_wr_infodata <= {3'b000,13'h0EF,8'h84};end  //
                WR_STA_36: begin r_wr_infodata <= {3'b000,13'h0EE,8'h85};end  //
                WR_STA_37: begin r_wr_infodata <= {3'b000,13'h0EF,8'h85};end  //
                WR_STA_38: begin r_wr_infodata <= {3'b000,13'h0EE,8'h86};end  //
                WR_STA_39: begin r_wr_infodata <= {3'b000,13'h0EF,8'h86};end  //
                WR_STA_40: begin r_wr_infodata <= {3'b000,13'h0EE,8'h87};end  //
                WR_STA_41: begin r_wr_infodata <= {3'b000,13'h0EF,8'h87};end  //
                END : begin dataout_valid <= 1'b0; datain_ready <= 1'b0; rst_delay_cnt <= 10'd0; r_wrrd_mode_sel <= SPI_WRITE_MODE;end
            endcase
        end
end

wire  w_sda_dir;
wire w_o_sda;
assign io_sda = w_sda_dir ? 1'bz: w_o_sda;
wire r_sclk_test, w_hold_save_read;

spi_wr_rd_single #(
                    .SPI_INFO_LENGTH (16),
                    .SPI_DATA_LENGTH (8)
                )
           spi_wr_rd_single
               (
                    .clk_in (clk_in),
                    .rst_n (rst_n),
                    .i_wrrd_mode_sel(r_wrrd_mode_sel),
                    .i_wr_infodata(r_wr_infodata),
                    .i_rd_info (r_rd_info),
                    .r_rd_data (w_rd_data),
                    .o_sclk (o_sclk),
                    .i_sda (io_sda),
                    .o_sda(w_o_sda),
                    .o_sda_dir(w_sda_dir),
                    .o_cs_n(o_sen_n),
                    .i_delay_cnt(r_dac_spi_delay_cnt),
                    .datain_valid (dataout_valid),
                    .datain_ready (dataout_ready),
                    .r_sclk(r_sclk_test),
                    .hold_save_read(w_hold_save_read)
               );

//myila_spi myila_ads_spi_inst (
//	.clk(clk_in), // input wire clk

//	.probe0(o_sclk), // input wire [0:0]  probe0
//	.probe1(o_sen_n), // input wire [0:0]  probe1
//	.probe2(io_sda), // input wire [0:0]  probe2
//	.probe3(w_sda_dir), // input wire [0:0]  probe3
//	.probe4(state_cur), // input wire [7:0]  probe4
//	.probe5({8'b0, w_rd_data}),
//	.probe6(r_sclk_test), // input wire [7:0]  probe4
//	.probe7(w_hold_save_read)

//	);// input wire [7:0]  probe5
endmodule
