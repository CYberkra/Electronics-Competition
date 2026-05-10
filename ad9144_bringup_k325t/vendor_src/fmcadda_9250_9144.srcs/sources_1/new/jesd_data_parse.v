`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company:
// Engineer:
//
// Create Date: 2022/06/09 19:58:36
// Design Name:
// Module Name: jesd_data_parse
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


module jesd_data_parse(
    input wr_clk,
    input rd_clk,
    input rst_n,
    input [31:0] i_jesd_data,
    input trig_in,
    output reg fifo_wr_done,

    output [13:0]  o_adc_sample
    );
    wire w_wr_rst_busy, w_rd_rst_busy;
reg r_wr_en;
reg r_rd_en;
reg r_rd_en_sync;
reg [2:0] state;
parameter state1 = 3'b001;
parameter state2 = 3'b010;
parameter state3 = 3'b100;
//reg [1:0] state;
wire w_empty, w_full;
always @(posedge wr_clk) begin
    if (!rst_n) begin
     state <= state1;
     fifo_wr_done <= 1'b0;
    end
    else
     case (state)
        state1 : begin
                   if (trig_in)
                      state <= state2;
                   else
                      state <= state1;
                 end
        state2 : begin
                   if (w_full) begin
                      r_wr_en <= 1'b0;
                      state <= state3;
                      fifo_wr_done <= 1'b1;
                      end
                   else begin
                      r_wr_en <= 1'b1;
                      state <= state2;
                      fifo_wr_done <= 1'b0;
                      end
                 end
        state3 :begin
                    if(w_empty) begin
                        r_rd_en <= 1'b0;
                        state <= state1;
                        end
                    else begin
                        r_rd_en <= 1'b1;
                        state <= state3;
                        end
                end
          default : state <= state1;
     endcase
end
always@(posedge rd_clk) begin
    if(!rst_n)
        r_rd_en_sync <= 1'b0;
    else
        r_rd_en_sync <= r_rd_en;
end

fifo_for_adc_data fifo_for_adc_data (
  .rst(1'b0),                  // input wire rst
  .wr_clk(wr_clk),            // input wire wr_clk
  .rd_clk(rd_clk),            // input wire rd_clk
  .din({i_jesd_data[7:0],i_jesd_data[15:10],i_jesd_data[23:16],i_jesd_data[31:26]}),                  // input wire [55 : 0] din
  .wr_en(r_wr_en),              // input wire wr_en
  .rd_en(r_rd_en_sync),              // input wire rd_en
  .dout(o_adc_sample),                // output wire [13 : 0] dout
  .full(w_full),                // output wire full
  .empty(w_empty),              // output wire empty
  .wr_rst_busy(w_wr_rst_busy),  // output wire wr_rst_busy
  .rd_rst_busy(w_rd_rst_busy)  // output wire rd_rst_busy
);
endmodule
