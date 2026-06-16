// ST7789 Character Display Test Top
// Pipeline: char_grid -> tile_renderer -> st7789_driver
// Writes "AWG Ready" message to char_grid at startup
`timescale 1ns / 1ps

module st7789_text_top (
    input  wire  sys_clk_p, sys_clk_n, sys_rst_n,
    output wire  tft_scl, tft_sda, tft_cs, tft_dc, tft_res, tft_blk,
    output wire  test_led
);

    // Clock
    wire cfg_clk, EOS_n;
    STARTUPE2 #(.PROG_USR("FALSE"),.SIM_CCLK_FREQ(0.0)) u_s (
        .CFGMCLK(cfg_clk),.EOS(EOS_n),.USRCCLKO(0),.USRCCLKTS(1)
    );
    wire clk_25m, clk_axi, clk_locked;
    clk_sys_mmcm u_m (.clk_out1(clk_25m),.clk_out2(clk_axi),.locked(clk_locked),.clk_in1(cfg_clk));
    wire rst_n = EOS_n & clk_locked & sys_rst_n;

    // ---- Display Pipeline ----

    // Char grid (30x17 = 510 bytes)
    wire [8:0]  grid_rd_addr;
    wire [7:0]  grid_rd_data;
    reg         grid_wr_en;
    reg  [8:0]  grid_wr_addr;
    reg  [7:0]  grid_wr_data;

    char_grid u_grid (
        .clk(clk_25m), .wr_en(grid_wr_en), .wr_addr(grid_wr_addr),
        .wr_data(grid_wr_data), .rd_addr(grid_rd_addr), .rd_data(grid_rd_data)
    );

    // Font ROM
    wire [6:0]  font_char;
    wire [3:0]  font_row;
    wire [7:0]  font_bm;
    char_rom #(.FONT_FILE("../../rtl/control/font_8x16.hex")) u_rom (
        .clk(clk_25m), .char_code(font_char), .row(font_row), .bitmap(font_bm)
    );

    // Tile renderer
    wire [15:0] tft_px;
    wire        tft_px_v;
    wire        tft_px_r;
    tile_renderer u_tr (
        .clk(clk_25m), .rst_n(rst_n),
        .char_addr(grid_rd_addr), .char_code(grid_rd_data),
        .font_char(font_char), .font_row(font_row), .font_bitmap(font_bm),
        .pixel_data(tft_px), .pixel_valid(tft_px_v), .pixel_ready(tft_px_r),
        .fg_color(16'hFFFF), .bg_color(16'h0000),
        .title_color(16'h001F), .status_color(16'h001F),
        .cursor_color(16'h07E0), .cursor_row(0), .cursor_col(0),
        .frame_start(), .vsync()
    );

    // ST7789 driver
    wire tft_init_done;
    st7789_driver u_drv (
        .clk(clk_25m), .rst_n(rst_n),
        .tft_scl(tft_scl), .tft_sda(tft_sda), .tft_cs(tft_cs),
        .tft_dc(tft_dc), .tft_res(tft_res), .tft_blk(tft_blk),
        .pixel_data(tft_px), .pixel_valid(tft_px_v), .pixel_ready(tft_px_r),
        .frame_done(), .init_done(tft_init_done)
    );

    assign test_led = tft_init_done;

    // ---- Startup text writer ----
    // Writes "  AWG Generator Ready  " to row 7 (center of screen)
    reg [8:0]  wr_idx;
    reg [2:0]  wr_st;
    reg [15:0] wr_timer;
    localparam WR_IDLE=0, WR_GO=1, WR_DONE=2;

    // Message: "  AWG TFT Test  " (16 chars) on row 7, starting at col 7
    // Row 7 = tile index 7*30+7 = 217
    reg [7:0] msg [0:15];
    integer mi;
    always @(posedge clk_25m or negedge rst_n) begin
        if (!rst_n) begin
            for (mi=0;mi<16;mi=mi+1) msg[mi] <= 8'h20; // spaces
        end else begin
            msg[0]  <= 8'h20; // space
            msg[1]  <= 8'h20; // space
            msg[2]  <= 8'h41; // A
            msg[3]  <= 8'h57; // W
            msg[4]  <= 8'h47; // G
            msg[5]  <= 8'h20; // space
            msg[6]  <= 8'h54; // T
            msg[7]  <= 8'h46; // F
            msg[8]  <= 8'h54; // T
            msg[9]  <= 8'h20; // space
            msg[10] <= 8'h4F; // O
            msg[11] <= 8'h4B; // K
            msg[12] <= 8'h21; // !
            msg[13] <= 8'h20; // space
            msg[14] <= 8'h20; // space
            msg[15] <= 8'h20; // space
        end
    end

    always @(posedge clk_25m or negedge rst_n) begin
        if (!rst_n) begin
            wr_st <= WR_IDLE; wr_idx <= 0; wr_timer <= 0;
            grid_wr_en <= 0; grid_wr_addr <= 0; grid_wr_data <= 0;
        end else begin
            grid_wr_en <= 0;

            case (wr_st)
                WR_IDLE: begin
                    if (tft_init_done) begin
                        wr_timer <= wr_timer + 1;
                        if (wr_timer > 25000) begin // wait ~1ms after init
                            wr_st <= WR_GO; wr_idx <= 0;
                        end
                    end
                end

                WR_GO: begin
                    grid_wr_en <= 1;
                    grid_wr_addr <= 9'd217 + wr_idx; // row 7, col 7+n
                    grid_wr_data <= msg[wr_idx];
                    if (wr_idx < 15)
                        wr_idx <= wr_idx + 1;
                    else
                        wr_st <= WR_DONE;
                end

                WR_DONE: ; // keep message on screen
            endcase
        end
    end

endmodule
