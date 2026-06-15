//------------------------------------------------------------------------------
// ST7789 minimal test — standalone display verification
// Clocks: STARTUPE2 CFGMCLK(65M) → clk_sys_mmcm → clk_25m
// Generates simple color bars to verify the display works
//------------------------------------------------------------------------------
`timescale 1ns / 1ps

module st7789_test_top (
    input  wire  sys_clk_p,
    input  wire  sys_clk_n,
    input  wire  sys_rst_n,

    // ST7789 TFT
    output wire  tft_scl,
    output wire  tft_sda,
    output wire  tft_cs,
    output wire  tft_dc,
    output wire  tft_res,
    output wire  tft_blk,

    // LED for status
    output wire  test_led
);

    //--------------------------------------------------------------------------
    // Clock: STARTUPE2 CFGMCLK → clk_sys_mmcm → clk_25m
    //--------------------------------------------------------------------------
    wire cfg_clk, EOS_n;
    STARTUPE2 #(.PROG_USR("FALSE"), .SIM_CCLK_FREQ(0.0)) u_startup (
        .CFGMCLK(cfg_clk), .EOS(EOS_n),
        .USRCCLKO(1'b0), .USRCCLKTS(1'b1)
    );

    wire clk_25m, clk_axi_100m, clk_mmcm_locked;
    clk_sys_mmcm u_mmcm (
        .clk_out1(clk_25m),
        .clk_out2(clk_axi_100m),
        .locked(clk_mmcm_locked),
        .clk_in1(cfg_clk)
    );

    wire rst_n;
    assign rst_n = EOS_n & clk_mmcm_locked & sys_rst_n;

    //--------------------------------------------------------------------------
    // Color bar pattern generator: 8 vertical bars cycling R,G,B
    //--------------------------------------------------------------------------
    reg [7:0]  px_col;      // 0-239 column
    reg [8:0]  px_row;      // 0-279 row
    reg [15:0] pat_pixel;
    reg        pat_valid;

    always @(posedge clk_25m or negedge rst_n) begin
        if (!rst_n) begin
            px_col <= 8'd0;
            px_row <= 9'd0;
            pat_valid <= 1'b0;
        end else begin
            pat_valid <= 1'b1;  // continuous valid

            if (px_col == 8'd239) begin
                px_col <= 8'd0;
                if (px_row == 9'd279)
                    px_row <= 9'd0;
                else
                    px_row <= px_row + 1'b1;
            end else begin
                px_col <= px_col + 1'b1;
            end
        end
    end

    // Color bars: 8 bands × 30 pixels each
    wire [2:0] band = px_col[7:5];  // 0-7
    always @(*) begin
        case (band)
            3'd0: pat_pixel = 16'hF800;  // Red
            3'd1: pat_pixel = 16'hFFE0;  // Yellow
            3'd2: pat_pixel = 16'h07E0;  // Green
            3'd3: pat_pixel = 16'h001F;  // Blue
            3'd4: pat_pixel = 16'hF81F;  // Magenta
            3'd5: pat_pixel = 16'h07FF;  // Cyan
            3'd6: pat_pixel = 16'hFFFF;  // White
            3'd7: pat_pixel = 16'h0000;  // Black
        endcase
    end

    //--------------------------------------------------------------------------
    // ST7789 driver
    //--------------------------------------------------------------------------
    wire tft_init_done;

    st7789_driver u_st7789 (
        .clk         (clk_25m),
        .rst_n       (rst_n),
        .tft_scl     (tft_scl),
        .tft_sda     (tft_sda),
        .tft_cs      (tft_cs),
        .tft_dc      (tft_dc),
        .tft_res     (tft_res),
        .tft_blk     (tft_blk),
        .pixel_data  (pat_pixel),
        .pixel_valid (pat_valid),
        .pixel_ready (),
        .frame_done  (),
        .init_done   (tft_init_done)
    );

    // LED = init_done (ON when display initialized)
    assign test_led = tft_init_done;

endmodule
