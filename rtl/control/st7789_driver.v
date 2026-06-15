//------------------------------------------------------------------------------
// ST7789 SPI LCD Driver — 240x280 TFT, 3-wire SPI + DC + RES + BLK
// Simple counter-based SPI: each bit = 2 cycles (SCL low → SCL high)
// SPI clock = clk/2 = 12.5 MHz
//------------------------------------------------------------------------------
`timescale 1ns / 1ps

module st7789_driver (
    input  wire        clk,           // 25MHz
    input  wire        rst_n,

    output reg         tft_scl,
    output reg         tft_sda,
    output reg         tft_cs,
    output reg         tft_dc,        // 0=command, 1=data
    output reg         tft_res,
    output reg         tft_blk,

    input  wire [15:0] pixel_data,    // RGB565
    input  wire        pixel_valid,
    output reg         pixel_ready,

    output reg         frame_done,
    output reg         init_done
);

    // Init commands: {is_data(1bit), payload(8bit)}
    // Special: 9'h1FF = delay, 9'h1FE = end
    localparam CMD_SWRESET = 9'h001;
    localparam CMD_SLPOUT  = 9'h011;
    localparam CMD_COLMOD  = 9'h03A;
    localparam CMD_MADCTL  = 9'h036;
    localparam CMD_INVON   = 9'h021;
    localparam CMD_NORON   = 9'h013;
    localparam CMD_DISPON  = 9'h029;
    localparam CMD_CASET   = 9'h02A;
    localparam CMD_RASET   = 9'h02B;
    localparam CMD_RAMWR   = 9'h02C;
    localparam SEQ_DELAY   = 9'h1FF;
    localparam SEQ_END     = 9'h1FE;

    // Init sequence ROM
    reg [8:0] init_seq [0:24];
    integer i;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < 25; i = i + 1) init_seq[i] <= 9'd0;
        end else begin
            init_seq[0]  <= CMD_SWRESET; init_seq[1]  <= SEQ_DELAY;
            init_seq[2]  <= CMD_SLPOUT;  init_seq[3]  <= SEQ_DELAY;
            init_seq[4]  <= CMD_COLMOD;  init_seq[5]  <= {1'b1, 8'h55};
            init_seq[6]  <= CMD_MADCTL;  init_seq[7]  <= {1'b1, 8'h00};
            init_seq[8]  <= CMD_INVON;
            init_seq[9]  <= CMD_NORON;
            init_seq[10] <= CMD_DISPON;
            init_seq[11] <= CMD_CASET;
            init_seq[12] <= {1'b1, 8'h00}; init_seq[13] <= {1'b1, 8'h00};
            init_seq[14] <= {1'b1, 8'h00}; init_seq[15] <= {1'b1, 8'hEF};
            init_seq[16] <= CMD_RASET;
            init_seq[17] <= {1'b1, 8'h00}; init_seq[18] <= {1'b1, 8'h00};
            init_seq[19] <= {1'b1, 8'h01}; init_seq[20] <= {1'b1, 8'h17};
            init_seq[21] <= CMD_RAMWR;
            init_seq[22] <= SEQ_END;
        end
    end

    //--------------------------------------------------------------------------
    // SPI bit-bang state machine
    // Each bit: 2 sub-cycles (phase=0: SCL=0 set SDA; phase=1: SCL=1 sample)
    //--------------------------------------------------------------------------
    localparam PHASE_SCL1 = 1'b1;  // SCL high, ST7789 samples SDA
    localparam PHASE_SCL0 = 1'b0;  // SCL low, update SDA

    reg        spi_phase;     // current SPI clock phase
    reg [2:0]  bit_cnt;       // bits remaining in current byte (0-7)
    reg [7:0]  spi_byte;      // byte being sent

    // High-level state
    reg [3:0]  state;
    reg [4:0]  seq_idx;
    reg [24:0] delay_cnt;      // enough for ~1 sec delay

    localparam S_RESET      = 4'd0;
    localparam S_INIT       = 4'd1;
    localparam S_INIT_DELAY = 4'd2;
    localparam S_PIXEL      = 4'd3;
    localparam S_INIT_DONE  = 4'd4;

    reg        spi_active;    // 1=currently sending a byte
    reg        px_byte1;      // 1=first byte of pixel, 0=second byte

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state      <= S_RESET;
            spi_phase  <= PHASE_SCL0;
            bit_cnt    <= 3'd0;
            spi_byte   <= 8'd0;
            seq_idx    <= 5'd0;
            delay_cnt  <= 25'd0;
            spi_active <= 1'b0;
            px_byte1   <= 1'b0;
            tft_scl    <= 1'b0;
            tft_sda    <= 1'b0;
            tft_cs     <= 1'b1;
            tft_dc     <= 1'b0;
            tft_res    <= 1'b0;
            tft_blk    <= 1'b0;
            pixel_ready <= 1'b0;
            frame_done  <= 1'b0;
            init_done   <= 1'b0;
        end else begin
            frame_done <= 1'b0;

            // SPI clock phase toggles every cycle
            spi_phase <= ~spi_phase;

            // SPI Mode 3: SCL idle HIGH (CPOL=1), sample on rising edge
            tft_scl <= ~spi_phase;

            case (state)

                //------------------------------------------------------------------
                // RESET: hardware reset pulse, then start init
                //------------------------------------------------------------------
                S_RESET: begin
                    tft_cs  <= 1'b1;
                    tft_res <= 1'b0;
                    if (delay_cnt < 25'd25000) begin  // 1ms
                        delay_cnt <= delay_cnt + 1'b1;
                    end else begin
                        tft_res   <= 1'b1;
                        delay_cnt <= 25'd0;
                        seq_idx   <= 5'd0;
                        state     <= S_INIT;
                    end
                end

                //------------------------------------------------------------------
                // INIT: process init sequence
                //------------------------------------------------------------------
                S_INIT: begin
                    if (spi_phase == PHASE_SCL1) begin
                        if (spi_active && bit_cnt > 0) begin
                            spi_byte <= {spi_byte[6:0], 1'b0};
                            bit_cnt  <= bit_cnt - 1'b1;
                            if (bit_cnt == 3'd1) spi_active <= 1'b0; // last bit
                        end else if (spi_active && bit_cnt == 0) begin
                            // Byte just completed → next entry
                            seq_idx    <= seq_idx + 1'b1;
                            spi_active <= 1'b0;
                        end
                        // else: no active byte, wait for SCL=0 to load one
                    end else begin
                        // SCL=0: load next byte if idle, drive SDA
                        if (!spi_active) begin
                            if (init_seq[seq_idx] == SEQ_END) begin
                                state <= S_INIT_DONE;
                            end else if (init_seq[seq_idx] == SEQ_DELAY) begin
                                tft_cs    <= 1'b1;
                                delay_cnt <= 25'd0;
                                state     <= S_INIT_DELAY;
                            end else begin
                                tft_sda    <= init_seq[seq_idx][7];
                                tft_dc     <= init_seq[seq_idx][8]; // bit8: 1=data, 0=cmd
                                spi_byte   <= init_seq[seq_idx][7:0];
                                bit_cnt    <= 3'd7;
                                spi_active <= 1'b1;
                                tft_cs     <= 1'b0;
                            end
                        end else begin
                            tft_sda <= spi_byte[7];
                        end
                    end
                end

                //------------------------------------------------------------------
                // INIT_DELAY: wait for specified time
                //------------------------------------------------------------------
                S_INIT_DELAY: begin
                    tft_cs <= 1'b1;
                    if (delay_cnt < 25'd75000) begin  // ~3ms
                        delay_cnt <= delay_cnt + 1'b1;
                    end else begin
                        delay_cnt <= 25'd0;
                        state     <= S_INIT;
                    end
                end

                //------------------------------------------------------------------
                // INIT_DONE: backlight on, start accepting pixels
                //------------------------------------------------------------------
                S_INIT_DONE: begin
                    tft_cs    <= 1'b0;
                    tft_dc    <= 1'b1;
                    tft_blk   <= 1'b1;
                    init_done <= 1'b1;
                    pixel_ready <= 1'b1;
                    spi_active  <= 1'b0;
                    px_byte1    <= 1'b1;
                    state     <= S_PIXEL;
                end

                //------------------------------------------------------------------
                // PIXEL: send 2 bytes (RGB565) per pixel
                //------------------------------------------------------------------
                S_PIXEL: begin
                    if (spi_phase == PHASE_SCL1) begin
                        if (spi_active && bit_cnt > 0) begin
                            spi_byte <= {spi_byte[6:0], 1'b0};
                            bit_cnt  <= bit_cnt - 1'b1;
                            if (bit_cnt == 3'd1) spi_active <= 1'b0;
                        end else if (spi_active && bit_cnt == 0) begin
                            // Byte done → load next
                            spi_active <= 1'b0;
                            if (px_byte1) begin
                                // High byte done → load low byte immediately
                                spi_byte <= pixel_data[7:0];
                                bit_cnt  <= 3'd7;
                                spi_active <= 1'b1;
                                px_byte1 <= 1'b0;
                            end else begin
                                // Low byte done → pixel complete
                                pixel_ready <= 1'b1;
                                px_byte1 <= 1'b1;
                            end
                        end
                    end else begin
                        // SCL=0: drive SDA, load new byte if idle
                        if (!spi_active) begin
                            // Start new byte
                            bit_cnt    <= 3'd7;
                            spi_active <= 1'b1;
                            if (px_byte1) begin
                                // Starting high byte of pixel
                                tft_sda <= pixel_data[15];
                                spi_byte <= pixel_data[15:8];
                                if (pixel_valid && pixel_ready)
                                    pixel_ready <= 1'b0;
                            end else begin
                                // Starting low byte of pixel
                                tft_sda <= pixel_data[7];
                                spi_byte <= pixel_data[7:0];
                            end
                        end else begin
                            tft_sda <= spi_byte[7];
                        end
                    end
                end

                default: state <= S_RESET;
            endcase
        end
    end

endmodule
