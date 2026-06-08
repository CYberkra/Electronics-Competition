`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company:
// Engineer:
//
// Create Date: 2024/10/02 17:26:38
// Design Name:
// Module Name: jesd_axi_read
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


module jesd_axi_read(
    input               s_axi_aclk      ,   //ʱ��
    input               s_axi_aresetn   ,   //�͵�ƽ��λ
    //input               axi_read_ena   ,
    input               s_axi_arready   ,   //��ȡ��ַ����
    input               s_axi_rvalid    ,   //��ȡ������Ч
    input      [31:0]   s_axi_rdata     ,   //��ȡ����
    input      [1:0]    s_axi_rresp     ,   //��ȡ��Ӧ
    output reg [11:0]   s_axi_araddr    ,   //��ȡ��ַ
    output reg          s_axi_arvalid   ,   //��ȡ��ַ��Ч
    output reg          s_axi_rready        //��ȡ���ݾ���

    );
//******************״̬��״̬*************************************
    localparam [2:0] IDLER      =  3'b001   ;
    localparam [2:0] DRIVER     =  3'b010   ;
    localparam [2:0] RDATA      =  3'b100   ;
    localparam       READ_NUM   =  14       ;
//*******************************************************************
//*****************�ڲ��ź�******************************
    reg [4:0]   curr_rs     ,
                next_rs     ;
    reg         read_over   ;
    reg [11:0]  radd        ;
    reg [9:0]   r_cnt       ;
    reg [31:0]  rdata       ;
    reg [1:0]   rresp       ;
//**********************************************************
//״̬��
    always@(posedge s_axi_aclk or negedge s_axi_aresetn) begin
        if(!s_axi_aresetn)
            curr_rs <= IDLER    ;
//        else if(axi_read_ena)
//            curr_rs <= next_rs  ;
        else
            curr_rs <= next_rs  ;
    end
    always@(*) begin
        next_rs = 'dx;
        case(curr_rs)
            IDLER   :
                if(read_over==0 && s_axi_arready==1)
                    next_rs = DRIVER    ;
                else
                    next_rs = IDLER     ;
            DRIVER  :
                if(s_axi_arvalid==1)
                    next_rs = RDATA     ;
                else
                    next_rs = DRIVER    ;
            RDATA   :
                if(s_axi_rvalid==1)
                    next_rs = IDLER     ;
                else    next_rs = RDATA ;
            default :   next_rs = IDLER ;
        endcase
    end

    always@(posedge s_axi_aclk or negedge s_axi_aresetn) begin
        if(!s_axi_aresetn) begin
            s_axi_araddr  <= 0  ;
            s_axi_arvalid <= 0  ;
            s_axi_rready  <= 0  ;
            rdata         <= 0  ;
            rresp         <= 0  ;
            r_cnt         <= 0  ;
        end
        else
            case(curr_rs)
                IDLER:
                begin
                    rdata <= 0;rresp <= 0;
                    if(read_over==0 && s_axi_arready==1)
                    begin
                        s_axi_araddr  <= radd   ;
                        s_axi_arvalid <= 1      ;
                        s_axi_rready  <= 0      ;
                        r_cnt <= r_cnt+1        ;   //���Ƹ���
                    end
                    else
                    begin
                        s_axi_araddr  <= 0      ;
                        s_axi_arvalid <= 0      ;
                        s_axi_rready  <= 0      ;
                        r_cnt <= r_cnt          ;
                    end
                end
                DRIVER:
                begin
                    rdata <= 0                  ;
                    rresp <= 0                  ;
                    r_cnt <= r_cnt              ;
                    if(s_axi_arvalid==1)
                    begin
                        s_axi_araddr  <= 0      ;
                        s_axi_arvalid <= 0      ;
                        s_axi_rready  <= 1      ;
                    end//else keep
                end
                RDATA:
                begin
                    s_axi_araddr    <= 0        ;
                    s_axi_arvalid   <= 0        ;
                    r_cnt           <= r_cnt    ;
                    if(s_axi_rvalid==1)
                    begin
                        s_axi_rready  <= 0      ;
                        rdata <= s_axi_rdata    ;
                        rresp <= s_axi_rresp    ;
                    end //else keep
                end
                default:
                begin
                    s_axi_araddr  <= 0          ;
                    s_axi_arvalid <= 0          ;
                    s_axi_rready  <= 0          ;
                    rdata <= 0                  ;
                    rresp <= 0                  ;
                    r_cnt <= r_cnt              ;
                end
            endcase
    end

    always@(posedge s_axi_aclk or negedge s_axi_aresetn) begin
        if(!s_axi_aresetn)
            read_over <= 0      ;
        else if( r_cnt == READ_NUM)
            read_over <= 1      ;          //11111111111111
    end

    always@(posedge s_axi_aclk or negedge s_axi_aresetn) begin
        if(!s_axi_aresetn)
            radd <= 12'h008 ;
        else
            case( r_cnt )
                0   :       radd <= 12'h008  ;
                1   :       radd <= 12'h00C  ;
                2   :       radd <= 12'h010  ;
                3   :       radd <= 12'h014  ;
                4   :       radd <= 12'h018  ;
                5   :       radd <= 12'h020  ;
                6   :       radd <= 12'h024  ;
                7   :       radd <= 12'h028  ;
                8   :       radd <= 12'h02C  ;
                9   :       radd <= 12'h80C  ;
                10  :       radd <= 12'h810  ;
                11  :       radd <= 12'h814  ;
                12  :       radd <= 12'h818  ;
                13  :       radd <= 12'h004  ;
                default:    radd <= 12'h004  ;
            endcase
    end
endmodule
