"""Integrate character display pipeline into awg_top.v"""
with open('rtl/top/awg_top.v', 'rb') as f:
    c = f.read()

# 1. Add display pipeline wires
old1 = b'    wire [31:0] awg_reg_cal_rd_data;\r\n\r\n'
new1 = (
    b'    wire [31:0] awg_reg_cal_rd_data;\r\n'
    b'\r\n'
    b'    // Character display pipeline\r\n'
    b'    wire [8:0]  grid_rd_addr;\r\n'
    b'    wire [7:0]  grid_rd_data;\r\n'
    b'    wire [7:0]  grid_wr_data;\r\n'
    b'    wire        grid_wr_en;\r\n'
    b'    wire [8:0]  grid_wr_addr;\r\n'
    b'    wire [6:0]  font_char_code;\r\n'
    b'    wire [3:0]  font_row;\r\n'
    b'    wire [7:0]  font_bitmap;\r\n'
    b'    wire [15:0] tft_pixel_data;\r\n'
    b'    wire        tft_pixel_valid;\r\n'
    b'    wire        tft_pixel_ready;\r\n'
    b'\r\n'
)
c = c.replace(old1, new1)
print("1: wires OK")

# 2. Replace ST7789 instantiation with full pipeline
old2 = (
    b'    // ST7789 TFT display driver\r\n'
    b'    wire tft_init_done;\r\n'
    b'    st7789_driver u_st7789_driver (\r\n'
    b'        .clk         (clk_25m),\r\n'
    b'        .rst_n       (w_rst_n),\r\n'
    b'        .tft_scl     (tft_scl),\r\n'
    b'        .tft_sda     (tft_sda),\r\n'
    b'        .tft_cs      (tft_cs),\r\n'
    b'        .tft_dc      (tft_dc),\r\n'
    b'        .tft_res     (tft_res),\r\n'
    b'        .tft_blk     (tft_blk),\r\n'
    b"        .pixel_data  (16'hF800),  // RED test pattern\r\n"
    b"        .pixel_valid (1'b1),       // continuous feed\r\n"
    b'        .pixel_ready (),\r\n'
    b'        .frame_done  (),\r\n'
    b'        .init_done   (tft_init_done)\r\n'
    b'    );\r\n'
)

new2 = (
    b'    // Character frame buffer (30x17 = 510 bytes)\r\n'
    b'    char_grid u_char_grid (\r\n'
    b'        .clk      (clk_25m),\r\n'
    b'        .wr_en    (grid_wr_en),\r\n'
    b'        .wr_addr  (grid_wr_addr),\r\n'
    b'        .wr_data  (grid_wr_data),\r\n'
    b'        .rd_addr  (grid_rd_addr),\r\n'
    b'        .rd_data  (grid_rd_data)\r\n'
    b'    );\r\n'
    b'\r\n'
    b'    // 8x16 ASCII font ROM\r\n'
    b'    char_rom #(.FONT_FILE("../../rtl/control/font_8x16.hex")) u_char_rom (\r\n'
    b'        .clk       (clk_25m),\r\n'
    b'        .char_code (font_char_code),\r\n'
    b'        .row       (font_row),\r\n'
    b'        .bitmap    (font_bitmap)\r\n'
    b'    );\r\n'
    b'\r\n'
    b'    // Tile renderer: char grid -> RGB565 pixel stream\r\n'
    b'    tile_renderer u_tile_renderer (\r\n'
    b'        .clk          (clk_25m),\r\n'
    b'        .rst_n        (w_rst_n),\r\n'
    b'        .char_addr    (grid_rd_addr),\r\n'
    b'        .char_code    (grid_rd_data),\r\n'
    b'        .font_char    (font_char_code),\r\n'
    b'        .font_row     (font_row),\r\n'
    b'        .font_bitmap  (font_bitmap),\r\n'
    b'        .pixel_data   (tft_pixel_data),\r\n'
    b'        .pixel_valid  (tft_pixel_valid),\r\n'
    b'        .pixel_ready  (tft_pixel_ready),\r\n'
    b"        .fg_color     (16'hFFFF),\r\n"
    b"        .bg_color     (16'h0000),\r\n"
    b"        .title_color  (16'h001F),\r\n"
    b"        .status_color (16'h001F),\r\n"
    b"        .cursor_color (16'h07E0),\r\n"
    b"        .cursor_row   (5'd0),\r\n"
    b"        .cursor_col   (5'd0),\r\n"
    b'        .frame_start  (),\r\n'
    b'        .vsync        ()\r\n'
    b'    );\r\n'
    b'\r\n'
    b'    // AWG menu controller: writes status text to char_grid\r\n'
    b'    awg_menu_controller u_menu (\r\n'
    b'        .clk          (clk_25m),\r\n'
    b'        .rst_n        (w_rst_n),\r\n'
    b'        .rotation     (ec11_rotation),\r\n'
    b'        .btn_short    (ec11_btn_short),\r\n'
    b'        .btn_long     (ec11_btn_long),\r\n'
    b'        .phase_inc    ({phase_inc, 1\'b0}),\r\n'
    b'        .wave_mode    (wave_mode),\r\n'
    b'        .amplitude_q15(amp_q15),\r\n'
    b'        .output_enable(awg_reg_output_enable),\r\n'
    b'        .jesd_sync    (w_tx_sync_from_pins),\r\n'
    b'        .init_state   (state),\r\n'
    b'        .param_wr_en  (grid_wr_en),\r\n'
    b'        .param_addr   (grid_wr_addr),\r\n'
    b'        .param_wdata  (grid_wr_data),\r\n'
    b'        .param_apply  (ec11_apply),\r\n'
    b'        .grid_wr_en   (),\r\n'
    b'        .grid_addr    (),\r\n'
    b'        .grid_data    (),\r\n'
    b'        .cursor_row   (),\r\n'
    b'        .cursor_col   ()\r\n'
    b'    );\r\n'
    b'\r\n'
    b'    // ST7789 TFT display driver\r\n'
    b'    wire tft_init_done;\r\n'
    b'    st7789_driver u_st7789_driver (\r\n'
    b'        .clk         (clk_25m),\r\n'
    b'        .rst_n       (w_rst_n),\r\n'
    b'        .tft_scl     (tft_scl),\r\n'
    b'        .tft_sda     (tft_sda),\r\n'
    b'        .tft_cs      (tft_cs),\r\n'
    b'        .tft_dc      (tft_dc),\r\n'
    b'        .tft_res     (tft_res),\r\n'
    b'        .tft_blk     (tft_blk),\r\n'
    b'        .pixel_data  (tft_pixel_data),\r\n'
    b'        .pixel_valid (tft_pixel_valid),\r\n'
    b'        .pixel_ready (tft_pixel_ready),\r\n'
    b'        .frame_done  (),\r\n'
    b'        .init_done   (tft_init_done)\r\n'
    b'    );\r\n'
)

if old2 in c:
    c = c.replace(old2, new2)
    print("2: display pipeline OK")
else:
    print("2: FAIL - searching...")
    idx = c.find(b'st7789_driver u_st7789_driver')
    if idx > 0:
        ctx = c[idx-100:idx+500]
        print(ctx)
        # Try alternative old string
        alt_old = c[idx-30:idx+500]
        # Find the end of this instantiation
        end_idx = c.find(b');', idx+300)
        if end_idx > 0:
            alt_old = c[idx-30:end_idx+5]
            print(f"\nALT old string ({len(alt_old)} bytes):")
            print(alt_old)
            c = c.replace(alt_old, new2)
            print("2: display pipeline OK (alt match)")
        else:
            print("2: can't find end")

with open('rtl/top/awg_top.v', 'wb') as f:
    f.write(c)
print("DONE")
