`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company:
// Engineer:
//
// Create Date: 2022/05/23 11:33:45
// Design Name:
// Module Name: spi_wr_config
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



module lmk_spi_wr_config(
                        input clk_in,
                        input rst_n,

                        output o_sclk,
                        //output  o_sda,
                        inout io_sda,
                        output  o_cs_n,
                        output  o_lmk_rst,

                        input datain_valid,
                        output reg datain_ready
                        );
reg dataout_valid;
reg[7:0] state_cur = 8'd0, state_next = 8'd0;
wire dataout_ready;
reg[31:0] r_delay_cnt;
localparam  IDLE      = 8'd0;
localparam  START     = 8'd1;
localparam  WAIT_GAP  = 8'd2;
localparam  WR_STA_0  = 8'd3  ;
localparam  WR_STA_1  = 8'd4  ;
localparam  WR_STA_2  = 8'd5  ;
localparam  WR_STA_3  = 8'd6  ;
localparam  WR_STA_4  = 8'd7  ;
localparam  WR_STA_5  = 8'd8  ;
localparam  WR_STA_6  = 8'd9  ;
localparam  WR_STA_7  = 8'd10 ;
localparam  WR_STA_8  = 8'd11 ;
localparam  WR_STA_9  = 8'd12 ;
localparam  WR_STA_10 = 8'd13 ;
localparam  WR_STA_11 = 8'd14 ;
localparam  WR_STA_12 = 8'd15 ;
localparam  WR_STA_13 = 8'd16 ;
localparam  WR_STA_14 = 8'd17 ;
localparam  WR_STA_15 = 8'd18 ;
localparam  WR_STA_16 = 8'd19 ;
localparam  WR_STA_17 = 8'd20 ;
localparam  WR_STA_18 = 8'd21 ;
localparam  WR_STA_19 = 8'd22 ;
localparam  WR_STA_20 = 8'd23 ;
localparam  WR_STA_21 = 8'd24 ;
localparam  WR_STA_22 = 8'd25 ;
localparam  WR_STA_23 = 8'd26 ;
localparam  WR_STA_24 = 8'd27 ;
localparam  WR_STA_25 = 8'd28 ;
localparam  WR_STA_26 = 8'd29 ;
localparam  WR_STA_27 = 8'd30 ;
localparam  WR_STA_28 = 8'd31 ;
localparam  WR_STA_29 = 8'd32 ;
localparam  WR_STA_30 = 8'd33 ;
localparam  WR_STA_31 = 8'd34 ;
localparam  WR_STA_32 = 8'd35 ;
localparam  WR_STA_33 = 8'd36 ;
localparam  WR_STA_34 = 8'd37 ;
localparam  WR_STA_35 = 8'd38;
localparam  WR_STA_36 = 8'd39;
localparam  WR_STA_37 = 8'd40;
localparam  WR_STA_38 = 8'd41;
localparam  WR_STA_39 = 8'd42;
localparam  WR_STA_40 = 8'd43;
localparam  WR_STA_41 = 8'd44;
localparam  WR_STA_42 = 8'd45;
localparam  WR_STA_43 = 8'd46;
localparam  WR_STA_44 = 8'd47;
localparam  WR_STA_45 = 8'd48;
localparam  WR_STA_46 = 8'd49;
localparam  WR_STA_47 = 8'd50;
localparam  WR_STA_48 = 8'd51;
localparam  WR_STA_49 = 8'd52;
localparam  WR_STA_50 = 8'd53;
localparam  WR_STA_51 = 8'd54;
localparam  WR_STA_52 = 8'd55;
localparam  WR_STA_53 = 8'd56;
localparam  WR_STA_54 = 8'd57;
localparam  WR_STA_55 = 8'd58;
localparam  WR_STA_56 = 8'd59;
localparam  WR_STA_57 = 8'd60;
localparam  WR_STA_58 = 8'd61;
localparam  WR_STA_59 = 8'd62;
localparam  WR_STA_60 = 8'd63;
localparam  WR_STA_61 = 8'd64;
localparam  WR_STA_62 = 8'd65;
localparam  WR_STA_63 = 8'd66;
localparam  WR_STA_64 = 8'd67;
localparam  WR_STA_65 = 8'd68;
localparam  WR_STA_66 = 8'd69;
localparam  WR_STA_67 = 8'd70;
localparam  WR_STA_68 = 8'd71;
localparam  WR_STA_69 = 8'd72;
localparam  WR_STA_70 = 8'd73;
localparam  WR_STA_71 = 8'd74;
localparam  WR_STA_72 = 8'd75;
localparam  WR_STA_73 = 8'd76;
localparam  WR_STA_74 = 8'd77;
localparam  WR_STA_75 = 8'd78;
localparam  WR_STA_76 = 8'd79;
localparam  WR_STA_77 = 8'd80;
localparam  WR_STA_78 = 8'd81;
localparam  WR_STA_79 = 8'd82;
localparam  WR_STA_80 = 8'd83;
localparam  WR_STA_81 = 8'd84;
localparam  WR_STA_82 = 8'd85;
localparam  WR_STA_83 = 8'd86;
localparam  WR_STA_84 = 8'd87;
localparam  WR_STA_85 = 8'd88;
localparam  WR_STA_86 = 8'd89;
localparam  WR_STA_87 = 8'd90;
localparam  WR_STA_88 = 8'd91;
localparam  WR_STA_89 = 8'd92;
localparam  WR_STA_90 = 8'd93;
localparam  WR_STA_91 = 8'd94;
localparam  WR_STA_92 = 8'd95;
localparam  WR_STA_93 = 8'd96;
localparam  WR_STA_94 = 8'd97;
localparam  WR_STA_95 = 8'd98;
localparam  WR_STA_96 = 8'd99;
localparam  WR_STA_97 = 8'd100;
localparam  WR_STA_98 = 8'd101;
localparam  WR_STA_99 = 8'd102;
localparam  WR_STA_100 = 8'd103;
localparam  WR_STA_101 = 8'd104;
localparam  WR_STA_102 = 8'd105;
localparam  WR_STA_103 = 8'd106;
localparam  WR_STA_104 = 8'd107;
localparam  WR_STA_105 = 8'd108;
localparam  WR_STA_106 = 8'd109;
localparam  WR_STA_107 = 8'd110;
localparam  WR_STA_108 = 8'd111;
localparam  WR_STA_109 = 8'd112;
localparam  WR_STA_110 = 8'd113;
localparam  WR_STA_111 = 8'd114;
localparam  WR_STA_112 = 8'd115;
localparam  WR_STA_113 = 8'd116;
localparam  WR_STA_114 = 8'd117;
localparam  WR_STA_115 = 8'd118;
localparam  WR_STA_116 = 8'd119;
localparam  WR_STA_117 = 8'd120;
localparam  WR_STA_118 = 8'd121;
localparam  WR_STA_119 = 8'd122;
localparam  WR_STA_120 = 8'd123;
localparam  WR_STA_121 = 8'd124;
localparam  WR_STA_122 = 8'd125;
localparam  WR_STA_123 = 8'd126;
localparam  WR_STA_124 = 8'd127;
localparam  WR_STA_125 = 8'd128;
localparam  WR_STA_126 = 8'd129;
localparam  WR_STA_127 = 8'd130;
localparam  WR_STA_128 = 8'd131;
localparam  WR_STA_129 = 8'd132;
localparam  WR_STA_130 = 8'd133;
localparam  WR_STA_131 = 8'd134;
localparam  WR_STA_132 = 8'd135;
localparam  WR_STA_133 = 8'd136;
localparam  WR_STA_134 = 8'd137;
localparam  WR_STA_135 = 8'd138;
localparam  WR_STA_136 = 8'd139;
localparam  WR_STA_137 = 8'd140;
localparam  END = 8'd141;

localparam SPI_WRITE_MODE  = 2'b00;
localparam SPI_READ_MODE  = 2'b01;
localparam SPI_DELAY_MODE  = 2'b10;

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
        IDLE :     begin if(datain_valid) state_next = START; else state_next = IDLE; end
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
        WR_STA_10 :begin     if(dataout_ready) state_next = WR_STA_11 ; else state_next = WR_STA_10 ; end
        WR_STA_11 :begin     if(dataout_ready) state_next = WR_STA_12 ; else state_next = WR_STA_11 ; end
        WR_STA_12 :begin     if(dataout_ready) state_next = WR_STA_13 ; else state_next = WR_STA_12 ; end
        WR_STA_13 :begin     if(dataout_ready) state_next = WR_STA_14 ; else state_next = WR_STA_13 ; end
        WR_STA_14 :begin     if(dataout_ready) state_next = WR_STA_15 ; else state_next = WR_STA_14 ; end
        WR_STA_15 :begin     if(dataout_ready) state_next = WR_STA_16 ; else state_next = WR_STA_15 ; end
        WR_STA_16 :begin     if(dataout_ready) state_next = WR_STA_17 ; else state_next = WR_STA_16 ; end
        WR_STA_17 :begin     if(dataout_ready) state_next = WR_STA_18 ; else state_next = WR_STA_17 ; end
        WR_STA_18 :begin     if(dataout_ready) state_next = WR_STA_19 ; else state_next = WR_STA_18 ; end
        WR_STA_19 :begin     if(dataout_ready) state_next = WR_STA_20 ; else state_next = WR_STA_19 ; end
        WR_STA_20 :begin     if(dataout_ready) state_next = WR_STA_21 ; else state_next = WR_STA_20 ; end
        WR_STA_21 :begin     if(dataout_ready) state_next = WR_STA_22 ; else state_next = WR_STA_21 ; end
        WR_STA_22 :begin     if(dataout_ready) state_next = WR_STA_23 ; else state_next = WR_STA_22 ; end
        WR_STA_23 :begin     if(dataout_ready) state_next = WR_STA_24 ; else state_next = WR_STA_23 ; end
        WR_STA_24 :begin     if(dataout_ready) state_next = WR_STA_25 ; else state_next = WR_STA_24 ; end
        WR_STA_25 :begin     if(dataout_ready) state_next = WR_STA_26 ; else state_next = WR_STA_25 ; end
        WR_STA_26 :begin     if(dataout_ready) state_next = WR_STA_27 ; else state_next = WR_STA_26 ; end
        WR_STA_27 :begin     if(dataout_ready) state_next = WR_STA_28 ; else state_next = WR_STA_27 ; end
        WR_STA_28 :begin     if(dataout_ready) state_next = WR_STA_29 ; else state_next = WR_STA_28 ; end
        WR_STA_29 :begin     if(dataout_ready) state_next = WR_STA_30 ; else state_next = WR_STA_29 ; end
        WR_STA_30 :begin     if(dataout_ready) state_next = WR_STA_31 ; else state_next = WR_STA_30 ; end
        WR_STA_31 :begin     if(dataout_ready) state_next = WR_STA_32 ; else state_next = WR_STA_31 ; end
        WR_STA_32 :begin     if(dataout_ready) state_next = WR_STA_33 ; else state_next = WR_STA_32 ; end
        WR_STA_33 :begin     if(dataout_ready) state_next = WR_STA_34 ; else state_next = WR_STA_33 ; end
        WR_STA_34 :begin     if(dataout_ready) state_next = WR_STA_35 ; else state_next = WR_STA_34 ; end
        WR_STA_35 :begin     if(dataout_ready) state_next = WR_STA_36 ; else state_next = WR_STA_35 ; end
        WR_STA_36 :begin     if(dataout_ready) state_next = WR_STA_37 ; else state_next = WR_STA_36 ; end
        WR_STA_37 :begin     if(dataout_ready) state_next = WR_STA_38 ; else state_next = WR_STA_37 ; end
        WR_STA_38 :begin     if(dataout_ready) state_next = WR_STA_39 ; else state_next = WR_STA_38 ; end
        WR_STA_39 :begin     if(dataout_ready) state_next = WR_STA_40 ; else state_next = WR_STA_39 ; end
        WR_STA_40 :begin     if(dataout_ready) state_next = WR_STA_41 ; else state_next = WR_STA_40 ; end
        WR_STA_41 :begin     if(dataout_ready) state_next = WR_STA_42 ; else state_next = WR_STA_41 ; end
        WR_STA_42 :begin     if(dataout_ready) state_next = WR_STA_43 ; else state_next = WR_STA_42 ; end
        WR_STA_43 :begin     if(dataout_ready) state_next = WR_STA_44 ; else state_next = WR_STA_43 ; end
        WR_STA_44 :begin     if(dataout_ready) state_next = WR_STA_45 ; else state_next = WR_STA_44 ; end
        WR_STA_45 :begin     if(dataout_ready) state_next = WR_STA_46 ; else state_next = WR_STA_45 ; end
        WR_STA_46 :begin     if(dataout_ready) state_next = WR_STA_47 ; else state_next = WR_STA_46 ; end
        WR_STA_47 :begin     if(dataout_ready) state_next = WR_STA_48 ; else state_next = WR_STA_47 ; end
        WR_STA_48 :begin     if(dataout_ready) state_next = WR_STA_49 ; else state_next = WR_STA_48 ; end
        WR_STA_49 :begin     if(dataout_ready) state_next = WR_STA_50 ; else state_next = WR_STA_49 ; end
        WR_STA_50 :begin     if(dataout_ready) state_next = WR_STA_51 ; else state_next = WR_STA_50 ; end
        WR_STA_51 :begin     if(dataout_ready) state_next = WR_STA_52 ; else state_next = WR_STA_51 ; end
        WR_STA_52 :begin     if(dataout_ready) state_next = WR_STA_53 ; else state_next = WR_STA_52 ; end
        WR_STA_53 :begin     if(dataout_ready) state_next = WR_STA_54 ; else state_next = WR_STA_53 ; end
        WR_STA_54 :begin     if(dataout_ready) state_next = WR_STA_55 ; else state_next = WR_STA_54 ; end
        WR_STA_55 :begin     if(dataout_ready) state_next = WR_STA_56 ; else state_next = WR_STA_55 ; end
        WR_STA_56 :begin     if(dataout_ready) state_next = WR_STA_57 ; else state_next = WR_STA_56 ; end
        WR_STA_57 :begin     if(dataout_ready) state_next = WR_STA_58 ; else state_next = WR_STA_57 ; end
        WR_STA_58 :begin     if(dataout_ready) state_next = WR_STA_59 ; else state_next = WR_STA_58 ; end
        WR_STA_59 :begin     if(dataout_ready) state_next = WR_STA_60 ; else state_next = WR_STA_59 ; end
        WR_STA_60 :begin     if(dataout_ready) state_next = WR_STA_61 ; else state_next = WR_STA_60 ; end
        WR_STA_61 :begin     if(dataout_ready) state_next = WR_STA_62 ; else state_next = WR_STA_61 ; end
        WR_STA_62 :begin     if(dataout_ready) state_next = WR_STA_63 ; else state_next = WR_STA_62 ; end
        WR_STA_63 :begin     if(dataout_ready) state_next = WR_STA_64 ; else state_next = WR_STA_63 ; end
        WR_STA_64 :begin     if(dataout_ready) state_next = WR_STA_65 ; else state_next = WR_STA_64 ; end
        WR_STA_65 :begin     if(dataout_ready) state_next = WR_STA_66 ; else state_next = WR_STA_65 ; end
        WR_STA_66 :begin     if(dataout_ready) state_next = WR_STA_67 ; else state_next = WR_STA_66 ; end
        WR_STA_67 :begin     if(dataout_ready) state_next = WR_STA_68 ; else state_next = WR_STA_67 ; end
        WR_STA_68 :begin     if(dataout_ready) state_next = WR_STA_69 ; else state_next = WR_STA_68 ; end
        WR_STA_69 :begin     if(dataout_ready) state_next = WR_STA_70 ; else state_next = WR_STA_69 ; end
        WR_STA_70 :begin     if(dataout_ready) state_next = WR_STA_71 ; else state_next = WR_STA_70 ; end
        WR_STA_71 :begin     if(dataout_ready) state_next = WR_STA_72 ; else state_next = WR_STA_71 ; end
        WR_STA_72 :begin     if(dataout_ready) state_next = WR_STA_73 ; else state_next = WR_STA_72 ; end
        WR_STA_73 :begin     if(dataout_ready) state_next = WR_STA_74 ; else state_next = WR_STA_73 ; end
        WR_STA_74 :begin     if(dataout_ready) state_next = WR_STA_75 ; else state_next = WR_STA_74 ; end
        WR_STA_75 :begin     if(dataout_ready) state_next = WR_STA_76 ; else state_next = WR_STA_75 ; end
        WR_STA_76 :begin     if(dataout_ready) state_next = WR_STA_77 ; else state_next = WR_STA_76 ; end
        WR_STA_77 :begin     if(dataout_ready) state_next = WR_STA_78 ; else state_next = WR_STA_77 ; end
        WR_STA_78 :begin     if(dataout_ready) state_next = WR_STA_79 ; else state_next = WR_STA_78 ; end
        WR_STA_79 :begin     if(dataout_ready) state_next = WR_STA_80 ; else state_next = WR_STA_79 ; end
        WR_STA_80 :begin     if(dataout_ready) state_next = WR_STA_81 ; else state_next = WR_STA_80 ; end
        WR_STA_81 :begin     if(dataout_ready) state_next = WR_STA_82 ; else state_next = WR_STA_81 ; end
        WR_STA_82 :begin     if(dataout_ready) state_next = WR_STA_83 ; else state_next = WR_STA_82 ; end
        WR_STA_83 :begin     if(dataout_ready) state_next = WR_STA_84 ; else state_next = WR_STA_83 ; end
        WR_STA_84 :begin     if(dataout_ready) state_next = WR_STA_85 ; else state_next = WR_STA_84 ; end
        WR_STA_85 :begin     if(dataout_ready) state_next = WR_STA_86 ; else state_next = WR_STA_85 ; end
        WR_STA_86 :begin     if(dataout_ready) state_next = WR_STA_87 ; else state_next = WR_STA_86 ; end
        WR_STA_87 :begin     if(dataout_ready) state_next = WR_STA_88 ; else state_next = WR_STA_87 ; end
        WR_STA_88 :begin     if(dataout_ready) state_next = WR_STA_89 ; else state_next = WR_STA_88 ; end
        WR_STA_89 :begin     if(dataout_ready) state_next = WR_STA_90 ; else state_next = WR_STA_89 ; end
        WR_STA_90 :begin     if(dataout_ready) state_next = WR_STA_91 ; else state_next = WR_STA_90 ; end
        WR_STA_91 :begin     if(dataout_ready) state_next = WR_STA_92 ; else state_next = WR_STA_91 ; end
        WR_STA_92 :begin     if(dataout_ready) state_next = WR_STA_93 ; else state_next = WR_STA_92 ; end
        WR_STA_93 :begin     if(dataout_ready) state_next = WR_STA_94 ; else state_next = WR_STA_93 ; end
        WR_STA_94 :begin     if(dataout_ready) state_next = WR_STA_95 ; else state_next = WR_STA_94 ; end
        WR_STA_95 :begin     if(dataout_ready) state_next = WR_STA_96 ; else state_next = WR_STA_95 ; end
        WR_STA_96 :begin     if(dataout_ready) state_next = WR_STA_97 ; else state_next = WR_STA_96 ; end
        WR_STA_97 :begin     if(dataout_ready) state_next = WR_STA_98 ; else state_next = WR_STA_97 ; end
        WR_STA_98 :begin     if(dataout_ready) state_next = WR_STA_99 ; else state_next = WR_STA_98 ; end
        WR_STA_99 :begin     if(dataout_ready) state_next = WR_STA_100; else state_next = WR_STA_99 ; end
        WR_STA_100:begin     if(dataout_ready) state_next = WR_STA_101; else state_next = WR_STA_100; end
        WR_STA_101:begin     if(dataout_ready) state_next = WR_STA_102; else state_next = WR_STA_101; end
        WR_STA_102:begin     if(dataout_ready) state_next = WR_STA_103; else state_next = WR_STA_102; end
        WR_STA_103:begin     if(dataout_ready) state_next = WR_STA_104; else state_next = WR_STA_103; end
        WR_STA_104:begin     if(dataout_ready) state_next = WR_STA_105; else state_next = WR_STA_104; end
        WR_STA_105:begin     if(dataout_ready) state_next = WR_STA_106; else state_next = WR_STA_105; end
        WR_STA_106:begin     if(dataout_ready) state_next = WR_STA_107; else state_next = WR_STA_106; end
        WR_STA_107:begin     if(dataout_ready) state_next = WR_STA_108; else state_next = WR_STA_107; end
        WR_STA_108:begin     if(dataout_ready) state_next = WR_STA_109; else state_next = WR_STA_108; end
        WR_STA_109:begin     if(dataout_ready) state_next = WR_STA_110; else state_next = WR_STA_109; end
        WR_STA_110:begin     if(dataout_ready) state_next = WR_STA_111; else state_next = WR_STA_110; end
        WR_STA_111:begin     if(dataout_ready) state_next = WR_STA_112; else state_next = WR_STA_111; end
        WR_STA_112:begin     if(dataout_ready) state_next = WR_STA_113; else state_next = WR_STA_112; end
        WR_STA_113:begin     if(dataout_ready) state_next = WR_STA_114; else state_next = WR_STA_113; end
        WR_STA_114:begin     if(dataout_ready) state_next = WR_STA_115; else state_next = WR_STA_114; end
        WR_STA_115:begin     if(dataout_ready) state_next = WR_STA_116; else state_next = WR_STA_115; end
        WR_STA_116:begin     if(dataout_ready) state_next = WR_STA_117; else state_next = WR_STA_116; end
        WR_STA_117:begin     if(dataout_ready) state_next = WR_STA_118; else state_next = WR_STA_117; end
        WR_STA_118:begin     if(dataout_ready) state_next = WR_STA_119; else state_next = WR_STA_118; end
        WR_STA_119:begin     if(dataout_ready) state_next = WR_STA_120; else state_next = WR_STA_119; end
        WR_STA_120:begin     if(dataout_ready) state_next = WR_STA_121; else state_next = WR_STA_120; end
        WR_STA_121:begin     if(dataout_ready) state_next = WR_STA_122; else state_next = WR_STA_121; end
        WR_STA_122:begin     if(dataout_ready) state_next = WR_STA_123; else state_next = WR_STA_122; end
        WR_STA_123:begin     if(dataout_ready) state_next = WR_STA_124; else state_next = WR_STA_123; end
        WR_STA_124:begin     if(dataout_ready) state_next = WR_STA_125; else state_next = WR_STA_124; end
        WR_STA_125:begin     if(dataout_ready) state_next = WR_STA_126; else state_next = WR_STA_125; end
        WR_STA_126:begin     if(dataout_ready) state_next = WR_STA_127; else state_next = WR_STA_126; end
        WR_STA_127:begin     if(dataout_ready) state_next = WR_STA_128; else state_next = WR_STA_127; end
        WR_STA_128:begin     if(dataout_ready) state_next = WR_STA_129; else state_next = WR_STA_128; end
        WR_STA_129:begin     if(dataout_ready) state_next = WR_STA_130; else state_next = WR_STA_129; end
        WR_STA_130:begin     if(dataout_ready) state_next = WR_STA_131; else state_next = WR_STA_130; end
        WR_STA_131:begin     if(dataout_ready) state_next = WR_STA_132; else state_next = WR_STA_131; end
        WR_STA_132:begin     if(dataout_ready) state_next = WR_STA_133; else state_next = WR_STA_132; end
        WR_STA_133  :begin     if(dataout_ready)
                                if(w_rd_data == 8'd02 | w_rd_data == 8'd06 )
                                    state_next = WR_STA_134;
                                else
                                    state_next = WR_STA_134;
                              else
                                 state_next = WR_STA_133  ; end
        WR_STA_134:begin     if(dataout_ready) state_next = WR_STA_135; else state_next = WR_STA_134; end
        WR_STA_135:begin     if(dataout_ready) state_next = WR_STA_136; else state_next = WR_STA_135; end
        WR_STA_136:begin     if(dataout_ready) state_next = WR_STA_137; else state_next = WR_STA_136; end
        WR_STA_137:begin     if(dataout_ready) state_next = END; else state_next = WR_STA_137; end
        END : begin state_next = IDLE; end
    endcase
end


always@ (posedge clk_in) begin
    if(!rst_n) begin
       datain_ready <= 1'b0;
       dataout_valid <= 1'b0;
       r_delay_cnt <= 32'd0;
    end
    else begin
        case(state_cur)
                IDLE : begin  dataout_valid <= 1'b0; datain_ready <= 1'b1; end
                START : begin dataout_valid <= 1'b1; datain_ready <= 1'b0; end
                WAIT_GAP : begin dataout_valid <= dataout_valid; datain_ready <= datain_ready; end
                WR_STA_0   : begin r_wr_infodata <= {3'b0,13'h0000,8'h80}; r_wrrd_mode_sel <= SPI_WRITE_MODE;end  //3-wire spi
                WR_STA_1   : begin r_wr_infodata <= {3'b0,13'h0000,8'h00}; end
                WR_STA_2   : begin r_wr_infodata <= {3'b0,13'h0002,8'h00}; end
                WR_STA_3   : begin r_wr_infodata <= {3'b0,13'h0003,8'h06}; end
                WR_STA_4   : begin r_wr_infodata <= {3'b0,13'h0004,8'hD0}; end
                WR_STA_5   : begin r_wr_infodata <= {3'b0,13'h0005,8'h5B}; end
                WR_STA_6   : begin r_wr_infodata <= {3'b0,13'h0006,8'h00}; end
                WR_STA_7   : begin r_wr_infodata <= {3'b0,13'h000C,8'h51}; end
                WR_STA_8   : begin r_wr_infodata <= {3'b0,13'h000D,8'h04}; end
                WR_STA_9   : begin r_wr_infodata <= {3'b0,13'h0100,8'h18}; end  //refclk = 125M
                WR_STA_10  : begin r_wr_infodata <= {3'b0,13'h0101,8'h55}; end
                WR_STA_11  : begin r_wr_infodata <= {3'b0,13'h0102,8'h55}; end
                WR_STA_12  : begin r_wr_infodata <= {3'b0,13'h0103,8'h01}; end
                WR_STA_13  : begin r_wr_infodata <= {3'b0,13'h0104,8'h20}; end
                WR_STA_14  : begin r_wr_infodata <= {3'b0,13'h0105,8'h00}; end
                WR_STA_15  : begin r_wr_infodata <= {3'b0,13'h0106,8'h70}; end
                WR_STA_16  : begin r_wr_infodata <= {3'b0,13'h0107,8'h11}; end
                WR_STA_17  : begin r_wr_infodata <= {3'b0,13'h0108,8'h0C}; end
                WR_STA_18  : begin r_wr_infodata <= {3'b0,13'h0109,8'h55}; end
                WR_STA_19  : begin r_wr_infodata <= {3'b0,13'h010A,8'h55}; end
                WR_STA_20  : begin r_wr_infodata <= {3'b0,13'h010B,8'h00}; end
                WR_STA_21  : begin r_wr_infodata <= {3'b0,13'h010C,8'h02}; end
                WR_STA_22  : begin r_wr_infodata <= {3'b0,13'h010D,8'h00}; end
                WR_STA_23  : begin r_wr_infodata <= {3'b0,13'h010E,8'h79}; end
                WR_STA_24  : begin r_wr_infodata <= {3'b0,13'h010F,8'h05}; end
                WR_STA_25  : begin r_wr_infodata <= {3'b0,13'h0110,8'h08}; end
                WR_STA_26  : begin r_wr_infodata <= {3'b0,13'h0111,8'h55}; end
                WR_STA_27  : begin r_wr_infodata <= {3'b0,13'h0112,8'h55}; end
                WR_STA_28  : begin r_wr_infodata <= {3'b0,13'h0113,8'h00}; end
                WR_STA_29  : begin r_wr_infodata <= {3'b0,13'h0114,8'h02}; end
                WR_STA_30  : begin r_wr_infodata <= {3'b0,13'h0115,8'h00}; end
                WR_STA_31  : begin r_wr_infodata <= {3'b0,13'h0116,8'hF9}; end
                WR_STA_32  : begin r_wr_infodata <= {3'b0,13'h0117,8'h00}; end
                WR_STA_33  : begin r_wr_infodata <= {3'b0,13'h0118,8'h18}; end
                WR_STA_34  : begin r_wr_infodata <= {3'b0,13'h0119,8'h55}; end
                WR_STA_35  : begin r_wr_infodata <= {3'b0,13'h011A,8'h55}; end
                WR_STA_36  : begin r_wr_infodata <= {3'b0,13'h011B,8'h00}; end
                WR_STA_37  : begin r_wr_infodata <= {3'b0,13'h011C,8'h02}; end
                WR_STA_38  : begin r_wr_infodata <= {3'b0,13'h011D,8'h00}; end
                WR_STA_39  : begin r_wr_infodata <= {3'b0,13'h011E,8'h79}; end
                WR_STA_40  : begin r_wr_infodata <= {3'b0,13'h011F,8'h33}; end
                WR_STA_41  : begin r_wr_infodata <= {3'b0,13'h0120,8'h06}; end
                WR_STA_42  : begin r_wr_infodata <= {3'b0,13'h0121,8'h55}; end
                WR_STA_43  : begin r_wr_infodata <= {3'b0,13'h0122,8'h55}; end
                WR_STA_44  : begin r_wr_infodata <= {3'b0,13'h0123,8'h01}; end
                WR_STA_45  : begin r_wr_infodata <= {3'b0,13'h0124,8'h22}; end
                WR_STA_46  : begin r_wr_infodata <= {3'b0,13'h0125,8'h00}; end
                WR_STA_47  : begin r_wr_infodata <= {3'b0,13'h0126,8'h70}; end
                WR_STA_48  : begin r_wr_infodata <= {3'b0,13'h0127,8'h16}; end
                WR_STA_49  : begin r_wr_infodata <= {3'b0,13'h0128,8'h0C}; end
                WR_STA_50  : begin r_wr_infodata <= {3'b0,13'h0129,8'h55}; end
                WR_STA_51  : begin r_wr_infodata <= {3'b0,13'h012A,8'h55}; end
                WR_STA_52  : begin r_wr_infodata <= {3'b0,13'h012B,8'h01}; end
                WR_STA_53  : begin r_wr_infodata <= {3'b0,13'h012C,8'h22}; end
                WR_STA_54  : begin r_wr_infodata <= {3'b0,13'h012D,8'h00}; end
                WR_STA_55  : begin r_wr_infodata <= {3'b0,13'h012E,8'h70}; end
                WR_STA_56  : begin r_wr_infodata <= {3'b0,13'h012F,8'h16}; end
                WR_STA_57  : begin r_wr_infodata <= {3'b0,13'h0130,8'h18}; end
                WR_STA_58  : begin r_wr_infodata <= {3'b0,13'h0131,8'h55}; end
                WR_STA_59  : begin r_wr_infodata <= {3'b0,13'h0132,8'h55}; end
                WR_STA_60  : begin r_wr_infodata <= {3'b0,13'h0133,8'h01}; end
                WR_STA_61  : begin r_wr_infodata <= {3'b0,13'h0134,8'h22}; end
                WR_STA_62  : begin r_wr_infodata <= {3'b0,13'h0135,8'h00}; end
                WR_STA_63  : begin r_wr_infodata <= {3'b0,13'h0136,8'h70}; end
                WR_STA_64  : begin r_wr_infodata <= {3'b0,13'h0137,8'h11}; end
                WR_STA_65  : begin r_wr_infodata <= {3'b0,13'h0138,8'h20}; end
                WR_STA_66  : begin r_wr_infodata <= {3'b0,13'h0139,8'h03}; end
                WR_STA_67  : begin r_wr_infodata <= {3'b0,13'h013A,8'h03}; end
                WR_STA_68  : begin r_wr_infodata <= {3'b0,13'h013B,8'h00}; end  // sysref=3.90625M
                WR_STA_69  : begin r_wr_infodata <= {3'b0,13'h013C,8'h00}; end
                WR_STA_70  : begin r_wr_infodata <= {3'b0,13'h013D,8'h08}; end
                WR_STA_71  : begin r_wr_infodata <= {3'b0,13'h013E,8'h03}; end
                WR_STA_72  : begin r_wr_infodata <= {3'b0,13'h013F,8'h06}; end
                WR_STA_73  : begin r_wr_infodata <= {3'b0,13'h0140,8'h81}; end
                WR_STA_74  : begin r_wr_infodata <= {3'b0,13'h0141,8'h00}; end
                WR_STA_75  : begin r_wr_infodata <= {3'b0,13'h0142,8'h00}; end
                WR_STA_76  : begin r_wr_infodata <= {3'b0,13'h0143,8'h01}; end
                WR_STA_77  : begin r_wr_infodata <= {3'b0,13'h0144,8'hFB}; end
                WR_STA_78  : begin r_wr_infodata <= {3'b0,13'h0145,8'h7F}; end
                WR_STA_79  : begin r_wr_infodata <= {3'b0,13'h0146,8'h03}; end
                WR_STA_80  : begin r_wr_infodata <= {3'b0,13'h0147,8'h17}; end
                WR_STA_81  : begin r_wr_infodata <= {3'b0,13'h0148,8'h00}; end
                WR_STA_82  : begin r_wr_infodata <= {3'b0,13'h0149,8'h40}; end
                WR_STA_83  : begin r_wr_infodata <= {3'b0,13'h014A,8'h02}; end
                WR_STA_84  : begin r_wr_infodata <= {3'b0,13'h014B,8'h16}; end
                WR_STA_85  : begin r_wr_infodata <= {3'b0,13'h014C,8'h00}; end
                WR_STA_86  : begin r_wr_infodata <= {3'b0,13'h014D,8'h00}; end
                WR_STA_87  : begin r_wr_infodata <= {3'b0,13'h014E,8'hC0}; end
                WR_STA_88  : begin r_wr_infodata <= {3'b0,13'h014F,8'h7F}; end
                WR_STA_89  : begin r_wr_infodata <= {3'b0,13'h0150,8'h03}; end
                WR_STA_90  : begin r_wr_infodata <= {3'b0,13'h0151,8'h02}; end
                WR_STA_91  : begin r_wr_infodata <= {3'b0,13'h0152,8'h00}; end
                WR_STA_92  : begin r_wr_infodata <= {3'b0,13'h0153,8'h00}; end
                WR_STA_93  : begin r_wr_infodata <= {3'b0,13'h0154,8'h01}; end
                WR_STA_94  : begin r_wr_infodata <= {3'b0,13'h0155,8'h00}; end
                WR_STA_95  : begin r_wr_infodata <= {3'b0,13'h0156,8'h01}; end
                WR_STA_96  : begin r_wr_infodata <= {3'b0,13'h0157,8'h00}; end
                WR_STA_97  : begin r_wr_infodata <= {3'b0,13'h0158,8'h96}; end
                WR_STA_98  : begin r_wr_infodata <= {3'b0,13'h0159,8'h00}; end
                WR_STA_99  : begin r_wr_infodata <= {3'b0,13'h015A,8'h05}; end
                WR_STA_100 : begin r_wr_infodata <= {3'b0,13'h015B,8'hD4}; end
                WR_STA_101 : begin r_wr_infodata <= {3'b0,13'h015C,8'h20}; end
                WR_STA_102 : begin r_wr_infodata <= {3'b0,13'h015D,8'h00}; end
                WR_STA_103 : begin r_wr_infodata <= {3'b0,13'h015E,8'h00}; end
                WR_STA_104 : begin r_wr_infodata <= {3'b0,13'h015F,8'h13}; end
                WR_STA_105 : begin r_wr_infodata <= {3'b0,13'h0160,8'h00}; end
                WR_STA_106 : begin r_wr_infodata <= {3'b0,13'h0161,8'h01}; end
                WR_STA_107 : begin r_wr_infodata <= {3'b0,13'h0162,8'hA4}; end
                WR_STA_108 : begin r_wr_infodata <= {3'b0,13'h0163,8'h00}; end
                WR_STA_109 : begin r_wr_infodata <= {3'b0,13'h0164,8'h00}; end
                WR_STA_110 : begin r_wr_infodata <= {3'b0,13'h0165,8'h0A}; end
                WR_STA_111 : begin r_wr_infodata <= {3'b0,13'h0171,8'hAA}; end
                WR_STA_112 : begin r_wr_infodata <= {3'b0,13'h0172,8'h02}; end
                WR_STA_113 : begin r_wr_infodata <= {3'b0,13'h017C,8'h15}; end
                WR_STA_114 : begin r_wr_infodata <= {3'b0,13'h017D,8'h33}; end
                WR_STA_115 : begin r_wr_infodata <= {3'b0,13'h0166,8'h00}; end
                WR_STA_116 : begin r_wr_infodata <= {3'b0,13'h0167,8'h00}; end
                WR_STA_117 : begin r_wr_infodata <= {3'b0,13'h0168,8'h0C}; end
                WR_STA_118 : begin r_wr_infodata <= {3'b0,13'h0169,8'h59}; end
                WR_STA_119 : begin r_wr_infodata <= {3'b0,13'h016A,8'h20}; end
                WR_STA_120 : begin r_wr_infodata <= {3'b0,13'h016B,8'h00}; end
                WR_STA_121 : begin r_wr_infodata <= {3'b0,13'h016C,8'h00}; end
                WR_STA_122 : begin r_wr_infodata <= {3'b0,13'h016D,8'h00}; end
                WR_STA_123 : begin r_wr_infodata <= {3'b0,13'h016E,8'h13}; end
                WR_STA_124 : begin r_wr_infodata <= {3'b0,13'h0173,8'h00}; end
                WR_STA_125 : begin r_wr_infodata <= {3'b0,13'h0182,8'h00}; end
                WR_STA_126 : begin r_wr_infodata <= {3'b0,13'h0183,8'h00}; end
                WR_STA_127 : begin r_wr_infodata <= {3'b0,13'h0184,8'h00}; end
                WR_STA_128 : begin r_wr_infodata <= {3'b0,13'h0185,8'h00}; end
                WR_STA_129 : begin r_wr_infodata <= {3'b0,13'h0188,8'h00}; end
                WR_STA_130 : begin r_wr_infodata <= {3'b0,13'h0189,8'h00}; end
                WR_STA_131 : begin r_wr_infodata <= {3'b0,13'h018A,8'h00}; end
                WR_STA_132 : begin r_wr_infodata <= {3'b0,13'h018B,8'h00}; end
                WR_STA_133 : begin r_rd_info <= {3'b100,13'h183}; r_wrrd_mode_sel <= SPI_READ_MODE; end
                WR_STA_134 : begin r_wr_infodata <= {3'b0,13'h144,8'hFF};  r_wrrd_mode_sel <= SPI_WRITE_MODE; end
                WR_STA_135 : begin r_wr_infodata <= {3'b0,13'h143,8'h51}; end
                WR_STA_136 : begin r_wr_infodata <= {3'b0,13'h143,8'h11}; end
                WR_STA_137 : begin r_wr_infodata <= {3'b0,13'h139,8'h03}; end
                END : begin dataout_valid <= 1'b0; datain_ready <= 1'b0; end
            endcase
        end
end

assign o_lmk_rst = 1'b0;  // LMK04828: board has inverter, 0 = deasserted

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
                    .o_cs_n(o_cs_n),
                    .i_delay_cnt(0),
                    .datain_valid (dataout_valid),
                    .datain_ready (dataout_ready),
                    .r_sclk(r_sclk_test),
                    .hold_save_read(w_hold_save_read)
               );
//myila_spi myila_lmk_spi_inst (
//	.clk(clk_in), // input wire clk

//	.probe0(o_sclk), // input wire [0:0]  probe0
//	.probe1(o_cs_n), // input wire [0:0]  probe1
//	.probe2(io_sda), // input wire [0:0]  probe2
//	.probe3(w_sda_dir), // input wire [0:0]  probe3
//	.probe4(state_cur), // input wire [7:0]  probe4
//	.probe5({8'b0, w_rd_data}),
//	.probe6(r_sclk_test), // input wire [7:0]  probe4
//	.probe7(w_hold_save_read)

//	);// input wire [7:0]  probe5


endmodule
