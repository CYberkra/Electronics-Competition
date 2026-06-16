//------------------------------------------------------------------------------
// Tile Renderer — BRAM/ROM registered-output safe version
// 240x280 pixels, 30x17 character grid, 8x16 font
//
// Key point:
//   char_grid.rd_data and char_rom.bitmap are updated on the same clock edge as
//   this renderer. Therefore, after issuing an address, the new data can only be
//   sampled one clock edge later. This FSM inserts explicit WAIT states.
//------------------------------------------------------------------------------

`timescale 1ns / 1ps

module tile_renderer #(
    parameter COLS     = 30,
    parameter ROWS     = 17,
    parameter CHAR_W   = 8,
    parameter CHAR_H   = 16,
    parameter SCR_W    = 240,
    parameter SCR_H    = 280
) (
    input  wire        clk,
    input  wire        rst_n,

    // Character grid synchronous read interface
    output reg  [8:0]  char_addr,
    input  wire [7:0]  char_code,

    // Font ROM synchronous read interface
    output reg  [6:0]  font_char,
    output reg  [3:0]  font_row,
    input  wire [7:0]  font_bitmap,

    // Pixel stream to ST7789 driver
    output reg  [15:0] pixel_data,
    output reg         pixel_valid,
    input  wire        pixel_ready,

    // Color theme
    input  wire [15:0] fg_color,
    input  wire [15:0] bg_color,
    input  wire [15:0] title_color,
    input  wire [15:0] status_color,
    input  wire [15:0] cursor_color,

    // Cursor position
    input  wire [4:0]  cursor_row,
    input  wire [4:0]  cursor_col,

    // Frame markers
    output reg         frame_start,
    output reg         vsync
);

    // Current pixel coordinate being prepared/output
    reg [7:0] px_x;   // 0..239
    reg [8:0] px_y;   // 0..279

    wire [4:0] tile_col_now = px_x[7:3];
    wire [4:0] tile_row_now = px_y[8:4];
    wire [2:0] sub_x_now    = px_x[2:0];
    wire [3:0] sub_y_now    = px_y[3:0];

    // Latched metadata for the pixel being prepared
    reg [4:0] tile_row_r;
    reg [4:0] tile_col_r;
    reg [2:0] sub_x_r;
    reg [3:0] sub_y_r;

    localparam [2:0] S_ADDR       = 3'd0; // issue char_grid address
    localparam [2:0] S_CHAR_WAIT  = 3'd1; // wait registered char_grid output
    localparam [2:0] S_FONT       = 3'd2; // sample char_code, issue font address
    localparam [2:0] S_FONT_WAIT  = 3'd3; // wait registered font output
    localparam [2:0] S_MAKE       = 3'd4; // sample font_bitmap, make pixel
    localparam [2:0] S_HOLD       = 3'd5; // hold pixel until accepted
    reg [2:0] st;

    wire printable = (char_code >= 8'h20) && (char_code < 8'h80);
    wire [6:0] font_char_next = printable ? char_code[6:0] : 7'h20;

    task advance_xy;
    begin
        if (px_x == SCR_W-1) begin
            px_x <= 8'd0;
            if (px_y == SCR_H-1) begin
                px_y <= 9'd0;
                frame_start <= 1'b1;
                vsync <= 1'b1;
            end else begin
                px_y <= px_y + 1'b1;
            end
        end else begin
            px_x <= px_x + 1'b1;
        end
    end
    endtask

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            px_x        <= 8'd0;
            px_y        <= 9'd0;
            char_addr   <= 9'd0;
            font_char   <= 7'h20;
            font_row    <= 4'd0;
            pixel_data  <= 16'd0;
            pixel_valid <= 1'b0;
            frame_start <= 1'b0;
            vsync       <= 1'b0;
            tile_row_r  <= 5'd0;
            tile_col_r  <= 5'd0;
            sub_x_r     <= 3'd0;
            sub_y_r     <= 4'd0;
            st          <= S_ADDR;
        end else begin
            frame_start <= 1'b0;
            vsync       <= 1'b0;

            case (st)
                S_ADDR: begin
                    // Issue char_grid address and latch coordinate metadata.
                    pixel_valid <= 1'b0;

                    tile_row_r <= tile_row_now;
                    tile_col_r <= tile_col_now;
                    sub_x_r    <= sub_x_now;
                    sub_y_r    <= sub_y_now;

                    if (tile_row_now >= ROWS)
                        char_addr <= 9'd0;
                    else
                        char_addr <= tile_row_now * COLS + tile_col_now;

                    st <= S_CHAR_WAIT;
                end

                S_CHAR_WAIT: begin
                    // char_grid updates rd_data on this edge; sample it next edge.
                    pixel_valid <= 1'b0;
                    st <= S_FONT;
                end

                S_FONT: begin
                    // Now char_code corresponds to char_addr issued in S_ADDR.
                    pixel_valid <= 1'b0;
                    font_char <= font_char_next;
                    font_row  <= sub_y_r;
                    st <= S_FONT_WAIT;
                end

                S_FONT_WAIT: begin
                    // char_rom updates bitmap on this edge; sample it next edge.
                    pixel_valid <= 1'b0;
                    st <= S_MAKE;
                end

                S_MAKE: begin
                    // Now font_bitmap corresponds to font_char/font_row issued in S_FONT.
                    if (tile_row_r >= ROWS) begin
                        pixel_data <= bg_color;
                    end else if (font_bitmap[3'd7 - sub_x_r]) begin
                        pixel_data <= fg_color;
                    end else begin
                        if (tile_row_r == 5'd0)
                            pixel_data <= title_color;
                        else if (tile_row_r == 5'd16)
                            pixel_data <= status_color;
                        else if (tile_row_r == cursor_row)
                            pixel_data <= cursor_color;
                        else
                            pixel_data <= bg_color;
                    end

                    pixel_valid <= 1'b1;
                    st <= S_HOLD;
                end

                S_HOLD: begin
                    // Hold pixel stable until accepted by st7789_driver.
                    pixel_valid <= 1'b1;
                    if (pixel_ready) begin
                        // Driver samples old pixel_valid/pixel_data at this edge.
                        pixel_valid <= 1'b0;
                        advance_xy();
                        st <= S_ADDR;
                    end
                end

                default: begin
                    pixel_valid <= 1'b0;
                    st <= S_ADDR;
                end
            endcase
        end
    end

endmodule
