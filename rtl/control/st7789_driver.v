// ST7789 SPI LCD Driver - 240x280 TFT
// 6-state bit engine: 6 cycles/bit = 4.17 MHz SCL
// SPI Mode 0: CPOL=0 (idle low), CPHA=0 (sample on rising edge)
`timescale 1ns / 1ps

module st7789_driver (
    input  wire        clk,
    input  wire        rst_n,
    output reg         tft_scl,
    output reg         tft_sda,
    output reg         tft_cs,
    output reg         tft_dc,
    output reg         tft_res,
    output reg         tft_blk,
    input  wire [15:0] pixel_data,
    input  wire        pixel_valid,
    output reg         pixel_ready,
    output reg         frame_done,
    output reg         init_done
);

    // Init commands: 9-bit {is_data, byte}, 0x1FF=delay, 0x1FE=end
    localparam CMD_SWRESET = {1'b0, 8'h01};
    localparam CMD_SLPOUT  = {1'b0, 8'h11};
    localparam CMD_COLMOD  = {1'b0, 8'h3A};
    localparam CMD_MADCTL  = {1'b0, 8'h36};
    localparam CMD_INVON   = {1'b0, 8'h21};
    localparam CMD_NORON   = {1'b0, 8'h13};
    localparam CMD_DISPON  = {1'b0, 8'h29};
    localparam CMD_CASET   = {1'b0, 8'h2A};
    localparam CMD_RASET   = {1'b0, 8'h2B};
    localparam CMD_RAMWR   = {1'b0, 8'h2C};
    localparam SEQ_DELAY   = 9'h1FF;
    localparam SEQ_END     = 9'h1FE;
    // Delay count for 120ms at 25MHz
    localparam [24:0] DELAY_120MS = 25'd3_000_000;

    reg [8:0] seq [0:23];
    integer i;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) for (i=0;i<24;i=i+1) seq[i]<=9'd0;
        else begin
            seq[0] <=CMD_SWRESET; seq[1] <=SEQ_DELAY;
            seq[2] <=CMD_SLPOUT;  seq[3] <=SEQ_DELAY;
            seq[4] <=CMD_COLMOD;  seq[5] <={1'b1,8'h55};
            seq[6] <=CMD_MADCTL;  seq[7] <={1'b1,8'h00}; // RGB mode (BGR=0x08 if colors swapped) // BGR panel subpixel order
            seq[8] <=CMD_INVON;
            seq[9] <=CMD_NORON;
            seq[10]<=CMD_DISPON;  seq[11]<=SEQ_DELAY;    // 120ms settle
            seq[12]<=CMD_CASET;
            seq[13]<={1'b1,8'h00};seq[14]<={1'b1,8'h00}; // XS=0
            seq[15]<={1'b1,8'h00};seq[16]<={1'b1,8'hEF}; // XE=239
            seq[17]<=CMD_RASET;
            seq[18]<={1'b1,8'h00};seq[19]<={1'b1,8'h14}; // YS=20 (0x0014)
            seq[20]<={1'b1,8'h01};seq[21]<={1'b1,8'h2B}; // YE=299 (0x012B) (0x012B)
            seq[22]<=CMD_RAMWR;
            seq[23]<=SEQ_END;
        end
    end

    // 6-state per bit engine: 3 SCL=0, 3 SCL=1
    // Gives 240ns/bit = 4.17MHz SCL, double timing margin
    localparam [2:0] PH_S0=0, PH_S1=1, PH_S2=2, PH_H0=3, PH_H1=4, PH_H2=5;
    reg [2:0] ph;
    reg [2:0] bc;         // bit count 0-7
    reg [7:0] sr;         // shift register
    reg [4:0] si;         // sequence index
    reg [24:0] dc;        // delay counter
    reg [15:0] px;        // current pixel
    reg active;           // currently sending a byte
    reg px_1st;           // 1=first byte of pixel, 0=second

    localparam ST_RESET=0, ST_INIT=1, ST_DELAY=2, ST_PIXEL=3, ST_DONE=4;
    reg [2:0] st;
    reg [2:0] st_prev;  // for edge detection

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            st<=ST_RESET; ph<=PH_S0; bc<=0; sr<=0; si<=0; dc<=0; px<=0;
            active<=0; px_1st<=0;
            tft_scl<=0; tft_sda<=0; tft_cs<=1; tft_dc<=0; tft_res<=0; tft_blk<=0;
            pixel_ready<=0; frame_done<=0; init_done<=0;
        end else begin
            frame_done <= 0;
            st_prev <= st;
            // 6-state counter: explicitly wrap at PH_H2
            if (active && ph == PH_H2)
                ph <= PH_S0;
            else if (!active)
                ph <= PH_S0;
            else
                ph <= ph + 1'b1;

            // On entering ST_PIXEL: backlight on, init done, ready for pixels
            if (st==ST_PIXEL && st_prev!=ST_PIXEL) begin
                tft_blk <= 1'b1; init_done <= 1'b1; pixel_ready <= 1'b1;
            end

            case (st)
                ST_RESET: begin
                    tft_cs<=1; tft_res<=0;
                    if (dc<DELAY_120MS) dc<=dc+1; else begin tft_res<=1; dc<=0; si<=0; st<=ST_INIT; end
                end

                ST_INIT: begin
                    if (!active) begin
                        tft_scl <= 1'b0;  // SPI Mode 0 idle low between bytes
                        if (seq[si]==SEQ_END) begin st<=ST_PIXEL; end
                        else if (seq[si]==SEQ_DELAY) begin si<=si+1; dc<=0; st<=ST_DELAY; end
                        else begin
                            tft_cs<=0; tft_dc<=seq[si][8]; sr<=seq[si][7:0];
                            bc<=0; active<=1; ph<=PH_S0;
                        end
                    end else begin
                        // Bit engine
                        case (ph)
                            PH_S0: begin tft_scl<=0; tft_sda<=sr[7]; end
                            PH_S1: begin tft_scl<=0; end
                            PH_S2: begin tft_scl<=0; end
                            PH_H0: begin tft_scl<=1; end  // ST7789 samples
                            PH_H1: begin tft_scl<=1; end
                            PH_H2: begin
                                tft_scl<=1;
                                if (bc<7) begin bc<=bc+1; sr<={sr[6:0],1'b0}; end
                                else begin active<=0; si<=si+1; end
                            end
                            default: ;
                        endcase
                    end
                end

                ST_DELAY: begin
                    tft_cs<=1;
                    if (dc<DELAY_120MS) dc<=dc+1; else begin dc<=0; st<=ST_INIT; end
                end

                ST_PIXEL: begin
                    if (!active) begin
                        tft_scl <= 1'b0;  // SPI Mode 0 idle between pixels
                        if (pixel_valid && pixel_ready) begin
                            pixel_ready<=0; px<=pixel_data; px_1st<=1;
                            sr<=pixel_data[15:8]; bc<=0; active<=1; ph<=PH_S0;
                            tft_cs<=0; tft_dc<=1;
                        end
                    end else begin
                        case (ph)
                            PH_S0: begin tft_scl<=0; tft_sda<=sr[7]; end
                            PH_S1: begin tft_scl<=0; end
                            PH_S2: begin tft_scl<=0; end
                            PH_H0: begin tft_scl<=1; end  // ST7789 samples
                            PH_H1: begin tft_scl<=1; end
                            PH_H2: begin
                                tft_scl<=1;
                                if (bc<7) begin bc<=bc+1; sr<={sr[6:0],1'b0}; end
                                else begin
                                    if (px_1st) begin
                                        px_1st<=0; sr<=px[7:0]; bc<=0;
                                    end else begin
                                        active<=0; pixel_ready<=1;
                                    end
                                end
                            end
                            default: ;
                        endcase
                    end
                end

                default: st<=ST_RESET;
            endcase
        end
    end


endmodule
