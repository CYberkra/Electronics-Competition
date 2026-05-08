`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2024/08/02 00:22:31
// Design Name: 
// Module Name: jesd_axi_write
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


module jesd_axi_write(
    input               s_axi_aclk      ,   //时钟
    input               s_axi_aresetn   ,   //低电平复位
    //input               axi_write_ena   ,
    input               s_axi_awready   ,   //写入地址就绪
    input               s_axi_wready    ,   //写入数据就绪
    input               s_axi_bvalid    ,   //写入响应有效
    input      [1:0]    s_axi_bresp     ,   //写入响应
    output reg [11:0]   s_axi_awaddr    ,   //写入地址
    output reg          s_axi_awvalid   ,   //写入地址有效
    output reg [31:0]   s_axi_wdata     ,   //写入数据
    output reg          s_axi_wvalid    ,   //写入数据有效
    output reg          s_axi_bready    ,      //写入数据就绪
    output reg          axi_write_done      //数据全部写入
    );
//*******************数据链路层的参数配置**********************
    localparam pLanes = 4       ;       //lane数
    // F = 1 K = 32                     //BUFF的值
    localparam  [2:0] pF        = 1-1    ;       //////////////////////F
    localparam  [8:0] pK        = 32-1   ;       //K
 
    // Setup the link configuration parameters.
    localparam [7:0] pDID      = 8'h00      ;    //Device ID 设备ID
    localparam [3:0] pADJCNT   = 4'h0       ;    //ADJCNT (Phase Adjust Request) [Subclass 2 Only]. Binary value.
    localparam [3:0] pBID      = 4'h0       ;    //Bank ID
    localparam       pADJDIR   = 1'b0       ;    //ADJDIR (Adjust Direction) [Subclass 2 Only]. Binary value.
    localparam       pPHADJ    = 1'b0       ;    //PHADJ (Phase Adjust Request) [Subclass 2 Only]. Binary value.
    localparam       pSCR      = 1'b1       ;    //Scrambling Enable
    localparam [4:0] pL        = (pLanes-1) ;    //L lane数
    localparam [7:0] pM        = 2 - 1          ;    //M 转换器数   
    localparam [1:0] pCS       = 2'd0       ;    //CS 每帧周期中每个采样样本所需的控制位数   
    localparam [4:0] pN        = 5'd16 - 1      ;    //N 转换器的分辨率   
    localparam [4:0] pNt       = 5'd16 - 1      ;    //N' 样本传输的总位数   
    localparam [2:0] pSUBCV    = 3'b001     ;    //SUBCLASS: 000=Subclass0  001=Subclass1 010=Subclass2
    localparam [2:0] pJESDV    = 3'b001     ;    //J204版本  000=JESD204A  001=JESD204B
    localparam [4:0] pS        = 5'd1 - 1       ;    //S 每帧周期每个转换器采样数；   
    localparam       pHD       = 1'b1       ;    //HD  HD=0 则样本在一个通道中，HD=1 则样本被分配在多个通道中；    
    localparam [4:0] pCF       = 5'd0       ;    //CF  CF=0 则控制位在采样样本后面，CF=1 则控制位单独组成控制字；   
    localparam [7:0] pRES1     = 8'h5A      ;    //RES1 (Reserved Field 1)
    localparam [7:0] pRES2     = 8'hA5      ;    //RES2 (Reserved Field 2)
//********************************************************************
//******************状态机状态*************************************
    localparam [4:0] IDLEW     =  5'b00001  ;     //空闲等待
    localparam [4:0] DRIVEW    =  5'b00010  ;     //准备
    localparam [4:0] ADD_RES   =  5'b00100  ;     //取地址
    localparam [4:0] DAT_RES   =  5'b01000  ;     //取数据
    localparam [4:0] BRES      =  5'b10000  ;     //写数据阶段
    localparam WRITE_NUM       =  16        ;    ///配置寄存器的个数
//*******************************************************************
 
//*****************内部信号******************************
    reg [4:0]   curr_ws             ,  //状态机的当前状态
                next_ws             ;  //状态机的下一个状态
    reg         write_over          ;
    reg         write_over_delay    ;
    reg [11:0]  wadd                ;   //寄存器地址
    reg [9:0]   w_cnt               ;   //对写入的数据个数进行计数，配置完成将write_over置高
    reg [31:0]  wdata               ;   //寄存器写入数据
    reg [1:0]   resp                ;
//**********************************************************
 
//状态机
    always@(posedge s_axi_aclk or negedge s_axi_aresetn) begin
        if(!s_axi_aresetn)  
            curr_ws <= IDLEW    ;              
        else
            curr_ws <= next_ws;
    end
 
    always@(*) begin
        next_ws = 'dx;
        case(curr_ws)
            IDLEW   :   if(write_over==0)       next_ws = DRIVEW    ;  else next_ws = IDLEW     ;
            DRIVEW  :   if(s_axi_awready==1)    next_ws = ADD_RES   ;  else next_ws = DRIVEW    ;
            ADD_RES :   if(s_axi_wready==1)     next_ws = DAT_RES   ;  else next_ws = ADD_RES   ;
            DAT_RES :   if(s_axi_bvalid==1)     next_ws = BRES      ;  else next_ws = DAT_RES   ;  
            BRES    :   if(write_over==1)       next_ws = IDLEW     ;  else next_ws = DRIVEW    ;
            default :   next_ws = IDLEW ;
        endcase
    end
    always@(posedge s_axi_aclk or negedge s_axi_aresetn) begin
    
        if(!s_axi_aresetn)begin
                s_axi_awaddr    <= 0    ;              
                s_axi_awvalid   <= 0    ;
                s_axi_wdata     <= 0    ;              
                s_axi_wvalid    <= 0    ;
                s_axi_bready    <= 0    ;              
                w_cnt           <= 0    ;        
                resp            <= 0    ;
        end
        else case(curr_ws)
                IDLEW:
                begin
                    s_axi_awaddr    <= 0    ;             
                    s_axi_awvalid   <= 0    ;
                    s_axi_wdata     <= 0    ;             
                    s_axi_wvalid    <= 0    ;
                    s_axi_bready    <= 0    ;             
                    w_cnt           <= w_cnt;     
                    resp            <= 0    ;
                end
                DRIVEW:
                begin
                    if(s_axi_awready==1) begin 
                        s_axi_awaddr  <= 0  ;        
                        s_axi_awvalid <= 0  ;   
                    end
                    else begin 
                        s_axi_awaddr  <= wadd   ;     
                        s_axi_awvalid <= 1      ;   
                    end
                    s_axi_wdata   <= wdata  ;         
                    s_axi_wvalid  <= 1      ;
                    s_axi_bready  <= 0      ;             
                    w_cnt         <= w_cnt  ;     
                    resp          <= 0      ;
                end
                ADD_RES:
                begin
                    s_axi_awaddr  <= 0      ;             
                    s_axi_awvalid <= 0      ;
                    if(s_axi_wready==1) begin  
                        s_axi_wdata <= 0    ;        
                        s_axi_wvalid  <= 0  ;  
                        w_cnt <= w_cnt+1    ;
                    end //else keep//每传输一个数据加1
                        s_axi_bready  <= 0  ;             
                    resp <= 0           ;
                end
                DAT_RES:
                begin
                    s_axi_awaddr  <= 0      ;              
                    s_axi_awvalid <= 0      ;
                    s_axi_wdata   <= 0      ;              
                    s_axi_wvalid  <= 0      ;
                    if(s_axi_bvalid==1) begin 
                        s_axi_bready  <= 1  ;        
                        resp <= s_axi_bresp ;
                    end    //else keep
                    w_cnt <= w_cnt          ;
                end
                BRES:
                begin
                    s_axi_awaddr  <= 0      ;             
                    s_axi_awvalid <= 0      ;
                    s_axi_wdata   <= 0      ;             
                    s_axi_wvalid  <= 0      ;       
                    w_cnt <= w_cnt          ;
                    if(s_axi_bready) begin 
                        s_axi_bready <= 0   ;       
                        resp <= 0           ;          
                    end//只持续一个高电平
                    else begin 
                        s_axi_bready <= 1   ;        
                        resp <= s_axi_bresp ;
                    end
                end
                default:
                begin
                   s_axi_awaddr  <= 0       ;              
                   s_axi_awvalid <= 0       ;
                   s_axi_wdata   <= 0       ;              
                   s_axi_wvalid  <= 0       ;
                   s_axi_bready  <= 0       ;              
                   w_cnt         <= 0       ;
                   resp          <= 0       ;
                end
            endcase
    end
//
//判断寄存器是否全部写入
    always@(posedge s_axi_aclk or negedge s_axi_aresetn) begin
        if(!s_axi_aresetn)                      
            write_over <= 0     ;
        else if( w_cnt == WRITE_NUM)            
            write_over <= 1     ;                   //else keep
    end
//
//数据全部写入  
    always @(posedge s_axi_aclk or negedge s_axi_aresetn) begin
        if(!s_axi_aresetn)
            write_over_delay <= 0   ;
        else    
            write_over_delay <= write_over  ;
    end
    always @(posedge s_axi_aclk or negedge s_axi_aresetn) begin
        if(!s_axi_aresetn)
            axi_write_done <= 0 ;
        else 
            axi_write_done <= write_over & ~write_over_delay ;
    end
//写寄存器
    always@(posedge s_axi_aclk or negedge s_axi_aresetn) begin
        if(!s_axi_aresetn)begin
            wadd <= 0   ;
            wdata <= 0  ;
        end
        else
        case( w_cnt )
       0   :  begin wadd <=12'h004; wdata <= 32'h00000002  ; end
       1   :  begin wadd <=12'h004; wdata <= 32'h00000000  ; end
       2   :   begin wadd <=12'h008; wdata <= 32'h00000001  ; end // ILA support enable
       3   :   begin wadd <=12'h00C; wdata <= {31'b0,pSCR}  ; end //Scrambling Enable
       4   :   begin wadd <=12'h010; wdata <= {15'b0,1'b0,15'b0,1'b0}  ; end //sysref handling disable, sysref always disable
       5   :   begin wadd <=12'h014; wdata <= 32'h00000003  ; end //ILA multiframes = 4
       6   :   begin wadd <=12'h018; wdata <= 32'h00000000  ; end // no test mode( normal operation )
       7   :   begin wadd <=12'h020; wdata <= {29'b0,pF}    ; end // F = 1
       8   :   begin wadd <=12'h024; wdata <= {23'b0,pK}    ; end // K = 32
       9   :   begin wadd <=12'h028; wdata <= {24'b0,8'h0F} ; end // Lane in use(4 lane)////////////////////
       10  :   begin wadd <=12'h02C; wdata <= 32'h00000001  ; end // subclass mode 1
       11  :   begin wadd <=12'h80C; wdata <= {3'b0, pL, 12'b0, pBID, pDID}  ; end
       12  :   begin wadd <=12'h810; wdata <= {6'b0, pCS, 3'b0, pNt, 3'b0, pN, pM}  ; end
       13  :   begin wadd <=12'h814; wdata <= {3'b0, pCF, 7'b0, pHD, 3'b0, pS, 7'b0, pSCR}  ; end
       14  :   begin wadd <=12'h818 ;wdata <= {16'b0, pRES2, pRES1}  ; end
       15  :   begin wadd <=12'h004; wdata <= 32'h00000001  ; end ///////////1 release reset
            default:begin wadd <=12'h008; wdata <= 32'h00000001  ; end
        endcase
    end
    
endmodule
