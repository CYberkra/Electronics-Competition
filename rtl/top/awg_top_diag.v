// Diagnostic top: lights LEDs showing init state machine progress
// No dependency on FMC/LMK/JESD clocks for LED display
module awg_top_diag (
    input  wire        sys_clk_p,
    input  wire        sys_clk_n,
    input  wire        sys_rst_n,
    input  wire        key0,
    input  wire        key1,
    output wire [1:0]  led
);
    wire sys_clk_bufg;
    IBUFDS ibufds (.I(sys_clk_p), .IB(sys_clk_n), .O(sys_clk_bufg));
    BUFG bufg (.I(sys_clk_bufg), .O(sys_clk_bufg));

    // Generate 65MHz CFGMCLK for clk_sys_mmcm
    wire cfg_clk, EOS_n;
    STARTUPE2 #(.PROG_USR("FALSE"), .SIM_CCLK_FREQ(0.0))
        startupe2_inst (.CFGMCLK(cfg_clk), .EOS(EOS_n),
            .USRCCLKO(1'b0), .USRCCLKTS(1'b1));

    // MMCM: cfg_clk(65MHz) -> clk_25m + clk_axi_100m
    wire clk_25m, clk_axi_100m, clk_mmcm_locked;
    clk_sys_mmcm mmcm (
        .clk_out1(clk_25m), .clk_out2(clk_axi_100m),
        .locked(clk_mmcm_locked), .clk_in1(cfg_clk));

    // Reset
    wire w_rst_n;
    rst_module rst_inst (
        .i_sys_clk(clk_25m), .i_sys_rst_async(EOS_n),
        .o_mod1_rstn(w_rst_n));

    // SPI control for LMK (on AD29/AE29 - I2C bus)
    wire lmk_datain_valid, lmk_datain_ready;
    wire lmk04828_spi_sclk, lmk04828_spi_sdio, lmk04828_cs_n, lmk04828_reset;

    lmk_spi_wr_config lmk_spi (
        .clk_in(clk_25m), .rst_n(w_rst_n),
        .o_sclk(lmk04828_spi_sclk), .io_sda(lmk04828_spi_sdio),
        .o_cs_n(lmk04828_cs_n), .o_lmk_rst(lmk04828_reset),
        .datain_valid(lmk_datain_valid), .datain_ready(lmk_datain_ready));

    // Init state machine (simplified)
    reg [3:0] state;
    reg [1:0] led_state;
    reg lmk_valid;

    always @(posedge clk_25m or negedge w_rst_n) begin
        if (!w_rst_n) begin
            state <= 0;
            led_state <= 2'b00;
            lmk_valid <= 0;
        end else begin
            case (state)
                0: begin lmk_valid <= 0; state <= 1; end
                1: if (lmk_datain_ready) begin lmk_valid <= 1; state <= 2; end
                2: if (!lmk_datain_ready) begin lmk_valid <= 0; state <= 3; end
                3: state <= 3;  // done
            endcase
            led_state <= state[1:0];  // show state on LEDs
        end
    end

    assign led = ~led_state;  // active low LEDs
endmodule
