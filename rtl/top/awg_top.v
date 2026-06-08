//------------------------------------------------------------------------------
// AWG Top Module - K325T with FMC ADDA (AD9144 + AD9250)
// 【AWG 统一顶层 — 正点原子 K325T + FMCADDA-9250-9144】
//
// 子卡：FMCADDA-9250-9144
//   - AD9144: 四通道 16bit DAC, 2.8Gsps, JESD204B (4L, 10Gbps)
//   - AD9250: 双通道 14bit ADC, 250Msps, JESD204B (2L, 5Gbps)
//   - 时钟：LMK04828, 板载 50M TCXO
//
// 时钟域：
//   - sys_clk:    100MHz 板载差分时钟 → 全局时钟
//   - glblclk:    125MHz FMC 输入 → JESD core_clk (250M tx / 125M rx)
//   - refclk:     125MHz FMC 输入 → GTX 参考时钟 (QPLL)
//   - clk_25m:    sys_mmcm 输出 → SPI 25MHz 控制时钟
//   - clk_axi:    sys_mmcm 输出 → AXI-Lite 100MHz 配置时钟
//
// 初始化顺序（状态机）：
//   LMK04828 → AD9250 → JESD TX复位 → AXI配置 → AD9144 → JESD RX复位
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
    // FMC HPC — ADC RX 高速差分 (AD9250, 子卡→FPGA, 2L @5Gbps)
    //==========================================================================
    input  wire        fmc_dp0_m2c_p, fmc_dp0_m2c_n,  // Lane0 (G4/G3)
    input  wire        fmc_dp1_m2c_p, fmc_dp1_m2c_n,  // Lane1 (F6/F5)

    //==========================================================================
    // JESD204B 同步信号 (LVDS_25)
    //==========================================================================
    input  wire        dac_sync0_p, dac_sync0_n,      // DAC SYNC~ 子卡→FPGA (E19/D19)
    input  wire        dac_sync1_p, dac_sync1_n,      // DAC SYNC1 (D21/C21, unused)
    output wire        adc_sync_p, adc_sync_n,         // ADC SYNC~ FPGA→子卡 (D22/C22)

    //==========================================================================
    // AD9250 SPI 控制 (LVCMOS25)
    //==========================================================================
    output wire        ad9250_spi_sclk,   // SCLK (F21)
    output wire        ad9250_spi_csb,    // CSN  (E21)
    inout  wire        ad9250_spi_sdio,   // SDIO (J18)
    output wire        ad9250_reset,      // RSTN (F20)

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
    output wire        lmk04828_spi_sclk, // SCLK (AD29)
    inout  wire        lmk04828_spi_sdio, // SDIO (AE29)
    output wire        lmk04828_cs_n,     // CSN
    output wire        lmk04828_reset,    // RST

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
    output wire        uart_txd           // UART TX
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
    reg  ads_datain_valid;
    wire ads_datain_ready;
    reg  das_datain_valid;
    wire das_datain_ready;

    // JESD204B 内部信号
    wire w_common0_qpll_lock_out;
    wire w_tx_sync, w_rx_sync;
    wire w_sysref;
    wire w_tx_reset_gt, w_rx_reset_gt;
    wire w_tx_sys_reset, w_rx_sys_reset;
    reg  r_jesd_tx_sys_reset, r_jesd_rx_sys_reset;
    wire w_jesd_tx_sys_reset_vio, w_jesd_rx_sys_reset_vio;
    wire w_rx_axi_ena;
    wire w_tx_reset_done, w_rx_reset_done;
    wire w_tx_aresetn;
    wire w_rxencommaalign_out;
    wire [3:0] w_gt_prbssel;

    // GTX 并行数据
    wire [31:0] gt0_txdata, gt1_txdata, gt2_txdata, gt3_txdata;
    wire [3:0]  gt0_txcharisk, gt1_txcharisk, gt2_txcharisk, gt3_txcharisk;
    wire [31:0] gt0_rxdata, gt1_rxdata;
    wire [3:0]  gt0_rxcharisk, gt1_rxcharisk;
    wire [3:0]  gt0_rxdisperr, gt1_rxdisperr;
    wire [3:0]  gt0_rxnotintable, gt1_rxnotintable;

    // JESD TX AXI-Lite
    wire w_tx_s_axi_awready, w_tx_s_axi_wready, w_tx_s_axi_bvalid;
    wire [1:0] w_tx_s_axi_bresp;
    wire [11:0] w_tx_s_axi_awaddr;
    wire w_tx_s_axi_awvalid;
    wire [31:0] w_tx_s_axi_wdata;
    wire w_tx_s_axi_wvalid, w_tx_s_axi_bready;
    wire w_tx_axi_write_done;
    reg  w_tx_axi_ena;

    // JESD RX AXI-Lite
    wire w_rx_s_axi_arready, w_rx_s_axi_rvalid;
    wire [1:0] w_rx_s_axi_rresp;
    wire [11:0] w_rx_s_axi_araddr;
    wire w_rx_s_axi_arvalid;
    wire [31:0] w_rx_s_axi_rdata;
    wire w_rx_s_axi_rready;

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

    // JESD RX (ADC) data
    wire [63:0] w_rx_tdata;
    wire w_rx_tvalid;
    wire [3:0] w_rx_start_of_frame, w_rx_end_of_frame;
    wire [3:0] w_rx_start_of_multiframe, w_rx_end_of_multiframe;
    wire [7:0] w_rx_frame_error;
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

    // 全局复位
    rst_module rst_module_inst (
        .i_sys_clk       (clk_25m),
        .i_sys_rst_async (EOS_n),
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
    // SPI 配置 — AD9250 ADC
    //==========================================================================
    ad9250_spi_config ad9250_spi_config_inst (
        .clk_in       (clk_25m),
        .rst_n        (w_rst_n),
        .o_sclk       (ad9250_spi_sclk),
        .io_sda       (ad9250_spi_sdio),
        .o_sen_n      (ad9250_spi_csb),
        .o_reset      (ad9250_reset),
        .datain_valid (ads_datain_valid),
        .datain_ready (ads_datain_ready)
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
        .probe_out0 (w_jesd_tx_sys_reset_vio),
        .probe_out1 (w_jesd_rx_sys_reset_vio),
        .probe_out2 (w_rx_axi_ena)
    );

    assign w_tx_sys_reset = r_jesd_tx_sys_reset | w_jesd_tx_sys_reset_vio;
    assign w_rx_sys_reset = r_jesd_rx_sys_reset | w_jesd_rx_sys_reset_vio;

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

    jesd_axi_read jesd_axi_read_for_rx (
        .s_axi_aclk    (clk_axi_100m),
        .s_axi_aresetn (w_rst_n & w_rx_axi_ena),
        .s_axi_arready (w_rx_s_axi_arready),
        .s_axi_rvalid  (w_rx_s_axi_rvalid),
        .s_axi_rresp   (w_rx_s_axi_rresp),
        .s_axi_araddr  (w_rx_s_axi_araddr),
        .s_axi_arvalid (w_rx_s_axi_arvalid),
        .s_axi_rdata   (w_rx_s_axi_rdata),
        .s_axi_rready  (w_rx_s_axi_rready)
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
    // JESD Core 时钟生成
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
    wire [15:0] awg_cal_amplitude_q15;

`ifdef AWG_UART_CONTROL
    wire awg_uart_activity;

    ad9144_uart_reg_bridge #(
        .CLK_HZ(250000000),
        .BAUD(115200)
    ) u_ad9144_uart_reg_bridge (
        .clk            (w_tx_core_clk),
        .rst_n          (w_rst_n),
        .uart_rxd       (uart_rxd),
        .uart_txd       (uart_txd),
        .cfg_wr_en      (awg_cfg_wr_en),
        .cfg_rd_en      (awg_cfg_rd_en),
        .cfg_addr       (awg_cfg_addr),
        .cfg_wdata      (awg_cfg_wdata),
        .cfg_rdata      (awg_reg_read_data),
        .activity_toggle(awg_uart_activity)
    );
`else
    assign awg_cfg_wr_en = 1'b0;
    assign awg_cfg_rd_en = 1'b0;
    assign awg_cfg_addr  = 8'd0;
    assign awg_cfg_wdata = 32'd0;
`endif

    ad9144_awg_reg_bank u_ad9144_awg_reg_bank (
        .clk              (w_tx_core_clk),
        .rst_n            (w_rst_n),
        .cfg_wr_en        (awg_cfg_wr_en),
        .cfg_addr         (awg_cfg_addr),
        .cfg_wdata        (awg_cfg_wdata),
        .cfg_rd_en        (awg_cfg_rd_en),
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
        .tx_sync          (w_tx_sync),
        .sysref_seen      (w_sysref),
        .sample_valid     (w_awg_sample_valid),
        .range_sel        (awg_reg_range_sel),
        .output_en        (awg_reg_output_en),
        .cal_enable       (awg_reg_cal_enable),
        .cal_wr_en        (awg_reg_cal_wr_en),
        .cal_wr_addr      (awg_reg_cal_wr_addr),
        .cal_wr_data      (awg_reg_cal_wr_data),
        .cal_rd_en        (awg_reg_cal_rd_en),
        .cal_rd_addr      (awg_reg_cal_rd_addr),
        .cal_rd_data      (awg_reg_cal_rd_data)
    );

    //==========================================================================
    // 数字校准
    //==========================================================================
    ad9144_awg_cal u_ad9144_awg_cal (
        .clk               (w_tx_core_clk),
        .rst_n             (w_rst_n),
        .cal_enable        (awg_reg_cal_enable),
        .range_sel         (awg_reg_range_sel),
        .phase_inc         (awg_reg_use_control ? awg_reg_phase_inc : key_phase_inc),
        .amplitude_q15_in  (awg_reg_amplitude_q15),
        .amplitude_q15_out (awg_cal_amplitude_q15),
        .cal_wr_en         (awg_reg_cal_wr_en),
        .cal_wr_addr       (awg_reg_cal_wr_addr),
        .cal_wr_data       (awg_reg_cal_wr_data),
        .cal_rd_en         (awg_reg_cal_rd_en),
        .cal_rd_addr       (awg_reg_cal_rd_addr),
        .cal_rd_data       (awg_reg_cal_rd_data)
    );

    wire [47:0] phase_inc    = awg_reg_use_control ? awg_reg_phase_inc : key_phase_inc;
    wire [15:0] amp_q15      = awg_reg_use_control ? awg_cal_amplitude_q15 : key_amplitude;
    wire [47:0] phase_offset = awg_reg_use_control ? awg_reg_phase_offset : key_phase_offset;
    wire [1:0]  wave_mode    = awg_reg_use_control ? awg_reg_wave_mode : key_wave_mode_3b[1:0];
    wire signed [15:0] awg_offset = awg_reg_use_control ? awg_reg_offset : 16'sd0;

    //==========================================================================
    // 4-采样每周期 DDS (JESD204B 需要 4 样本/beat)
    //==========================================================================
    ad9144_awg_dds4 #(
        .INIT_FILE("ad9144_sine_4096.hex")
    ) u_ad9144_awg_dds4 (
        .clk           (w_tx_core_clk),
        .rst_n         (w_rst_n),
        .phase_inc     (phase_inc),
        .phase_offset  (phase_offset),
        .wave_mode     (wave_mode),
        .amplitude_q15 (amp_q15),
        .offset        (awg_offset),
        .sample0       (w_awg_sample0),
        .sample1       (w_awg_sample1),
        .sample2       (w_awg_sample2),
        .sample3       (w_awg_sample3),
        .phase_addr0   (w_awg_phase_addr0),
        .phase_addr1   (w_awg_phase_addr1),
        .phase_addr2   (),
        .phase_addr3   (),
        .sample_valid  (w_awg_sample_valid)
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
    wire w_tx_sync_from_pins;
    IBUFDS IBUFDS_tx_sync (
        .O (w_tx_sync_from_pins),
        .I (dac_sync0_p),
        .IB(dac_sync0_n)
    );

    // ADC SYNC 输出缓冲
    OBUFDS OBUFDS_rx_sync (
        .O  (adc_sync_p),
        .OB (adc_sync_n),
        .I  (w_rx_sync)
    );

    //==========================================================================
    // JESD204B PHY (GTX 收发器)
    //==========================================================================
    jesd204_phy_0 jesd204_phy_txrx_inst (
        .cpll_refclk            (w_qpll_refclk),
        .qpll_refclk            (w_qpll_refclk),
        .drpclk                 (clk_axi_100m),
        .tx_reset_gt            (w_tx_reset_gt),
        .rx_reset_gt            (w_rx_reset_gt),
        .tx_sys_reset           (w_tx_sys_reset),
        .rx_sys_reset           (w_rx_sys_reset),
        .txp_out                ({fmc_dp3_c2m_p, fmc_dp2_c2m_p, fmc_dp1_c2m_p, fmc_dp0_c2m_p}),
        .txn_out                ({fmc_dp3_c2m_n, fmc_dp2_c2m_n, fmc_dp1_c2m_n, fmc_dp0_c2m_n}),
        .rxp_in                 ({fmc_dp1_m2c_p, fmc_dp0_m2c_p}),
        .rxn_in                 ({fmc_dp1_m2c_n, fmc_dp0_m2c_n}),
        .tx_core_clk            (w_tx_core_clk),
        .rx_core_clk            (w_rx_core_clk),
        .txoutclk               (),
        .rxoutclk               (),
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
        .gt0_rxdata             (gt0_rxdata),
        .gt0_rxcharisk          (gt0_rxcharisk),
        .gt0_rxdisperr          (gt0_rxdisperr),
        .gt0_rxnotintable       (gt0_rxnotintable),
        .gt1_rxdata             (gt1_rxdata),
        .gt1_rxcharisk          (gt1_rxcharisk),
        .gt1_rxdisperr          (gt1_rxdisperr),
        .gt1_rxnotintable       (gt1_rxnotintable),
        .gt2_rxdata             (),
        .gt2_rxcharisk          (),
        .gt2_rxdisperr          (),
        .gt2_rxnotintable       (),
        .gt3_rxdata             (),
        .gt3_rxcharisk          (),
        .gt3_rxdisperr          (),
        .gt3_rxnotintable       (),
        .rx_reset_done          (w_rx_reset_done),
        .rxencommaalign         (w_rxencommaalign_out),
        .common0_qpll_clk_out   (),
        .common0_qpll_refclk_out(),
        .common0_qpll_lock_out  (w_common0_qpll_lock_out)
    );

    //==========================================================================
    // JESD204B RX Core (AD9250 ADC ← FPGA)
    //==========================================================================
    jesd204_rx jesd204_rx_inst (
        .gt0_rxdata             (gt0_rxdata),
        .gt0_rxcharisk          (gt0_rxcharisk),
        .gt0_rxdisperr          (gt0_rxdisperr),
        .gt0_rxnotintable       (gt0_rxnotintable),
        .gt1_rxdata             (gt1_rxdata),
        .gt1_rxcharisk          (gt1_rxcharisk),
        .gt1_rxdisperr          (gt1_rxdisperr),
        .gt1_rxnotintable       (gt1_rxnotintable),
        .rx_reset_done          (w_rx_reset_done),
        .rxencommaalign_out     (w_rxencommaalign_out),
        .rx_reset_gt            (w_rx_reset_gt),
        .rx_core_clk            (w_rx_core_clk),
        .s_axi_aclk             (clk_axi_100m),
        .s_axi_aresetn          (w_rst_n),
        .s_axi_awaddr           (12'd0),
        .s_axi_awvalid          (1'b0),
        .s_axi_awready          (),
        .s_axi_wdata            (32'd0),
        .s_axi_wstrb            (4'b1111),
        .s_axi_wvalid           (1'b0),
        .s_axi_wready           (),
        .s_axi_bresp            (),
        .s_axi_bvalid           (),
        .s_axi_bready           (1'b0),
        .s_axi_araddr           (12'd0),
        .s_axi_arvalid          (1'b0),
        .s_axi_arready          (),
        .s_axi_rdata            (),
        .s_axi_rresp            (),
        .s_axi_rvalid           (),
        .s_axi_rready           (1'b0),
        .rx_reset               (w_rx_sys_reset),
        .rx_aresetn             (),
        .rx_tdata               (w_rx_tdata),
        .rx_tvalid              (w_rx_tvalid),
        .rx_start_of_frame      (w_rx_start_of_frame),
        .rx_end_of_frame        (w_rx_end_of_frame),
        .rx_start_of_multiframe (w_rx_start_of_multiframe),
        .rx_end_of_multiframe   (w_rx_end_of_multiframe),
        .rx_frame_error         (w_rx_frame_error),
        .rx_sysref              (w_sysref),
        .rx_sync                (w_rx_sync)
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
        .s_axi_araddr           (w_rx_s_axi_araddr),
        .s_axi_arvalid          (w_rx_s_axi_arvalid),
        .s_axi_arready          (w_rx_s_axi_arready),
        .s_axi_rdata            (w_rx_s_axi_rdata),
        .s_axi_rresp            (w_rx_s_axi_rresp),
        .s_axi_rvalid           (w_rx_s_axi_rvalid),
        .s_axi_rready           (w_rx_s_axi_rready),
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
    // 顺序：LMK04828 → AD9250 → JESD TX复位 → AXI配置 → AD9144 → JESD RX复位
    //==========================================================================
    reg [3:0] state;
    reg [15:0] jesd_rst_delay_cnt;

    always @(posedge clk_25m) begin
        if (!w_rst_n) begin
            state            <= 4'd0;
            lmk_datain_valid <= 1'b0;
            ads_datain_valid <= 1'b0;
            das_datain_valid <= 1'b0;
            r_jesd_rx_sys_reset <= 1'b0;
            r_jesd_tx_sys_reset <= 1'b0;
            jesd_rst_delay_cnt  <= 16'd0;
            w_tx_axi_ena        <= 1'b1;
        end else begin
            case (state)
                4'd0: begin
                    lmk_datain_valid <= 1'b0;
                    ads_datain_valid <= 1'b0;
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
                    if (lmk_datain_ready && ads_datain_ready) begin
                        ads_datain_valid <= 1'b1;
                        state <= 4'd5;
                    end else begin
                        ads_datain_valid <= 1'b0;
                        state <= 4'd4;
                    end
                end
                4'd5: begin
                    if (!ads_datain_ready) begin
                        ads_datain_valid <= 1'b0;
                        state <= 4'd6;
                    end else begin
                        ads_datain_valid <= 1'b1;
                        state <= 4'd5;
                    end
                end
                4'd6: begin
                    if (jesd_rst_delay_cnt < 16'd1000) begin
                        r_jesd_tx_sys_reset <= 1'b1;
                        w_tx_axi_ena        <= 1'b1;
                        jesd_rst_delay_cnt  <= jesd_rst_delay_cnt + 16'd1;
                        state <= 4'd6;
                    end else if (jesd_rst_delay_cnt < 16'd20000) begin
                        r_jesd_tx_sys_reset <= 1'b0;
                        w_tx_axi_ena        <= 1'b1;
                        jesd_rst_delay_cnt  <= jesd_rst_delay_cnt + 16'd1;
                        state <= 4'd6;
                    end else if (jesd_rst_delay_cnt < 16'd60000) begin
                        r_jesd_tx_sys_reset <= 1'b0;
                        w_tx_axi_ena        <= 1'b0;
                        jesd_rst_delay_cnt  <= jesd_rst_delay_cnt + 16'd1;
                        state <= 4'd6;
                    end else begin
                        r_jesd_tx_sys_reset <= 1'b0;
                        w_tx_axi_ena        <= 1'b1;
                        jesd_rst_delay_cnt  <= 16'd0;
                        state <= 4'd7;
                    end
                end
                4'd7: begin
                    if (das_datain_ready) begin
                        das_datain_valid <= 1'b1;
                        state <= 4'd8;
                    end else begin
                        das_datain_valid <= 1'b0;
                        state <= 4'd7;
                    end
                end
                4'd8: begin
                    if (!das_datain_ready) begin
                        das_datain_valid <= 1'b0;
                        state <= 4'd9;
                    end else begin
                        das_datain_valid <= 1'b1;
                        state <= 4'd8;
                    end
                end
                4'd9: begin
                    if (das_datain_ready) begin
                        if (jesd_rst_delay_cnt < 16'd100) begin
                            r_jesd_rx_sys_reset <= 1'b1;
                            jesd_rst_delay_cnt  <= jesd_rst_delay_cnt + 16'd1;
                            state <= 4'd9;
                        end else begin
                            r_jesd_rx_sys_reset <= 1'b0;
                            jesd_rst_delay_cnt  <= 16'd0;
                            state <= 4'd10;
                        end
                    end else begin
                        state <= 4'd9;
                    end
                end
                4'd10: begin
                    state <= 4'd10;
                end
                default: state <= 4'd0;
            endcase
        end
    end

    //==========================================================================
    // ADC 数据回读 (当前未使用，保留 jesd_data_parse 供后续扩展)
    //==========================================================================
    // LED 指示
    //==========================================================================
    wire [1:0] w_wave_led;
    assign w_wave_led[0] = w_awg_sample0[15];
    assign w_wave_led[1] = w_awg_sample0[14] ^ w_awg_sample0[15];

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
