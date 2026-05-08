`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2022/07/31 08:40:55
// Design Name: 
// Module Name: ad9144_spi_config_v2
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
module ad9144_spi_config(
                        input clk_in,
                        input rst_n,
                        
                        output o_sclk,
                        output o_sen_n,
                        output reg o_reset,
                        
                        inout io_sda,
                        input datain_valid,
                        output reg datain_ready
                        ); 
localparam IDLE            = 10'd0  ;
localparam START           = 10'd1  ;
localparam PRE_REST_H      = 10'd2  ;
localparam PRE_REST_L      = 10'd3  ;
localparam WAIT_GAP        = 10'd4  ;
localparam WR_STA_0        = 10'd5  ;
localparam WR_STA_1        = 10'd6  ;
localparam WR_STA_2        = 10'd7  ;
localparam WR_STA_3        = 10'd8  ;
localparam WR_STA_4        = 10'd9  ;
localparam WR_STA_5        = 10'd10 ;
localparam WR_STA_6        = 10'd11 ;
localparam WR_STA_7        = 10'd12 ;
localparam WR_STA_8        = 10'd13 ;
localparam WR_STA_9        = 10'd14 ;
localparam WR_STA_10       = 10'd15 ;
localparam WR_STA_11       = 10'd16 ;
localparam WR_STA_12       = 10'd17 ;
localparam WR_STA_13       = 10'd18 ;
localparam WR_STA_14       = 10'd19 ;
localparam WR_STA_15       = 10'd20 ;
localparam WR_STA_16       = 10'd21 ;
localparam WR_STA_17       = 10'd22 ;
localparam WR_STA_18       = 10'd23 ;
localparam WR_STA_19       = 10'd24 ;
localparam WR_STA_20       = 10'd25 ;
localparam WR_STA_21       = 10'd26 ;  
localparam WR_STA_22       = 10'd27 ;
localparam WR_STA_23       = 10'd28 ;
localparam WR_STA_24       = 10'd29 ;
localparam WR_STA_25       = 10'd30 ;
localparam WR_STA_26       = 10'd31 ;
localparam WR_STA_27       = 10'd32 ;
localparam WR_STA_28       = 10'd33 ;
localparam WR_STA_29       = 10'd34 ;
localparam WR_STA_30       = 10'd35 ;
localparam WR_STA_31       = 10'd36 ;
localparam WR_STA_32       = 10'd37 ;
localparam WR_STA_33       = 10'd38 ;
localparam WR_STA_34       = 10'd39 ;
localparam WR_STA_35       = 10'd40 ;
localparam WR_STA_36       = 10'd41 ;      
localparam WR_STA_37       = 10'd42 ;      
localparam WR_STA_38       = 10'd43 ;      
localparam WR_STA_39       = 10'd44 ;      
localparam WR_STA_40       = 10'd45 ;      
localparam WR_STA_41       = 10'd46 ;      
localparam WR_STA_42       = 10'd47 ;      
localparam WR_STA_43       = 10'd48 ;      
localparam WR_STA_44       = 10'd49 ;      
localparam WR_STA_45       = 10'd50 ;
localparam WR_STA_46       = 10'd51 ;
localparam WR_STA_47       = 10'd52 ;
localparam WR_STA_48       = 10'd53 ;
localparam WR_STA_49       = 10'd54 ;
localparam WR_STA_50       = 10'd55 ;      
localparam WR_STA_51       = 10'd56 ;      
localparam WR_STA_52       = 10'd57 ;      
localparam WR_STA_53       = 10'd58 ;      
localparam WR_STA_54       = 10'd59 ;      
localparam WR_STA_55       = 10'd60 ;
localparam WR_STA_56       = 10'd61 ;
localparam WR_STA_57       = 10'd62 ;
localparam WR_STA_58       = 10'd63 ;
localparam WR_STA_59       = 10'd64 ;
localparam WR_STA_60       = 10'd65 ;      
localparam WR_STA_61       = 10'd66 ;      
localparam WR_STA_62       = 10'd67 ;      
localparam WR_STA_63       = 10'd68 ;      
localparam WR_STA_64       = 10'd69 ;      
localparam WR_STA_65       = 10'd70 ;
localparam WR_STA_66       = 10'd71 ;
localparam WR_STA_67       = 10'd72 ;
localparam WR_STA_68       = 10'd73 ;
localparam WR_STA_69       = 10'd74 ;
localparam WR_STA_70       = 10'd75 ;      
localparam WR_STA_71       = 10'd76 ;      
localparam WR_STA_72       = 10'd77 ;      
localparam WR_STA_73       = 10'd78 ;      
localparam WR_STA_74       = 10'd79 ;      
localparam WR_STA_75       = 10'd80 ;
localparam WR_STA_76       = 10'd81 ;
localparam WR_STA_77       = 10'd82 ;
localparam WR_STA_78       = 10'd83 ;
localparam WR_STA_79       = 10'd84 ;
localparam WR_STA_80       = 10'd85 ;      
localparam WR_STA_81       = 10'd86 ;      
localparam WR_STA_82       = 10'd87 ;      
localparam WR_STA_83       = 10'd88 ;      
localparam WR_STA_84       = 10'd89 ;      
localparam WR_STA_85       = 10'd90 ;
localparam WR_STA_86       = 10'd91 ;
localparam WR_STA_87       = 10'd92 ;
localparam WR_STA_88       = 10'd93 ;
localparam WR_STA_89       = 10'd94 ;
localparam WR_STA_90       = 10'd95 ;      
localparam WR_STA_91       = 10'd96 ;      
localparam WR_STA_92       = 10'd97 ;      
localparam WR_STA_93       = 10'd98 ;      
localparam WR_STA_94       = 10'd99 ;      
localparam WR_STA_95       = 10'd100;
localparam WR_STA_96       = 10'd101;
localparam WR_STA_97       = 10'd102;
localparam WR_STA_98       = 10'd103;
localparam WR_STA_99       = 10'd104;
localparam WR_STA_100      = 10'd105;        
localparam WR_STA_101      = 10'd106;        
localparam WR_STA_102      = 10'd107;        
localparam WR_STA_103      = 10'd108;        
localparam WR_STA_104      = 10'd109;        
localparam WR_STA_105      = 10'd110; 
localparam WR_STA_106      = 10'd111; 
localparam WR_STA_107      = 10'd112; 
localparam WR_STA_108      = 10'd113; 
localparam WR_STA_109      = 10'd114; 
localparam WR_STA_110      = 10'd115; 
localparam WR_STA_111      = 10'd116; 
localparam WR_STA_112      = 10'd117; 
localparam WR_STA_113      = 10'd118; 
localparam WR_STA_114      = 10'd119; 
localparam WR_STA_115      = 10'd120; 
localparam WR_STA_116      = 10'd121; 
localparam WR_STA_117      = 10'd122; 
localparam WR_STA_118      = 10'd123; 
localparam WR_STA_119      = 10'd124; 
localparam WR_STA_120      = 10'd125; 
localparam WR_STA_121      = 10'd126; 
localparam WR_STA_122      = 10'd127;  
localparam WR_STA_123      = 10'd128; 
localparam WR_STA_124      = 10'd129; 
localparam WR_STA_125      = 10'd130; 
localparam WR_STA_126      = 10'd131; 
localparam WR_STA_127      = 10'd132; 
localparam WR_STA_128      = 10'd133; 
localparam WR_STA_129      = 10'd134; 
localparam WR_STA_130      = 10'd135; 
localparam WR_STA_131      = 10'd136; 
localparam WR_STA_132      = 10'd137;    
localparam WR_STA_133      = 10'd138; 
localparam WR_STA_134      = 10'd139; 
localparam WR_STA_135      = 10'd140; 
localparam WR_STA_136      = 10'd141; 
localparam WR_STA_137      = 10'd142; 
localparam END  = 10'd143; 
localparam SPI_WRITE_MODE  = 2'b00;       
localparam SPI_READ_MODE  = 2'b01;    
localparam SPI_DELAY_MODE  = 2'b10;       
    
reg dataout_valid;
reg delay_timer_valid;
reg[9:0] state_cur = 10'd0;
reg[9:0] state_next = 10'd0;

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
        IDLE :     begin if(datain_valid) state_next = PRE_REST_L; else state_next = IDLE; end
        PRE_REST_L:  begin     if(rst_delay_cnt == 32'd10000) state_next = PRE_REST_H; else state_next = PRE_REST_L; end
        PRE_REST_H:  begin     if(rst_delay_cnt == 32'd30000) state_next = START; else state_next = PRE_REST_H; end
        START :    begin     if(dataout_ready) state_next = WAIT_GAP; else state_next = START;   end
        WAIT_GAP : begin    if(dataout_ready) state_next = WR_STA_0; else state_next = WAIT_GAP;   end               
        WR_STA_0   :begin     if(dataout_ready) state_next = WR_STA_1  ; else state_next = WR_STA_0   ; end
        WR_STA_1   :begin     if(dataout_ready) state_next = WR_STA_2  ; else state_next = WR_STA_1   ; end
        WR_STA_2   :begin     if(dataout_ready) state_next = WR_STA_3  ; else state_next = WR_STA_2   ; end
        WR_STA_3   :begin     if(dataout_ready) state_next = WR_STA_4  ; else state_next = WR_STA_3   ; end
        WR_STA_4   :begin     if(dataout_ready) state_next = WR_STA_5  ; else state_next = WR_STA_4   ; end
        WR_STA_5   :begin     if(dataout_ready) state_next = WR_STA_6  ; else state_next = WR_STA_5   ; end
        WR_STA_6   :begin     if(dataout_ready) state_next = WR_STA_7  ; else state_next = WR_STA_6   ; end
        WR_STA_7   :begin     if(dataout_ready) state_next = WR_STA_8  ; else state_next = WR_STA_7   ; end
        WR_STA_8   :begin     if(dataout_ready) state_next = WR_STA_9  ; else state_next = WR_STA_8   ; end
        WR_STA_9   :begin     if(dataout_ready) state_next = WR_STA_10 ; else state_next = WR_STA_9   ; end
        WR_STA_10  :begin     if(dataout_ready) state_next = WR_STA_11 ; else state_next = WR_STA_10  ; end
        WR_STA_11  :begin     if(dataout_ready) state_next = WR_STA_12 ; else state_next = WR_STA_11  ; end
        WR_STA_12  :begin     if(dataout_ready) state_next = WR_STA_13 ; else state_next = WR_STA_12  ; end
        WR_STA_13  :begin     if(dataout_ready) state_next = WR_STA_14 ; else state_next = WR_STA_13  ; end
        WR_STA_14  :begin     if(dataout_ready) state_next = WR_STA_15 ; else state_next = WR_STA_14  ; end            
        WR_STA_15  :begin     if(dataout_ready) state_next = WR_STA_16 ; else state_next = WR_STA_15  ; end
        WR_STA_16  :begin     if(dataout_ready) state_next = WR_STA_17 ; else state_next = WR_STA_16  ; end        
        WR_STA_17  :begin     if(dataout_ready) state_next = WR_STA_18 ; else state_next = WR_STA_17  ; end        
        WR_STA_18  :begin     if(dataout_ready) state_next = WR_STA_19 ; else state_next = WR_STA_18  ; end        
        WR_STA_19  :begin     if(dataout_ready) state_next = WR_STA_20 ; else state_next = WR_STA_19  ; end  
        WR_STA_20  :begin     if(dataout_ready) state_next = WR_STA_21 ; else state_next = WR_STA_20  ; end        
        WR_STA_21  :begin     if(dataout_ready) state_next = WR_STA_22 ; else state_next = WR_STA_21  ; end     
        WR_STA_22  :begin     if(dataout_ready) state_next = WR_STA_23 ; else state_next = WR_STA_22  ; end        
        WR_STA_23  :begin     if(dataout_ready) state_next = WR_STA_24 ; else state_next = WR_STA_23  ; end  
        WR_STA_24  :begin     if(dataout_ready) state_next = WR_STA_25 ; else state_next = WR_STA_24  ; end  
        WR_STA_25  :begin     if(dataout_ready) state_next = WR_STA_26 ; else state_next = WR_STA_25  ; end    
        WR_STA_26  :begin     if(dataout_ready) state_next = WR_STA_27 ; else state_next = WR_STA_26  ; end       
        WR_STA_27  :begin     if(dataout_ready) state_next = WR_STA_28 ; else state_next = WR_STA_27  ; end        
        WR_STA_28  :begin     if(dataout_ready) state_next = WR_STA_29 ; else state_next = WR_STA_28  ; end  
        WR_STA_29  :begin     if(dataout_ready) state_next = WR_STA_30 ; else state_next = WR_STA_29  ; end 
        WR_STA_30  :begin     if(dataout_ready) state_next = WR_STA_31 ; else state_next = WR_STA_30  ; end 
        WR_STA_31  :begin     if(dataout_ready) state_next = WR_STA_32 ; else state_next = WR_STA_31  ; end 
        WR_STA_32  :begin     if(dataout_ready) state_next = WR_STA_33 ; else state_next = WR_STA_32  ; end 
        WR_STA_33  :begin     if(dataout_ready) state_next = WR_STA_34 ; else state_next = WR_STA_33  ; end   
        WR_STA_34  :begin     if(dataout_ready) state_next = WR_STA_35 ; else state_next = WR_STA_34  ; end 
        WR_STA_35  :begin     if(dataout_ready) state_next = WR_STA_36 ; else state_next = WR_STA_35  ; end 
        WR_STA_36  :begin     if(dataout_ready) state_next = WR_STA_37 ; else state_next = WR_STA_36  ; end
        WR_STA_37  :begin     if(dataout_ready) state_next = WR_STA_38 ; else state_next = WR_STA_37  ; end
        WR_STA_38  :begin     if(dataout_ready) state_next = WR_STA_39 ; else state_next = WR_STA_38  ; end
        WR_STA_39  :begin     if(dataout_ready) state_next = WR_STA_40 ; else state_next = WR_STA_39  ; end
        WR_STA_40  :begin     if(dataout_ready) state_next = WR_STA_41 ; else state_next = WR_STA_40  ; end
        WR_STA_41  :begin     if(dataout_ready) state_next = WR_STA_42 ; else state_next = WR_STA_41  ; end
        WR_STA_42  :begin     if(dataout_ready) state_next = WR_STA_43 ; else state_next = WR_STA_42  ; end
        WR_STA_43  :begin     if(dataout_ready) state_next = WR_STA_44 ; else state_next = WR_STA_43  ; end
        WR_STA_44  :begin     if(dataout_ready) state_next = WR_STA_45 ; else state_next = WR_STA_44  ; end
        WR_STA_45  :begin     if(dataout_ready) state_next = WR_STA_46 ; else state_next = WR_STA_45  ; end
        WR_STA_46  :begin     if(dataout_ready) state_next = WR_STA_47 ; else state_next = WR_STA_46  ; end
        WR_STA_47  :begin     if(dataout_ready) state_next = WR_STA_48 ; else state_next = WR_STA_47  ; end
        WR_STA_48  :begin     if(dataout_ready) state_next = WR_STA_49 ; else state_next = WR_STA_48  ; end
        WR_STA_49  :begin     if(dataout_ready) state_next = WR_STA_50 ; else state_next = WR_STA_49  ; end
        WR_STA_50  :begin     if(dataout_ready) state_next = WR_STA_51 ; else state_next = WR_STA_50  ; end
        WR_STA_51  :begin     if(dataout_ready) state_next = WR_STA_52 ; else state_next = WR_STA_51  ; end            
        WR_STA_52  :begin     if(dataout_ready) state_next = WR_STA_53 ; else state_next = WR_STA_52  ; end
        WR_STA_53  :begin     if(dataout_ready) state_next = WR_STA_54 ; else state_next = WR_STA_53  ; end        
        WR_STA_54  :begin     if(dataout_ready) state_next = WR_STA_55 ; else state_next = WR_STA_54  ; end        
        WR_STA_55  :begin     if(dataout_ready) state_next = WR_STA_56 ; else state_next = WR_STA_55  ; end        
        WR_STA_56  :begin     if(dataout_ready) state_next = WR_STA_57 ; else state_next = WR_STA_56  ; end  
        WR_STA_57  :begin     if(dataout_ready) state_next = WR_STA_58 ; else state_next = WR_STA_57  ; end        
        WR_STA_58  :begin     if(dataout_ready) state_next = WR_STA_59 ; else state_next = WR_STA_58  ; end     
        WR_STA_59  :begin     if(dataout_ready) state_next = WR_STA_60 ; else state_next = WR_STA_59  ; end        
        WR_STA_60  :begin     if(dataout_ready) state_next = WR_STA_61 ; else state_next = WR_STA_60  ; end  
        WR_STA_61  :begin     if(dataout_ready) state_next = WR_STA_62 ; else state_next = WR_STA_61  ; end  
        WR_STA_62  :begin     if(dataout_ready) state_next = WR_STA_63 ; else state_next = WR_STA_62  ; end    
        WR_STA_63  :begin     if(dataout_ready) state_next = WR_STA_64 ; else state_next = WR_STA_63  ; end       
        WR_STA_64  :begin     if(dataout_ready) state_next = WR_STA_65 ; else state_next = WR_STA_64  ; end        
        WR_STA_65  :begin     if(dataout_ready) state_next = WR_STA_66 ; else state_next = WR_STA_65  ; end  
        WR_STA_66  :begin     if(dataout_ready) state_next = WR_STA_67 ; else state_next = WR_STA_66  ; end 
        WR_STA_67  :begin     if(dataout_ready) state_next = WR_STA_68 ; else state_next = WR_STA_67  ; end 
        WR_STA_68  :begin     if(dataout_ready) state_next = WR_STA_69 ; else state_next = WR_STA_68  ; end 
        WR_STA_69  :begin     if(dataout_ready) state_next = WR_STA_70 ; else state_next = WR_STA_69  ; end 
        WR_STA_70  :begin     if(dataout_ready) state_next = WR_STA_71 ; else state_next = WR_STA_70  ; end 
        WR_STA_71  :begin     if(dataout_ready) state_next = WR_STA_72 ; else state_next = WR_STA_71  ; end 
        WR_STA_72  :begin     if(dataout_ready) state_next = WR_STA_73 ; else state_next = WR_STA_72  ; end 
        WR_STA_73  :begin     if(dataout_ready) state_next = WR_STA_74 ; else state_next = WR_STA_73  ; end 
        WR_STA_74  :begin     if(dataout_ready) state_next = WR_STA_75 ; else state_next = WR_STA_74  ; end        
        WR_STA_75  :begin     if(dataout_ready) state_next = WR_STA_76 ; else state_next = WR_STA_75  ; end  
        WR_STA_76  :begin     if(dataout_ready) state_next = WR_STA_77 ; else state_next = WR_STA_76  ; end 
        WR_STA_77  :begin     if(dataout_ready) state_next = WR_STA_78 ; else state_next = WR_STA_77  ; end 
        WR_STA_78  :begin     if(dataout_ready) state_next = WR_STA_79 ; else state_next = WR_STA_78  ; end 
        WR_STA_79  :begin     if(dataout_ready) state_next = WR_STA_80 ; else state_next = WR_STA_79  ; end 
        WR_STA_80  :begin     if(dataout_ready) state_next = WR_STA_81 ; else state_next = WR_STA_80  ; end 
        WR_STA_81  :begin     if(dataout_ready) state_next = WR_STA_82 ; else state_next = WR_STA_81  ; end 
        WR_STA_82  :begin     if(dataout_ready) state_next = WR_STA_83 ; else state_next = WR_STA_82  ; end 
        WR_STA_83  :begin     if(dataout_ready) state_next = WR_STA_84 ; else state_next = WR_STA_83  ; end     
        WR_STA_84  :begin     if(dataout_ready) state_next = WR_STA_85 ; else state_next = WR_STA_84  ; end
        WR_STA_85  :begin     if(dataout_ready) state_next = WR_STA_86 ; else state_next = WR_STA_85  ; end 
        WR_STA_86  :begin     if(dataout_ready) state_next = WR_STA_87 ; else state_next = WR_STA_86  ; end 
        WR_STA_87  :begin     if(dataout_ready) state_next = WR_STA_88 ; else state_next = WR_STA_87 ; end 
        WR_STA_88  :begin     if(dataout_ready) state_next = WR_STA_89 ; else state_next = WR_STA_88 ; end 
        WR_STA_89  :begin     if(dataout_ready) state_next = WR_STA_90 ; else state_next = WR_STA_89 ; end 
        WR_STA_90  :begin     if(dataout_ready) state_next = WR_STA_91 ; else state_next = WR_STA_90 ; end 
        WR_STA_91  :begin     if(dataout_ready) state_next = WR_STA_92 ; else state_next = WR_STA_91 ; end        
        WR_STA_92  :begin     if(dataout_ready) state_next = WR_STA_93 ; else state_next = WR_STA_92 ; end  
        WR_STA_93  :begin     if(dataout_ready) state_next = WR_STA_94 ; else state_next = WR_STA_93 ; end 
        WR_STA_94  :begin     if(dataout_ready) state_next = WR_STA_95 ; else state_next = WR_STA_94 ; end 
        WR_STA_95  :begin     if(dataout_ready) state_next = WR_STA_96 ; else state_next = WR_STA_95 ; end 
        WR_STA_96  :begin     if(dataout_ready) state_next = WR_STA_97 ; else state_next = WR_STA_96 ; end 
        WR_STA_97  :begin     if(dataout_ready) state_next = WR_STA_98 ; else state_next = WR_STA_97 ; end 
        WR_STA_98  :begin     if(dataout_ready) 
                                if(w_rd_data[0] == 1'b1)
                                    state_next = WR_STA_99;
                                else
                                    state_next = WR_STA_98;
                              else      
                                 state_next = WR_STA_98  ; end 
        WR_STA_99  :begin     if(dataout_ready) state_next = WR_STA_100; else state_next = WR_STA_99 ; end 
        WR_STA_100 :begin     if(dataout_ready) state_next = WR_STA_101; else state_next = WR_STA_100; end     
        WR_STA_101 :begin     if(dataout_ready) state_next = WR_STA_102; else state_next = WR_STA_101; end
        WR_STA_102 :begin     if(dataout_ready) state_next = WR_STA_103; else state_next = WR_STA_102; end 
        WR_STA_103 :begin     if(dataout_ready) state_next = WR_STA_104; else state_next = WR_STA_103; end
        WR_STA_104 :begin     if(dataout_ready) state_next = WR_STA_105; else state_next = WR_STA_104; end 
        WR_STA_105 :begin     if(dataout_ready) state_next = WR_STA_106; else state_next = WR_STA_105 ; end   
        WR_STA_106 :begin     if(dataout_ready) state_next = WR_STA_107; else state_next = WR_STA_106 ; end
        WR_STA_107 :begin     if(dataout_ready) state_next = WR_STA_108; else state_next = WR_STA_107 ; end
        WR_STA_108 :begin     if(dataout_ready) state_next = WR_STA_109; else state_next = WR_STA_108 ; end
        WR_STA_109 :begin     if(dataout_ready) state_next = WR_STA_110; else state_next = WR_STA_109 ; end
        WR_STA_110 :begin     if(dataout_ready) state_next = WR_STA_111; else state_next = WR_STA_110 ; end
        WR_STA_111 :begin     if(dataout_ready) state_next = WR_STA_112; else state_next = WR_STA_111 ; end
        WR_STA_112 :begin     if(dataout_ready) state_next = WR_STA_113; else state_next = WR_STA_112 ; end
        WR_STA_113 :begin     if(dataout_ready) state_next = WR_STA_114; else state_next = WR_STA_113 ; end
        WR_STA_114 :begin     if(dataout_ready) state_next = WR_STA_115; else state_next = WR_STA_114 ; end
        WR_STA_115 :begin     if(dataout_ready) state_next = WR_STA_116; else state_next = WR_STA_115 ; end   
        WR_STA_116 :begin     if(dataout_ready) state_next = WR_STA_117; else state_next = WR_STA_116 ; end
        WR_STA_117 :begin     if(dataout_ready) state_next = WR_STA_118; else state_next = WR_STA_117 ; end
        WR_STA_118 :begin     if(dataout_ready) state_next = WR_STA_119; else state_next = WR_STA_118 ; end
        WR_STA_119 :begin     if(dataout_ready) state_next = WR_STA_120; else state_next = WR_STA_119 ; end
        WR_STA_120 :begin     if(dataout_ready) state_next = WR_STA_121; else state_next = WR_STA_120 ; end
        WR_STA_121 :begin     if(dataout_ready) state_next = WR_STA_122; else state_next = WR_STA_121 ; end
        WR_STA_122 :begin     if(dataout_ready) state_next = WR_STA_123; else state_next = WR_STA_122 ; end
        WR_STA_123 :begin     if(dataout_ready) state_next = WR_STA_124; else state_next = WR_STA_123 ; end
        WR_STA_124 :begin     if(dataout_ready) state_next = END; else state_next = WR_STA_124 ; end                                                     
        END : begin state_next = IDLE; end                           
    endcase
end
// ad9144 mode = 4, L = 4(lane0~3), M = 2, single link, DAC0 DAC1 output      
// F = 1, K = 32, S = 1, HD = 1, SCR = 1
// 基带数据速率1Gsps，dac速率2Gsps（*2插值 ），线速率10Gbps
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
                    //For spi write: bit23 , bit22~8 : reg address , bit7~0 : reg data   
                WR_STA_0  : begin r_wr_infodata <= {1'b0,15'h000, 8'hA5};  r_wrrd_mode_sel <= SPI_WRITE_MODE;  end  //    reset 
                WR_STA_1  : begin  r_dac_spi_delay_cnt <= 16'd1000;        r_wrrd_mode_sel <= SPI_DELAY_MODE;  end
                WR_STA_2  : begin r_wr_infodata <= {1'b0,15'h000, 8'h24};  r_wrrd_mode_sel <= SPI_WRITE_MODE;  end   //  deassert-reset, spi 3-wire mode
                WR_STA_3  : begin r_wr_infodata <= {1'b0,15'h011, 8'h00};  end   // enable, refenernce ,dac channels and master dac 
                WR_STA_4  : begin r_wr_infodata <= {1'b0,15'h080, 8'h00};  end   // power up all clocks 
                WR_STA_5  : begin r_wr_infodata <= {1'b0,15'h081, 8'h00};  end   // power up sysref receiver, disable sysref hysteresis, DAC clock fall edge to sample sysref
                WR_STA_6  : begin r_wr_infodata <= {1'b0,15'h12D, 8'h8B};  end   // DEVICE_CONFIG_0 must be 0x8B
                WR_STA_7  : begin r_wr_infodata <= {1'b0,15'h146, 8'h01};  end   // DEVICE_CONFIG_1 must be 0x01
                WR_STA_8  : begin r_wr_infodata <= {1'b0,15'h2A4, 8'hFF};  end   // DEVICE_CONFIG_8 must be 0xFF
                WR_STA_9  : begin r_wr_infodata <= {1'b0,15'h232, 8'hFF};  end   // DEVICE_CONFIG_3 must be 0xFF
                WR_STA_10  : begin r_wr_infodata <= {1'b0,15'h333, 8'h01};  end   // DEVICE_CONFIG_13 must be 0x01
                WR_STA_11  : begin r_wr_infodata <= {1'b0,15'h087, 8'h62};  end   // 
                WR_STA_12  : begin r_wr_infodata <= {1'b0,15'h088, 8'hC9};  end   // 
                WR_STA_13  : begin r_wr_infodata <= {1'b0,15'h089, 8'h0E};  end   // 
                WR_STA_14  : begin r_wr_infodata <= {1'b0,15'h08A, 8'h12};  end   // 
                WR_STA_15  : begin r_wr_infodata <= {1'b0,15'h08D, 8'h7B};  end   // 
                WR_STA_16  : begin r_wr_infodata <= {1'b0,15'h1B0, 8'h00};  end   // 
                WR_STA_17  : begin r_wr_infodata <= {1'b0,15'h1B9, 8'h24};  end   // 
                WR_STA_18  : begin r_wr_infodata <= {1'b0,15'h1BC, 8'h0D};  end   //   
                WR_STA_19  : begin r_wr_infodata <= {1'b0,15'h1BE, 8'h02};  end   // 
                WR_STA_20  : begin r_wr_infodata <= {1'b0,15'h1BF, 8'h8E};  end   // 
                WR_STA_21  : begin r_wr_infodata <= {1'b0,15'h1C0, 8'h2A};  end   // 
                WR_STA_22  : begin r_wr_infodata <= {1'b0,15'h1C1, 8'h2A};  end   // 
                WR_STA_23  : begin r_wr_infodata <= {1'b0,15'h1C4, 8'h7E};  end   // 
                WR_STA_24  : begin r_wr_infodata <= {1'b0,15'h08B, 8'h01};  end   //  6G <lo divider = 2^(1+1)= 4 < 12G
                WR_STA_25  : begin r_wr_infodata <= {1'b0,15'h08C, 8'h03};  end   // receference clk div = 8
                WR_STA_26  : begin r_wr_infodata <= {1'b0,15'h085, 8'h10};  end   //  B counter = 16
                WR_STA_27  : begin r_wr_infodata <= {1'b0,15'h1B5, 8'h09};  end   //  pll lookup table.25
                WR_STA_28  : begin r_wr_infodata <= {1'b0,15'h1BB, 8'h13};  end   // pll lookup table.25
                WR_STA_29  : begin r_wr_infodata <= {1'b0,15'h1C5, 8'h06};  end   // pll lookup table.25
                WR_STA_30  : begin r_wr_infodata <= {1'b0,15'h083, 8'h10};  end   //  enable dac pll  
                WR_STA_31  : begin r_wr_infodata <= {1'b0,15'h083, 8'h90};  end   //  enable dac pll
                WR_STA_32  : begin r_wr_infodata <= {1'b0,15'h083, 8'h10};  end   //  enable dac pll 
                WR_STA_33 :  begin r_wr_infodata <= {1'b0,15'h083, 8'h10};  end   //  enable dac pll 
                WR_STA_34  : begin r_wr_infodata <= {1'b0,15'h040, 8'h01};  end   // Dual A I DAC MSB gain code
                WR_STA_35  : begin r_wr_infodata <= {1'b0,15'h041, 8'hFF};  end   // Dual A I DAC LSB gain code  
                WR_STA_36  : begin r_wr_infodata <= {1'b0,15'h042, 8'h01};  end   // Dual A Q DAC MSB gain code
                WR_STA_37  : begin r_wr_infodata <= {1'b0,15'h043, 8'hFF};  end   // Dual A Q DAC LSB gain code 
                WR_STA_38  : begin r_wr_infodata <= {1'b0,15'h044, 8'h01};  end   // Dual B I DAC MSB gain code
                WR_STA_39  : begin r_wr_infodata <= {1'b0,15'h045, 8'hFF};  end   // Dual B I DAC LSB gain code  
                WR_STA_40  : begin r_wr_infodata <= {1'b0,15'h046, 8'h01};  end   // Dual B Q DAC MSB gain code
                WR_STA_41  : begin r_wr_infodata <= {1'b0,15'h047, 8'hFF};  end   // Dual B Q DAC LSB gain code                                                                                     
                WR_STA_42  : begin r_wr_infodata <= {1'b0,15'h112, 8'h01};  end   // Interpolation 2x
                WR_STA_43  : begin r_wr_infodata <= {1'b0,15'h110, 8'h00};  end   // twos-complenment
                WR_STA_44  : begin r_wr_infodata <= {1'b0,15'h111, 8'hA0};  end   //// enable INVSINC filer and digitial gain control
                WR_STA_45  : begin r_wr_infodata <= {1'b0,15'h13C, 8'hEA};  end   // I DAC LSB GainCode
                WR_STA_46  : begin r_wr_infodata <= {1'b0,15'h13D, 8'h08};  end   // I DAC MSB GainCode
                WR_STA_47  : begin r_wr_infodata <= {1'b0,15'h13E, 8'hEA};  end   // Q DAC LSB GainCode
                WR_STA_48  : begin r_wr_infodata <= {1'b0,15'h13F, 8'h08};  end   // Q DAC MSB GainCode
                WR_STA_49  : begin r_wr_infodata <= {1'b0,15'h200, 8'h00};  end   // power up jesd204b interface
                WR_STA_50  : begin r_wr_infodata <= {1'b0,15'h201, 8'h00};  end   // enable all lanes
                WR_STA_51  : begin r_wr_infodata <= {1'b0,15'h300, 8'h00};  end   // checksum reg, single-link mode(use link0)
                WR_STA_52  : begin r_wr_infodata <= {1'b0,15'h450, 8'h00};  end   // set device ID, ILS_DID = 0x00
                WR_STA_53  : begin r_wr_infodata <= {1'b0,15'h451, 8'h00};  end   // set bank ID
                WR_STA_54  : begin r_wr_infodata <= {1'b0,15'h452, 8'h00};  end   // set lane ID
                WR_STA_55  : begin r_wr_infodata <= {1'b0,15'h453, 8'h83};  end   // SCR on, L = 4
                WR_STA_56  : begin r_wr_infodata <= {1'b0,15'h454, 8'h00};  end   // F = 1
                WR_STA_57  : begin r_wr_infodata <= {1'b0,15'h455, 8'h1F};  end   // K = 32
                WR_STA_58  : begin r_wr_infodata <= {1'b0,15'h456, 8'h01};  end   // M = 2 per link
                WR_STA_59  : begin r_wr_infodata <= {1'b0,15'h457, 8'h0F};  end   // CS = 0, N = 16
                WR_STA_60  : begin r_wr_infodata <= {1'b0,15'h458, 8'h2F};  end   // subclass1, NP = 16
                WR_STA_61  : begin r_wr_infodata <= {1'b0,15'h459, 8'h20};  end   // S = 1
                WR_STA_62  : begin r_wr_infodata <= {1'b0,15'h45A, 8'h80};  end   //  HD = 1, CF = 0 
                WR_STA_63  : begin r_wr_infodata <= {1'b0,15'h45D, 8'h45};  end   //  checksum
                WR_STA_64 : begin r_wr_infodata <= {1'b0,15'h46C, 8'h0F};  end   //  deskew link lane0 to lane3
                WR_STA_65 : begin r_wr_infodata <= {1'b0,15'h476, 8'h01};  end   //  F = 1
                WR_STA_66  : begin r_wr_infodata <= {1'b0,15'h47D, 8'h0F};  end   //  enable link lane0 to lane3
                WR_STA_67 : begin r_wr_infodata <= {1'b0,15'h2AA, 8'hB7};  end   
                WR_STA_68 : begin r_wr_infodata <= {1'b0,15'h2AB, 8'h87};  end   // 
                WR_STA_69  : begin r_wr_infodata <= {1'b0,15'h2A7, 8'h01};  end    // cal lane phy 50ohm
                WR_STA_70  : begin r_wr_infodata <= {1'b0,15'h2AE, 8'h01};  end    // cal lane phy 50ohm
                WR_STA_71 : begin r_wr_infodata <= {1'b0,15'h2B1, 8'hB7};  end   // 
                WR_STA_72 : begin r_wr_infodata <= {1'b0,15'h2B2, 8'h87};  end   // 
                WR_STA_73 : begin r_wr_infodata <= {1'b0,15'h2A7, 8'h01};  end   // 
                WR_STA_74 : begin r_wr_infodata <= {1'b0,15'h2AE, 8'h01};  end   // 
                WR_STA_75 : begin r_wr_infodata <= {1'b0,15'h314, 8'h01};  end   // 
                WR_STA_76 : begin r_wr_infodata <= {1'b0,15'h230, 8'h28};  end   //  CDR   lane rate
                WR_STA_77 : begin r_wr_infodata <= {1'b0,15'h206, 8'h00};  end   //  
                WR_STA_78 : begin r_wr_infodata <= {1'b0,15'h206, 8'h01};  end   // 
                WR_STA_79 : begin r_wr_infodata <= {1'b0,15'h289, 8'h04};  end   // serdes pll lane rate 5.75~12.4Gbps
                WR_STA_80 : begin r_wr_infodata <= {1'b0,15'h284, 8'h62};  end   // 
                WR_STA_81 : begin r_wr_infodata <= {1'b0,15'h285, 8'hC9};  end   // 
                WR_STA_82 : begin r_wr_infodata <= {1'b0,15'h286, 8'h0E};  end   // 
                WR_STA_83 : begin r_wr_infodata <= {1'b0,15'h287, 8'h12};  end   // 
                WR_STA_84 : begin r_wr_infodata <= {1'b0,15'h28A, 8'h7B};  end   // 
                WR_STA_85 : begin r_wr_infodata <= {1'b0,15'h28B, 8'h00};  end   // 
                WR_STA_86 : begin r_wr_infodata <= {1'b0,15'h290, 8'h89};  end   // 
                WR_STA_87 : begin r_wr_infodata <= {1'b0,15'h294, 8'h24};  end   // 
                WR_STA_88 : begin r_wr_infodata <= {1'b0,15'h296, 8'h03};  end   // 
                WR_STA_89 : begin r_wr_infodata <= {1'b0,15'h297, 8'h0D};  end   //  
                WR_STA_90 : begin r_wr_infodata <= {1'b0,15'h299, 8'h02};  end   // 
                WR_STA_91  : begin r_wr_infodata <= {1'b0,15'h29A, 8'h8E};  end   // 
                WR_STA_92  : begin r_wr_infodata <= {1'b0,15'h29C, 8'h2A};  end   // 
                WR_STA_93  : begin r_wr_infodata <= {1'b0,15'h29F, 8'h78};  end   // 
                WR_STA_94  : begin r_wr_infodata <= {1'b0,15'h2A0, 8'h06};  end   // 
                WR_STA_95  : begin r_wr_infodata <= {1'b0,15'h280, 8'h01};  end   //  
                WR_STA_96  : begin r_wr_infodata <= {1'b0,15'h280, 8'h05};  end   //
                WR_STA_97  : begin r_wr_infodata <= {1'b0,15'h280, 8'h01};  end   //
                WR_STA_98 :  begin r_rd_info <= {1'b1,15'h281};            r_wrrd_mode_sel <= SPI_READ_MODE; end// read if serdes pll locked and wait it
                WR_STA_99  : begin r_wr_infodata <= {1'b0,15'h268, 8'h22};  r_wrrd_mode_sel <= SPI_WRITE_MODE; end   // Normal EQ mode
                WR_STA_100: begin r_wr_infodata <= {1'b0,15'h301, 8'h01};  end   // subclass 1
                WR_STA_101: begin r_wr_infodata <= {1'b0,15'h304, 8'h00};  end   // LMFC delay set 0
                WR_STA_102: begin r_wr_infodata <= {1'b0,15'h305, 8'h00};  end   // LMFC delay set 0
                WR_STA_103: begin r_wr_infodata <= {1'b0,15'h306, 8'h06};  end   // LMFC receive buffer delay = 6
                WR_STA_104: begin r_wr_infodata <= {1'b0,15'h307, 8'h06};  end   // LMFC receive buffer delay = 6    
                WR_STA_105: begin r_wr_infodata <= {1'b0,15'h03A, 8'h01};  end   // sync mode = one-shot mode
                WR_STA_106: begin r_wr_infodata <= {1'b0,15'h03A, 8'h81};  end   // enable sync FSM
                WR_STA_107: begin r_wr_infodata <= {1'b0,15'h03A, 8'hC1};  end   // arm sync FSM
                WR_STA_108: begin r_wr_infodata <= {1'b0,15'h300, 8'h01};  end   // checksum reg, single link mode, enable link0     
                WR_STA_109: begin r_wr_infodata <= {1'b0,15'hE7, 8'h38};  end   // dac self calibration
                WR_STA_110: begin r_wr_infodata <= {1'b0,15'hE8, 8'h03};  end
                WR_STA_111: begin r_wr_infodata <= {1'b0,15'hED, 8'hA2};  end    
                WR_STA_112: begin r_wr_infodata <= {1'b0,15'hE2, 8'h01};  end
                WR_STA_113: begin r_wr_infodata <= {1'b0,15'hE2, 8'h03};  end 
                WR_STA_114: begin  r_dac_spi_delay_cnt <= 16'd20000;       r_wrrd_mode_sel <= SPI_DELAY_MODE;  end  //delay 100ms
                WR_STA_115: begin r_rd_info <= {1'b1,15'h023};             r_wrrd_mode_sel <= SPI_READ_MODE; end  // 
                WR_STA_116: begin r_wr_infodata <= {1'b0,15'hE7, 8'h30};   r_wrrd_mode_sel <= SPI_WRITE_MODE; end   // close self calibration
                WR_STA_117: begin r_wr_infodata <= {1'b0,15'h08, 8'h03};  end   // update
                WR_STA_118: begin r_wr_infodata <= {1'b0,15'h300, 8'h01};  end   // checksum reg, single link mode, enable link0                                                                                                                                                                  
                WR_STA_119:  begin r_rd_info <= {1'b1,15'h084};            r_wrrd_mode_sel <= SPI_READ_MODE; end//  read dac pll locked   
                WR_STA_120:  begin r_rd_info <= {1'b1,15'h281};            r_wrrd_mode_sel <= SPI_READ_MODE; end//  read serdes pll lock status
                WR_STA_121:  begin r_rd_info <= {1'b1,15'h470};            r_wrrd_mode_sel <= SPI_READ_MODE; end//  read jesd check
                WR_STA_122:  begin r_rd_info <= {1'b1,15'h471};            r_wrrd_mode_sel <= SPI_READ_MODE; end// 
                WR_STA_123:  begin r_rd_info <= {1'b1,15'h472};            r_wrrd_mode_sel <= SPI_READ_MODE; end//  
                WR_STA_124:  begin r_rd_info <= {1'b1,15'h473};            r_wrrd_mode_sel <= SPI_READ_MODE; end//                                                                         
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

//myila_spi myila_das_spi_inst (
//	.clk(clk_in), // input wire clk
	
//	.probe0(o_sclk), // input wire [0:0]  probe0  
//	.probe1(o_sen_n), // input wire [0:0]  probe1 
//	.probe2(io_sda), // input wire [0:0]  probe2 
//	.probe3(w_sda_dir), // input wire [0:0]  probe3 
//	.probe4(state_cur), // input wire [9:0]  probe4
//	.probe5(w_rd_data),// input wire [7:0]  probe5
//	.probe6(r_sclk_test), // input wire [0:0]  probe6
//	.probe7(w_hold_save_read)
	
//	);
endmodule