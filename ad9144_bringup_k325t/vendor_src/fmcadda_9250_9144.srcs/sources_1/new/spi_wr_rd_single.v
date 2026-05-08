

module spi_wr_rd_single #(
    parameter SPI_INFO_LENGTH = 8,
    parameter SPI_DATA_LENGTH = 8)
(
    input clk_in,
    input rst_n,
    input [SPI_INFO_LENGTH + SPI_DATA_LENGTH - 1: 0] i_wr_infodata,
    input [SPI_INFO_LENGTH - 1: 0] i_rd_info,
    output reg[SPI_DATA_LENGTH - 1: 0] r_rd_data,
    
    input[1:0] i_wrrd_mode_sel,  //2'b00时只写入SPI，2'b01时读取SPI, 2'b10时为延时等待
    output reg o_sclk,
    input      i_sda,
    output reg o_sda,
    output reg o_sda_dir, //低点平时只写入SPI(控制为端口输出方向)，高电平时读取SPI(控制为端口输入方向)
    output reg o_cs_n,
    input[15:0] i_delay_cnt,
    
    input datain_valid,
    output datain_ready,
    output reg r_sclk,
    output reg hold_save_read
    );
   

localparam IDLE         = 3'd0;
localparam START        = 3'd1;
localparam INFO_TRANS   = 3'd2;
localparam DATA_REV     = 3'd3;
localparam END          = 3'd4;


reg[31:0] spi_cnt = 32'd0;
reg[2:0] state_cur = 3'd0, state_next = 3'd0;

reg[7:0] i, j;
//reg r_sclk;
reg[15:0] delay_cnt;
always@ (posedge clk_in) begin
    if(!rst_n) begin
        spi_cnt <= 32'd0;
        r_sclk <= 0;
        o_sclk <= 0;
        end
    else if(spi_cnt <= 32'd10) begin
        r_sclk <= 1;
        spi_cnt <= spi_cnt + 1'd1;
        end
    else if(spi_cnt <= 32'd20) begin
        o_sclk <= 1;
        spi_cnt <= spi_cnt + 1'd1;
        end
    else if(spi_cnt <= 32'd30) begin
        r_sclk <= 0;
        spi_cnt <= spi_cnt + 1'd1;
        end
    else if(spi_cnt <= 32'd40) begin
        o_sclk <= 0;
        spi_cnt <= spi_cnt + 1'd1;
        end
    else
       spi_cnt <= 32'd0; 
end

always@ (posedge r_sclk) begin
    if(!rst_n)
        state_cur <= IDLE;
    else 
        state_cur <= state_next;    
end

always@ (*) begin
case(state_cur)
        IDLE : begin
                    if(datain_valid)
                        state_next = START;
                    else
                        state_next = IDLE; 
               end
        START : begin
                    state_next = INFO_TRANS;
                end
        INFO_TRANS : begin
                        if(i_wrrd_mode_sel == 2'b01)  //spi read mode
                            if(i == SPI_INFO_LENGTH - 1'd1)
                                state_next = DATA_REV;
                            else 
                                state_next = INFO_TRANS;
                        else if(i_wrrd_mode_sel == 2'b00)
                            if(i == SPI_INFO_LENGTH + SPI_DATA_LENGTH - 1'd1) 
                                state_next = END;
                            else
                                state_next = INFO_TRANS;
                        else if(i_wrrd_mode_sel == 2'b10)
                            if(delay_cnt <= i_delay_cnt)
                                state_next = INFO_TRANS;
                            else
                                state_next = END;
                     end
        DATA_REV : begin
                    if(j == SPI_DATA_LENGTH - 1'd1) begin
                        state_next = END;
                        end
                    else begin
                        state_next = DATA_REV;
                        end
                    end        
        END : begin
                state_next = IDLE;
                end                           
    endcase
end
reg r_once_flag;
reg r_dir_temp;

reg[15:0] read_delay_cnt;
reg r_once_flag_for_delay;
reg wr_r_sclk;
always@ (posedge clk_in) begin
    if(!rst_n) begin
        wr_r_sclk <= 1'b0;
        read_delay_cnt <= 8'd0;
        r_once_flag_for_delay <= 0;
        end
    else if(o_sda_dir) begin
        read_delay_cnt <= read_delay_cnt + 1;
        if((read_delay_cnt == 6) & (~r_once_flag_for_delay)) begin
            wr_r_sclk <= 1;
            r_once_flag_for_delay <= 1;
            end
        else if(read_delay_cnt >= 7)
            wr_r_sclk <= 0;
        end
     else begin
        r_once_flag_for_delay <= 0;
        read_delay_cnt <= 0;
        wr_r_sclk <= 0;
    end   
end

reg temp_save_read;
always@ (posedge clk_in) begin
    if(!rst_n) begin
        temp_save_read <= 1'b0;
        end
    else begin
        temp_save_read <= wr_r_sclk & i_sda;
    end   
end

always@ (posedge clk_in) begin
    if(!rst_n) begin
        hold_save_read <= 1'b0;
        r_once_flag <= 1'b0;
        end
    else if((r_once_flag == 1'b0) && temp_save_read)begin
        hold_save_read <= 1'b1 ;
        r_once_flag <= 1'b1;
    end
    else if(~o_sda_dir) begin
        hold_save_read <= 1'b0;
        r_once_flag <= 1'b0;
    end   
end

always@ (posedge r_sclk) begin
    if(!rst_n) begin
       o_sda <= 1'b0;
       o_cs_n <= 1'b1;
       i <= 1'd0;
       j <= 1'd0;
       r_rd_data <= 8'h00;
       o_sda_dir <= 1'b0; //默认数据输出方向
       delay_cnt <= 16'd0;
    end
    case(state_cur)
            IDLE : begin
                        o_sda <= 1'b0;
                        o_cs_n <= 1'b1;
                        i <= 1'd0;
                        j <= 1'd0;
                        r_rd_data <= 8'h00; 
                        o_sda_dir <= 1'b0; 
                        delay_cnt <= 16'd0;
                   end
            START : begin
                        o_sda_dir <= 1'b0;
                        o_sda <= 1'b0;
                        o_cs_n <= 1'b1;  
                    end
            INFO_TRANS : begin
                            if(i_wrrd_mode_sel == 2'b01)  begin//spi read mode
                                o_sda <= i_rd_info[(SPI_INFO_LENGTH - 1'd1) - i];
                                i <= i + 1'd1;
                                o_cs_n <= 1'b0;
                                end
                            else if(i_wrrd_mode_sel == 2'b00) begin  //spi write mode
                                o_sda <= i_wr_infodata[(SPI_INFO_LENGTH + SPI_DATA_LENGTH - 1'd1) - i];
                                i <= i + 1'd1;
                                o_cs_n <= 1'b0;
                                end
                            else if(i_wrrd_mode_sel == 2'b10) begin
                                o_sda <= 1'b0;
                                o_cs_n <= 1'b1;
                                delay_cnt <= delay_cnt + 1'd1;
                                end    
                        end
            DATA_REV : begin
                            o_sda_dir <= 1'b1; // data input direction
                            r_rd_data <= r_rd_data | ((i_sda)  << (SPI_DATA_LENGTH - 1 - j));
                            r_rd_data[SPI_DATA_LENGTH - 1] <= hold_save_read;
                            j <= j + 1'd1;
                            o_cs_n <= 1'b0;
                        end
            END : begin
                        o_sda <= 1'b0;
                        o_cs_n <= 1'b1;
                        i <= 1'd0; 
                        j <= 1'd0; 
                    end                           
        endcase
end 
 
reg r_datain_ready, r_datain_ready_temp1;
always@ (posedge clk_in) begin
    if(!rst_n) begin
        r_datain_ready <= 1'b0;
        r_datain_ready_temp1 <= 1'b0;
        end
    else if(state_cur == IDLE) begin
        r_datain_ready <= 1'b1;
        if(datain_valid)
            r_datain_ready_temp1 <= r_datain_ready;
        end
    else if(state_cur == START) begin
        r_datain_ready <= 1'b0;
        r_datain_ready_temp1 <= 1'b0;
        end
end
assign datain_ready = (r_datain_ready & (~r_datain_ready_temp1)) ; 

endmodule

