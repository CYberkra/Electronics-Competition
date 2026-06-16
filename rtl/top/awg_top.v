//------------------------------------------------------------------------------
// AWG Top Module - K325T with FMC ADDA (AD9144 DAC only)
// 【AWG 统一顶层 — 正点原子 K325T + FMCADDA-9250-9144】
//
// 子卡：FMCADDA-9250-9144
//   - AD9144: 四通道 16bit DAC, 2.8Gsps, JESD204B (4L, 10Gbps)
//   - AD9250: 双通道 14bit ADC — 已剥离（本工程仅使用 DAC）
//   - 时钟：LMK04828, 板载 50M TCXO
//
// 时钟域：
//   - sys_clk:    100MHz 板载差分时钟 → 全局时钟
//   - glblclk:    125MHz FMC 输入 → JESD TX core_clk (250M)
//   - refclk:     125MHz FMC 输入 → GTX 参考时钟 (QPLL)
//   - clk_25m:    sys_mmcm 输出 → SPI 25MHz 控制时钟
//   - clk_axi:    sys_mmcm 输出 → AXI-Lite 100MHz 配置时钟
//
// 初始化顺序（状态机）：
//   LMK04828 → JESD TX复位 → AXI配置 → AD9144 → 完成
//
// 控制方式：
//   - 默认：板载按键 KEY0/KEY1 控制频率/波形/幅度/偏置
//   - 可选：UART (115200) 通过寄存器桥接远程控制 (AWG_UART_CONTROL)
//------------------------------------------------------------------------------

`timescale 1ns / 1ps

module awg_top (
    //==========================================================================
    // 板载时钟和复位
    //==========================================================================
    input  wire        sys_clk_p,       // 100MHz 差分时钟正端 (AE10)
    input  wire        sys_clk_n,       // 100MHz 差分时钟负端 (AF10)
    input  wire        sys_rst_n,       // 低电平复位 (AB25)

    //==========================================================================
    // FMC HPC — GTX 参考时钟
    //==========================================================================
    input  wire        fmc_gbtclk0_m2c_p,  // GTX RefClk 125M (G8)
    input  wire        fmc_gbtclk0_m2c_n,  // GTX RefClk 125M (G7)

    //==========================================================================
    // FMC HPC — JESD204B 全局时钟 (用于 core_clk 生成)
    //==========================================================================
    input  wire        fmc_glblclk_p,      // JESD glblclk 125M (D17)
    input  wire        fmc_glblclk_n,      // JESD glblclk 125M (D18)

    //==========================================================================
    // FMC HPC — JESD204B SYSREF (Subclass 1 确定性延迟)
    //==========================================================================
    input  wire        fmc_sysref_p,       // SYSREF+ (D14)
    input  wire        fmc_sysref_n,       // SYSREF- (C14)

    //==========================================================================
    // FMC HPC — DAC TX 高速差分 (AD9144, FPGA→子卡, 4L @10Gbps)
    //==========================================================================
    output wire        fmc_dp0_c2m_p, fmc_dp0_c2m_n,  // Lane0 (H2/H1)
    output wire        fmc_dp1_c2m_p, fmc_dp1_c2m_n,  // Lane1 (F2/F1)
    output wire        fmc_dp2_c2m_p, fmc_dp2_c2m_n,  // Lane2 (J4/J3)
    output wire        fmc_dp3_c2m_p, fmc_dp3_c2m_n,  // Lane3 (K2/K1)

    //==========================================================================
    // JESD204B 同步信号 (LVDS_25)
    //==========================================================================
    input  wire        dac_sync0_p, dac_sync0_n,      // DAC SYNC~ 子卡→FPGA (E19/D19)
    input  wire        dac_sync1_p, dac_sync1_n,      // DAC SYNC1 (D21/C21, unused)

    //==========================================================================
    // AD9144 SPI 控制 (LVCMOS25)
    //==========================================================================
    output wire        ad9144_spi_sclk,   // SCLK (C19)
    output wire        ad9144_spi_csb,    // CSN  (B19)
    inout  wire        ad9144_spi_sdio,   // SDIO (B18)
    output wire        ad9144_reset,      // RSTN (F18)
    output wire        ad9144_txen0,      // TXEN0 (D16)
    output wire        ad9144_txen1,      // TXEN1 (C16)

    //==========================================================================
    // LMK04828 SPI 控制 (LVCMOS25)
    //==========================================================================
    output wire        lmk04828_spi_sclk, // SCLK (E16)
    inout  wire        lmk04828_spi_sdio, // SDIO (J12)
    output wire        lmk04828_cs_n,     // CSN  (J11)
    output wire        lmk04828_reset,    // RST  (F15)

    //==========================================================================
    // 子卡状态
    //==========================================================================
    input  wire        fmc_prsnt,         // FMC 在位检测 (AF30)

    //==========================================================================
    // 板载控制与指示
    //==========================================================================
    input  wire        key0,              // KEY0 (A26)
    input  wire        key1,              // KEY1 (A25)
    output wire [1:0]  led,               // LED0/1 (R24/R23)

    // UART 控制接口 (通过 AWG_UART_CONTROL 宏启用)
    input  wire        uart_rxd,          // UART RX
    output wire        uart_txd,          // UART TX

    //==========================================================================
    // 扩展模块接口 (KiCad PCB: ST7789 TFT + EC11 编码器)
    //==========================================================================
    output wire        tft_dc,            // TFT 数据/命令切换
    output wire        tft_scl,           // TFT SPI 时钟
    output wire        tft_cs,            // TFT SPI 片选
    output wire        tft_sda,           // TFT SPI 数据
    output wire        tft_res,           // TFT 复位
    output wire        tft_blk,           // TFT 背光
    input  wire        ec11_a,            // EC11 A 相
    input  wire        ec11_b,            // EC11 B 相
    input  wire        ec11_m,            // EC11 按键
    output wire        ec11_ledk          // 扩展模块 LED
);

    //==========================================================================
    // 内部信号声明
    //==========================================================================

    // 时钟与复位
    wire sys_clk_bufg;
    wire clk_25m;
    wire clk_axi_100m;
    wire clk_mmcm_locked;
    wire w_rst_n, w_rst2_n;

    // GTX/GlblClk 时钟
    wire w_qpll_refclk;
    wire w_tx_core_clk, w_rx_core_clk;
    wire w_glbclk_mmcm_locked;

    // SPI 控制握手
    reg  lmk_datain_valid;
    wire lmk_datain_ready;
    reg  das_datain_valid;
    wire das_datain_ready;

    // JESD204B 内部信号
    wire w_common0_qpll_lock_out;
    wire w_tx_sync_from_pins;
    wire w_tx_sys_reset;
    wire w_sysref;
    wire w_tx_reset_gt;
    reg  r_jesd_tx_sys_reset;
    reg [3:0] state;
    reg [15:0] jesd_rst_delay_cnt;
    wire w_jesd_tx_sys_reset_vio;
    wire w_tx_reset_done;
    wire w_tx_aresetn;
    wire [3:0] w_gt_prbssel;

    // GTX 并行数据 (TX only)
    wire [31:0] gt0_txdata, gt1_txdata, gt2_txdata, gt3_txdata;
    wire [3:0]  gt0_txcharisk, gt1_txcharisk, gt2_txcharisk, gt3_txcharisk;

    // JESD TX AXI-Lite
    wire w_tx_s_axi_awready, w_tx_s_axi_wready, w_tx_s_axi_bvalid;
    wire [1:0] w_tx_s_axi_bresp;
    wire [11:0] w_tx_s_axi_awaddr;
    wire w_tx_s_axi_awvalid;
    wire [31:0] w_tx_s_axi_wdata;
    wire w_tx_s_axi_wvalid, w_tx_s_axi_bready;
    wire w_tx_axi_write_done;
    reg  w_tx_axi_ena;

    // DDS / DAC 数据
    wire [47:0] w_phase_inc;
    wire [47:0] w_phase_offset;
    wire [15:0] w_amplitude_q15;
    wire signed [15:0] w_offset;
    wire [1:0]  w_wave_mode;
    wire signed [15:0] w_awg_sample0, w_awg_sample1;
    wire signed [15:0] w_awg_sample2, w_awg_sample3;
    wire [11:0] w_awg_phase_addr0, w_awg_phase_addr1;
    wire w_awg_sample_valid;
    wire [127:0] w_awg_tx_tdata;

    // JESD TX data
    wire [3:0] w_tx_start_of_multiframe, w_tx_start_of_frame;
    wire [127:0] w_tx_tdata;
    wire w_tx_tready;

    // JESD TX SYSREF/SYNC (从 IP 引出)
    wire [3:0] w_tx_start_of_frame_from_ip, w_tx_start_of_multiframe_from_ip;
    wire w_tx_tready_from_ip;

    //==========================================================================
    // 按键控制层
    //==========================================================================
    wire [47:0] key_phase_inc;
    wire [47:0] key_phase_offset;
    wire [2:0]  key_wave_mode_3b;
    wire [15:0] key_amplitude;
    wire signed [15:0] key_offset;
    wire [1:0]  key_ui_mode;
    wire        key_freq_load;

    awg_key_ui_ctrl #(
        .DEBOUNCE_TICKS (32'd2_000_000),    // 20ms @ 100MHz
        .CHORD_TICKS    (32'd25_000_000),   // 250ms @ 100MHz
        .PHASE_W        (48),
        .DATA_W         (16)
    ) u_key_ctrl (
        .clk          (sys_clk_bufg),
        .rst_n        (sys_rst_n),
        .key0         (key0),
        .key1         (key1),
        .freq_load    (key_freq_load),
        .phase_inc    (key_phase_inc),
        .phase_offset (key_phase_offset),
        .wave_mode    (key_wave_mode_3b),
        .amplitude    (key_amplitude),
        .offset       (key_offset),
        .test_sample  (),
        .ui_mode      (key_ui_mode)
    );

    //==========================================================================
    // 时钟系统
    //==========================================================================

    // 板载 100MHz 差分时钟输入
    wire clk_ibuf;
    IBUFDS clk_ibufds (.I(sys_clk_p), .IB(sys_clk_n), .O(clk_ibuf));
    BUFG   clk_bufg   (.I(clk_ibuf), .O(sys_clk_bufg));

    // 系统时钟 MMCM：65M cfg → 25M SPI + 100M AXI
    // 注意：STARTUPE2 CFGMCLK 提供 65MHz 给 MMCM 输入
    wire EOS_n;
    wire cfg_clk;

    STARTUPE2 #(
        .PROG_USR("FALSE"),
        .SIM_CCLK_FREQ(0.0)
    ) STARTUPE2_inst (
        .CFGMCLK  (cfg_clk),
        .EOS      (EOS_n),
        .USRCCLKO (1'b0),
        .USRCCLKTS(1'b1)
    );

    clk_sys_mmcm clk_sys_mmcm_inst (
        .clk_out1(clk_25m),
        .clk_out2(clk_axi_100m),
        .locked  (clk_mmcm_locked),
        .clk_in1 (cfg_clk)
    );

    // 全局复位 — 必须等待 MMCM 锁定后才释放，避免时钟不稳定时启动 SPI
    wire w_mmcm_locked_rst_n;
    assign w_mmcm_locked_rst_n = EOS_n & clk_mmcm_locked;

    rst_module rst_module_inst (
        .i_sys_clk       (clk_25m),
        .i_sys_rst_async (w_mmcm_locked_rst_n),
        .o_mod1_rstn     (w_rst_n),
        .o_mod2_rstn     ()
    );

    //==========================================================================
    // SPI 配置 — LMK04828 时钟芯片
    //==========================================================================
    lmk_spi_wr_config lmk_spi_wr_config_inst (
        .clk_in       (clk_25m),
        .rst_n        (w_rst_n),
        .o_sclk       (lmk04828_spi_sclk),
        .io_sda       (lmk04828_spi_sdio),
        .o_cs_n       (lmk04828_cs_n),
        .o_lmk_rst    (lmk04828_reset),
        .datain_valid (lmk_datain_valid),
        .datain_ready (lmk_datain_ready)
    );

    //==========================================================================
    // SPI 配置 — AD9144 DAC
    //==========================================================================
    ad9144_spi_config AD9144_spi_wr_config_inst (
        .clk_in       (clk_25m),
        .rst_n        (w_rst_n),
        .o_sclk       (ad9144_spi_sclk),
        .io_sda       (ad9144_spi_sdio),
        .o_sen_n      (ad9144_spi_csb),
        .o_reset      (ad9144_reset),
        .datain_valid (das_datain_valid),
        .datain_ready (das_datain_ready)
    );

    assign ad9144_txen0 = 1'b1;
    assign ad9144_txen1 = 1'b1;

    //==========================================================================
    // JESD204B 复位与 AXI-Lite 配置
    //==========================================================================
    vio_for_jesd_rst vio_for_jesd_rst_debug (
        .clk        (clk_axi_100m),
        .probe_out0 (w_jesd_tx_sys_reset_vio)
    );

    assign w_tx_sys_reset = r_jesd_tx_sys_reset | w_jesd_tx_sys_reset_vio;

    jesd_axi_write jesd_axi_write_for_tx (
        .s_axi_aclk    (clk_axi_100m),
        .s_axi_aresetn (w_rst_n & w_tx_axi_ena),
        .s_axi_awready (w_tx_s_axi_awready),
        .s_axi_wready  (w_tx_s_axi_wready),
        .s_axi_bvalid  (w_tx_s_axi_bvalid),
        .s_axi_bresp   (w_tx_s_axi_bresp),
        .s_axi_awaddr  (w_tx_s_axi_awaddr),
        .s_axi_awvalid (w_tx_s_axi_awvalid),
        .s_axi_wdata   (w_tx_s_axi_wdata),
        .s_axi_wvalid  (w_tx_s_axi_wvalid),
        .s_axi_bready  (w_tx_s_axi_bready),
        .axi_write_done()
    );

    //==========================================================================
    // GTX 参考时钟缓冲
    //==========================================================================
    IBUFDS_GTE2 #(
        .CLKCM_CFG("TRUE"),
        .CLKRCV_TRST("TRUE"),
        .CLKSWING_CFG(2'b11)
    ) IBUFDS_GTE2_inst (
        .O     (w_qpll_refclk),
        .ODIV2 (),
        .CEB   (1'b0),
        .I     (fmc_gbtclk0_m2c_p),
        .IB    (fmc_gbtclk0_m2c_n)
    );

    //==========================================================================
    // JESD Core 时钟生成 — 恢复原始 clk_for_glbclk (师弟确认硬件可用)
    //==========================================================================
    clk_for_glbclk clk_for_glbclk_inst (
        .clk_out1 (w_rx_core_clk),
        .clk_out2 (w_tx_core_clk),
        .resetn   (w_rst_n),
        .locked   (w_glbclk_mmcm_locked),
        .clk_in1_p(fmc_glblclk_p),
        .clk_in1_n(fmc_glblclk_n)
    );

    //==========================================================================
    // 注册控制层（按键 + UART 共存）
    //==========================================================================
    wire        awg_reg_output_enable;
    wire        awg_reg_use_control;
    wire [47:0] awg_reg_phase_inc;
    wire [47:0] awg_reg_phase_offset;
    wire [15:0] awg_reg_amplitude_q15;
    wire signed [15:0] awg_reg_offset;
    wire [1:0]  awg_reg_wave_mode;
    wire        awg_reg_update_toggle;
    wire [31:0] awg_reg_read_data;
    wire        awg_cfg_wr_en;
    wire        awg_cfg_rd_en;
    wire [7:0]  awg_cfg_addr;
    wire [31:0] awg_cfg_wdata;
    wire [1:0]  awg_reg_range_sel;
    wire        awg_reg_output_en;
    wire        awg_reg_cal_enable;
    wire        awg_reg_cal_wr_en;
    wire [3:0]  awg_reg_cal_wr_addr;
    wire [31:0] awg_reg_cal_wr_data;
    wire        awg_reg_cal_rd_en;
    wire [3:0]  awg_reg_cal_rd_addr;
    wire [31:0] awg_reg_cal_rd_data;

    // Character display pipeline
    wire [8:0]  grid_rd_addr;
    wire [7:0]  grid_rd_data;
    reg  [7:0]  grid_wr_data;
    reg         grid_wr_en;
    reg  [8:0]  grid_wr_addr;
    wire [6:0]  font_char_code;
    wire [3:0]  font_row;
    wire [7:0]  font_bitmap;
    wire [15:0] tft_pixel_data;
    wire        tft_pixel_valid;
    wire        tft_pixel_ready;

    // Sweep engine control wires
    wire        awg_reg_sweep_enable;
    wire        awg_reg_sweep_dir;
    wire        awg_reg_sweep_log_mode;
    wire [47:0] awg_reg_sweep_start_inc;
    wire [47:0] awg_reg_sweep_stop_inc;
    wire [47:0] awg_reg_sweep_step_inc;
    wire [31:0] awg_reg_sweep_dwell;
    wire [47:0] w_sweep_phase_inc;
    wire        w_sweep_active;

    // Expansion module - EC11 encoder + ST7789 display
    wire signed [7:0] ec11_rotation;
    wire        ec11_btn_short, ec11_btn_long;
    wire        ec11_cfg_wr_en;
    wire [7:0]  ec11_cfg_addr;
    wire [31:0] ec11_cfg_wdata;
    wire        ec11_apply;

`ifdef AWG_UART_CONTROL
    wire awg_uart_activity;
    wire uart_cfg_wr_en;
    wire [7:0] uart_cfg_addr;
    wire [31:0] uart_cfg_wdata;

    ad9144_uart_reg_bridge #(
        .CLK_HZ(250000000),
        .BAUD(115200)
    ) u_ad9144_uart_reg_bridge (
        .clk            (w_tx_core_clk),
        .rst_n          (w_rst_n),
        .uart_rxd       (uart_rxd),
        .uart_txd       (uart_txd),
        .cfg_wr_en      (uart_cfg_wr_en),
        .cfg_rd_en      (awg_cfg_rd_en),
        .cfg_addr       (uart_cfg_addr),
        .cfg_wdata      (uart_cfg_wdata),
        .cfg_rdata      (awg_reg_read_data),
        .activity_toggle(awg_uart_activity)
    );
`else
    wire uart_cfg_wr_en = 1'b0;
    wire [7:0] uart_cfg_addr = 8'd0;
    wire [31:0] uart_cfg_wdata = 32'd0;
    assign awg_cfg_rd_en = 1'b0;
`endif

    // EC11 + UART bus mux (UART priority for both read and write)
    wire uart_bus_active = uart_cfg_wr_en | awg_cfg_rd_en;
    assign awg_cfg_wr_en = uart_cfg_wr_en | ec11_cfg_wr_en;
    assign awg_cfg_addr  = uart_bus_active ? uart_cfg_addr : ec11_cfg_addr;
    assign awg_cfg_wdata = uart_cfg_wr_en ? uart_cfg_wdata : ec11_cfg_wdata;

    ad9144_awg_reg_bank u_ad9144_awg_reg_bank (
        .clk              (w_tx_core_clk),
        .rst_n            (w_rst_n),
        .cfg_wr_en        (awg_cfg_wr_en),
        .cfg_rd_en        (awg_cfg_rd_en),
        .cfg_addr         (awg_cfg_addr),
        .cfg_wdata        (awg_cfg_wdata),
        .cfg_rdata        (awg_reg_read_data),
        .output_enable    (awg_reg_output_enable),
        .use_reg_control  (awg_reg_use_control),
        .phase_inc        (awg_reg_phase_inc),
        .phase_offset     (awg_reg_phase_offset),
        .amplitude_q15    (awg_reg_amplitude_q15),
        .offset           (awg_reg_offset),
        .wave_mode        (awg_reg_wave_mode),
        .update_toggle    (awg_reg_update_toggle),
        .button_ui_mode   (key_ui_mode),
        .button_freq_sel  (key_phase_inc[2:0]),
        .button_amp_sel   (key_amplitude[2:0]),
        .button_phase_sel (key_phase_offset[2:0]),
        .button_wave_sel  (key_wave_mode_3b[1:0]),
        .tx_ready         (w_tx_tready),
        .tx_sync          (w_tx_sync_from_pins),
        .sysref_seen      (w_sysref),
        .sample_valid     (w_awg_sample_valid),
        .sweep_active_in  (w_sweep_active),
        .ec11_a_in        (ec11_a),
        .ec11_b_in        (ec11_b),
        .ec11_btn_in      (ec11_m),
        .range_sel        (awg_reg_range_sel),
        .output_en        (awg_reg_output_en),
        .cal_enable       (awg_reg_cal_enable),
        .cal_wr_en        (awg_reg_cal_wr_en),
        .cal_wr_addr      (awg_reg_cal_wr_addr),
        .cal_wr_data      (awg_reg_cal_wr_data),
        .cal_rd_en        (awg_reg_cal_rd_en),
        .cal_rd_addr      (awg_reg_cal_rd_addr),
        .cal_rd_data      (awg_reg_cal_rd_data),
        .sweep_enable     (awg_reg_sweep_enable),
        .sweep_dir        (awg_reg_sweep_dir),
        .sweep_log_mode   (awg_reg_sweep_log_mode),
        .sweep_start_inc  (awg_reg_sweep_start_inc),
        .sweep_stop_inc   (awg_reg_sweep_stop_inc),
        .sweep_step_inc   (awg_reg_sweep_step_inc),
        .sweep_dwell      (awg_reg_sweep_dwell),

        // Debug: expose init state and MMCM lock
        .init_state           (state),
        .glblclk_mmcm_locked  (w_glbclk_mmcm_locked)
    );

    wire [47:0] phase_inc    = awg_reg_use_control ? awg_reg_phase_inc : key_phase_inc;

    // Sweep engine between phase_inc and DDS
    sweep_engine #(.PHASE_W(48)) u_sweep_engine (
        .clk               (w_tx_core_clk),
        .rst_n             (w_rst_n),
        .enable            (awg_reg_sweep_enable),
        .sweep_dir         (awg_reg_sweep_dir),
        .sweep_log_mode    (awg_reg_sweep_log_mode),
        .dyn_start_inc     (awg_reg_sweep_start_inc),
        .dyn_stop_inc      (awg_reg_sweep_stop_inc),
        .dyn_step_inc      (awg_reg_sweep_step_inc),
        .dyn_dwell         (awg_reg_sweep_dwell),
        .manual_phase_inc  (phase_inc),
        .phase_inc_out     (w_sweep_phase_inc),
        .sweep_active      (w_sweep_active)
    );

    wire [15:0] amp_q15      = awg_reg_use_control ? awg_reg_amplitude_q15 : key_amplitude;
    wire [47:0] phase_offset = awg_reg_use_control ? awg_reg_phase_offset : key_phase_offset;
    wire [1:0]  wave_mode    = awg_reg_use_control ? awg_reg_wave_mode : key_wave_mode_3b[1:0];
    wire signed [15:0] awg_offset = awg_reg_use_control ? awg_reg_offset : 16'sd0;

    //==========================================================================
    // 数字校准模块 — 频率分bin增益/偏置补偿
    //==========================================================================
    wire [15:0] amp_q15_calibrated;

    ad9144_awg_cal u_ad9144_awg_cal (
        .clk               (w_tx_core_clk),
        .rst_n             (w_rst_n),
        .cal_enable        (awg_reg_cal_enable),
        .range_sel         (awg_reg_range_sel),
        .phase_inc         (w_sweep_phase_inc),
        .amplitude_q15_in  (amp_q15),
        .amplitude_q15_out (amp_q15_calibrated),
        .cal_wr_en         (awg_reg_cal_wr_en),
        .cal_wr_addr       (awg_reg_cal_wr_addr),
        .cal_wr_data       (awg_reg_cal_wr_data),
        .cal_rd_en         (awg_reg_cal_rd_en),
        .cal_rd_addr       (awg_reg_cal_rd_addr),
        .cal_rd_data       (awg_reg_cal_rd_data)
    );

    //==========================================================================
    // 4-采样每周期 DDS (JESD204B 需要 4 样本/beat)
    //==========================================================================
    ad9144_awg_dds4 #(
        .INIT_FILE("../../ad9144_sine_4096.hex")
    ) u_ad9144_awg_dds4 (
        .clk           (w_tx_core_clk),
        .rst_n         (w_rst_n),
        .phase_inc     (w_sweep_phase_inc),
        .phase_offset  (phase_offset),
        .wave_mode     (wave_mode),
        .amplitude_q15 (amp_q15_calibrated),
        .offset        (awg_offset),
        .sample0       (w_awg_sample0),
        .sample1       (w_awg_sample1),
        .sample2       (w_awg_sample2),
        .sample3       (w_awg_sample3),
        .phase_addr0   (w_awg_phase_addr0),
        .phase_addr1   (w_awg_phase_addr1),
        .phase_addr2   (),
        .phase_addr3   (),
        .sample_valid  (w_awg_sample_valid),
        // FMCW chirp — disabled by default, enable via future reg_bank extension
        .chirp_en      (1'b0),
        .chirp_slope   (48'd0),
        .chirp_start_inc(48'd0),
        .chirp_stop_inc(48'd0)
    );

    ad9144_sample_packer u_ad9144_sample_packer (
        .sample0 (w_awg_sample0),
        .sample1 (w_awg_sample1),
        .sample2 (w_awg_sample2),
        .sample3 (w_awg_sample3),
        .tx_tdata(w_awg_tx_tdata)
    );

    assign w_tx_tdata = awg_reg_output_enable ? w_awg_tx_tdata : 128'd0;

    //==========================================================================
    // SYSREF 输入缓冲
    //==========================================================================
    IBUFDS IBUFDS_sysref (
        .O (w_sysref),
        .I (fmc_sysref_p),
        .IB(fmc_sysref_n)
    );

    // DAC SYNC 输入缓冲
    IBUFDS IBUFDS_tx_sync (
        .O (w_tx_sync_from_pins),
        .I (dac_sync0_p),
        .IB(dac_sync0_n)
    );

    //==========================================================================
    // JESD204B PHY (GTX 收发器 — TX only, ADC 已剥离)
    //==========================================================================
    jesd204_phy_0 jesd204_phy_txrx_inst (
        .cpll_refclk            (w_qpll_refclk),
        .qpll_refclk            (w_qpll_refclk),
        .drpclk                 (clk_axi_100m),
        .tx_reset_gt            (w_tx_reset_gt),
        .tx_sys_reset           (w_tx_sys_reset),
        .txp_out                ({fmc_dp3_c2m_p, fmc_dp2_c2m_p, fmc_dp1_c2m_p, fmc_dp0_c2m_p}),
        .txn_out                ({fmc_dp3_c2m_n, fmc_dp2_c2m_n, fmc_dp1_c2m_n, fmc_dp0_c2m_n}),
        .tx_core_clk            (w_tx_core_clk),
        .txoutclk               (),
        .gt_prbssel             (w_gt_prbssel),
        .gt0_txdata             (gt0_txdata),
        .gt0_txcharisk          (gt0_txcharisk),
        .gt1_txdata             (gt1_txdata),
        .gt1_txcharisk          (gt1_txcharisk),
        .gt2_txdata             (gt2_txdata),
        .gt2_txcharisk          (gt2_txcharisk),
        .gt3_txdata             (gt3_txdata),
        .gt3_txcharisk          (gt3_txcharisk),
        .tx_reset_done          (w_tx_reset_done),
        .common0_qpll_clk_out   (),
        .common0_qpll_refclk_out(),
        .common0_qpll_lock_out  (w_common0_qpll_lock_out)
    );

    //==========================================================================
    // JESD204B TX Core (AD9144 DAC → FPGA)
    //==========================================================================
    jesd204_tx jesd204_tx_inst (
        .gt0_txdata             (gt0_txdata),
        .gt0_txcharisk          (gt0_txcharisk),
        .gt1_txdata             (gt1_txdata),
        .gt1_txcharisk          (gt1_txcharisk),
        .gt2_txdata             (gt2_txdata),
        .gt2_txcharisk          (gt2_txcharisk),
        .gt3_txdata             (gt3_txdata),
        .gt3_txcharisk          (gt3_txcharisk),
        .tx_reset_done          (w_tx_reset_done),
        .gt_prbssel_out         (w_gt_prbssel),
        .tx_reset_gt            (w_tx_reset_gt),
        .tx_core_clk            (w_tx_core_clk),
        .s_axi_aclk             (clk_axi_100m),
        .s_axi_aresetn          (w_rst_n),
        .s_axi_awaddr           (w_tx_s_axi_awaddr),
        .s_axi_awvalid          (w_tx_s_axi_awvalid),
        .s_axi_awready          (w_tx_s_axi_awready),
        .s_axi_wdata            (w_tx_s_axi_wdata),
        .s_axi_wstrb            (4'b1111),
        .s_axi_wvalid           (w_tx_s_axi_wvalid),
        .s_axi_wready           (w_tx_s_axi_wready),
        .s_axi_bresp            (w_tx_s_axi_bresp),
        .s_axi_bvalid           (w_tx_s_axi_bvalid),
        .s_axi_bready           (w_tx_s_axi_bready),
        .s_axi_araddr           (12'd0),
        .s_axi_arvalid          (1'b0),
        .s_axi_arready          (),
        .s_axi_rdata            (),
        .s_axi_rresp            (),
        .s_axi_rvalid           (),
        .s_axi_rready           (1'b0),
        .tx_reset               (w_tx_sys_reset),
        .tx_sysref              (w_sysref),
        .tx_start_of_frame      (w_tx_start_of_frame_from_ip),
        .tx_start_of_multiframe (w_tx_start_of_multiframe_from_ip),
        .tx_aresetn             (w_tx_aresetn),
        .tx_tdata               (w_tx_tdata),
        .tx_tready              (w_tx_tready),
        .tx_sync                (w_tx_sync_from_pins)
    );

    //==========================================================================
    // 初始化状态机
    //
    // 顺序：LMK04828 → JESD TX复位 → AXI配置 → AD9144 → 完成
    // （AD9250/ADC 已剥离，JESD RX 已移除）
    //==========================================================================

    always @(posedge clk_25m) begin
        if (!w_rst_n) begin
            state            <= 4'd0;
            lmk_datain_valid <= 1'b0;
            das_datain_valid <= 1'b0;
            r_jesd_tx_sys_reset <= 1'b0;
            jesd_rst_delay_cnt  <= 16'd0;
            w_tx_axi_ena        <= 1'b1;
        end else begin
            case (state)
                4'd0: begin
                    lmk_datain_valid <= 1'b0;
                    das_datain_valid <= 1'b0;
                    state <= 4'd1;
                end
                4'd1: begin
                    if (lmk_datain_ready) begin
                        lmk_datain_valid <= 1'b1;
                        state <= 4'd2;
                    end else begin
                        lmk_datain_valid <= 1'b0;
                        state <= 4'd1;
                    end
                end
                4'd2: begin
                    state <= 4'd3;
                end
                4'd3: begin
                    if (!lmk_datain_ready) begin
                        lmk_datain_valid <= 1'b0;
                        state <= 4'd4;
                    end else begin
                        lmk_datain_valid <= 1'b1;
                        state <= 4'd3;
                    end
                end
                4'd4: begin
                    if (jesd_rst_delay_cnt < 16'd1000) begin
                        r_jesd_tx_sys_reset <= 1'b1;
                        w_tx_axi_ena        <= 1'b1;
                        jesd_rst_delay_cnt  <= jesd_rst_delay_cnt + 16'd1;
                        state <= 4'd4;
                    end else if (jesd_rst_delay_cnt < 16'd20000) begin
                        r_jesd_tx_sys_reset <= 1'b0;
                        w_tx_axi_ena        <= 1'b1;
                        jesd_rst_delay_cnt  <= jesd_rst_delay_cnt + 16'd1;
                        state <= 4'd4;
                    end else if (jesd_rst_delay_cnt < 16'd60000) begin
                        r_jesd_tx_sys_reset <= 1'b0;
                        w_tx_axi_ena        <= 1'b0;
                        jesd_rst_delay_cnt  <= jesd_rst_delay_cnt + 16'd1;
                        state <= 4'd4;
                    end else begin
                        r_jesd_tx_sys_reset <= 1'b0;
                        w_tx_axi_ena        <= 1'b1;
                        jesd_rst_delay_cnt  <= 16'd0;
                        state <= 4'd5;
                    end
                end
                4'd5: begin
                    if (das_datain_ready) begin
                        das_datain_valid <= 1'b1;
                        state <= 4'd6;
                    end else begin
                        das_datain_valid <= 1'b0;
                        state <= 4'd5;
                    end
                end
                4'd6: begin
                    if (!das_datain_ready) begin
                        das_datain_valid <= 1'b0;
                        state <= 4'd7;
                    end else begin
                        das_datain_valid <= 1'b1;
                        state <= 4'd6;
                    end
                end
                4'd7: begin
                    state <= 4'd7;
                end
                default: state <= 4'd0;
            endcase
        end
    end

    //==========================================================================
    // Expansion module - EC11 encoder decode
    //==========================================================================
    ec11_decoder #(
        .CLK_HZ(25000000)
    ) u_ec11_decoder (
        .clk        (clk_25m),
        .rst_n      (w_rst_n),
        .ec11_a     (ec11_a),
        .ec11_b     (ec11_b),
        .ec11_btn   (ec11_m),
        .rotation   (ec11_rotation),
        .btn_short  (ec11_btn_short),
        .btn_long   (ec11_btn_long)
    );

    // EC11 -> AWG register bridge
    ec11_awg_bridge u_ec11_awg_bridge (
        .clk        (clk_25m),
        .rst_n      (w_rst_n),
        .rotation   (ec11_rotation),
        .btn_short  (ec11_btn_short),
        .btn_long   (ec11_btn_long),
        .wr_en      (ec11_cfg_wr_en),
        .wr_addr    (ec11_cfg_addr),
        .wr_data    (ec11_cfg_wdata),
        .apply_trig (ec11_apply),
        .param_page (),
        .activity   ()
    );

    // Character display pipeline: grid -> renderer -> ST7789
    char_grid u_char_grid (
        .clk(clk_25m), .wr_en(grid_wr_en), .wr_addr(grid_wr_addr),
        .wr_data(grid_wr_data), .rd_addr(grid_rd_addr), .rd_data(grid_rd_data)
    );
    char_rom #(.FONT_FILE("../../rtl/control/font_8x16.hex")) u_char_rom (
        .clk(clk_25m), .char_code(font_char_code), .row(font_row), .bitmap(font_bitmap)
    );
    tile_renderer u_tile_renderer (
        .clk(clk_25m), .rst_n(w_rst_n),
        .char_addr(grid_rd_addr), .char_code(grid_rd_data),
        .font_char(font_char_code), .font_row(font_row), .font_bitmap(font_bitmap),
        .pixel_data(tft_pixel_data), .pixel_valid(tft_pixel_valid), .pixel_ready(tft_pixel_ready),
        .fg_color(16'hFFFF), .bg_color(16'h0000), .title_color(16'h001F),
        .status_color(16'h001F), .cursor_color(16'h07E0),
        .cursor_row(5'd0), .cursor_col(5'd0),
        .frame_start(), .vsync()
    );
    wire tft_init_done;
    st7789_driver u_st7789_driver (
        .clk(clk_25m), .rst_n(w_rst_n),
        .tft_scl(tft_scl), .tft_sda(tft_sda), .tft_cs(tft_cs),
        .tft_dc(tft_dc), .tft_res(tft_res), .tft_blk(tft_blk),
        .pixel_data(tft_pixel_data), .pixel_valid(tft_pixel_valid), .pixel_ready(tft_pixel_ready),
        .frame_done(), .init_done(tft_init_done)
    );

    // Startup: write "AWG" to char_grid after init
    reg [15:0] startup_timer;
    reg [3:0]  startup_idx;
    always @(posedge clk_25m or negedge w_rst_n) begin
        if (!w_rst_n) begin
            startup_timer <= 0; startup_idx <= 0;
            grid_wr_en <= 0; grid_wr_addr <= 0; grid_wr_data <= 0;
        end else begin
            grid_wr_en <= 0;
            if (!tft_init_done) begin
                startup_timer <= 0; startup_idx <= 0;
            end else if (startup_idx < 8) begin
                if (startup_timer > 50000) begin
                    startup_timer <= 0;
                    grid_wr_en <= 1;
                    grid_wr_addr <= 9'd210 + startup_idx; // row 7, col 0-7
                    case (startup_idx)
                        0: grid_wr_data <= 8'h20; // space
                        1: grid_wr_data <= 8'h41; // A
                        2: grid_wr_data <= 8'h57; // W
                        3: grid_wr_data <= 8'h47; // G
                        4: grid_wr_data <= 8'h20; // space
                        5: grid_wr_data <= 8'h4F; // O
                        6: grid_wr_data <= 8'h4B; // K
                        7: grid_wr_data <= 8'h20; // space
                    endcase
                    startup_idx <= startup_idx + 1;
                end else begin
                    startup_timer <= startup_timer + 1;
                end
            end
        end
    end


    // Expansion module LED: ON = TFT init done, BLINK = EC11 activity
    assign ec11_ledk = tft_init_done | ec11_apply;

    //==========================================================================
    // LED 指示
    //==========================================================================
    // DIAG: show init state on wave_led (instead of DDS sample, which needs LMK clock)
    reg [1:0] w_wave_led;
    always @(posedge clk_25m) begin
        if (!w_rst_n)
            w_wave_led <= 2'b00;
        else if (w_common0_qpll_lock_out)
            w_wave_led <= 2'b11;  // QPLL locked - everything OK
        else
            w_wave_led <= state[1:0];  // show init state machine progress
    end

    awg_led_status #(
        .STATUS_TICKS (32'd100_000_000)
    ) u_led_status (
        .clk       (sys_clk_bufg),
        .rst_n     (sys_rst_n),
        .ui_mode   (key_ui_mode),
        .wave_mode (key_wave_mode_3b),
        .phase_inc (key_phase_inc),
        .amplitude (key_amplitude),
        .offset    (key_offset),
        .wave_led  (w_wave_led),
        .led       (led)
    );

    //==========================================================================
    // ILA 调试 (可选，通过 AWG_DEBUG_ILA 宏控制)
    //==========================================================================
`ifdef AWG_DEBUG_ILA
    ila_awg_debug u_ila_awg_debug (
        .clk    (w_tx_core_clk),
        .probe0 (key0),
        .probe1 (key1),
        .probe2 (sys_rst_n),
        .probe3 (key_ui_mode),
        .probe4 (key_wave_mode_3b),
        .probe5 (w_awg_sample_valid),
        .probe6 (phase_inc),
        .probe7 (amp_q15),
        .probe8 (awg_offset),
        .probe9 (w_awg_sample0),
        .probe10(w_awg_sample_valid),
        .probe11(8'b0),
        .probe12({state, w_common0_qpll_lock_out, w_tx_reset_done, w_tx_tready})
    );
`endif

endmodule
