//------------------------------------------------------------------------------
// AWG FMC ADDA Top Module - K325T with AD9144 + AD9250
// 【AWG FMC ADDA 顶层模块 — 正点原子 K325T 版】
//
// 子卡：FMCADDA-9250-9144
//   - AD9250: 双通道 14bit ADC, 250Msps, JESD204B (2 Lane, 5Gbps)
//   - AD9144: 四通道 16bit DAC, 2.8Gsps, JESD204B (8 Lane, 12.5Gbps)
//   - 时钟：LMK04828, 板载 50M TCXO
//
// 当前模式：4L DAC (AD9144 Mode4, Lane0~3) + 2L ADC (AD9250)
//   - DAC lane rate: 10Gbps, glblclk=250M, refclk=125M
//   - ADC lane rate: 5Gbps, glblclk=125M, refclk=125M
//
// FMC HPC 引脚来源：正点原子 K7_BASE_1V3_2025_0111_USER.pdf
//------------------------------------------------------------------------------

module awg_fmc_adda_top (
    //--------------------------------------------------------------------------
    // 板载时钟和复位
    //--------------------------------------------------------------------------
    input  wire        sys_clk_p,   // 100MHz 差分时钟正端 (AE10)
    input  wire        sys_clk_n,   // 100MHz 差分时钟负端 (AF10)
    input  wire        sys_rst_n,   // 低电平复位 (AB25)

    //--------------------------------------------------------------------------
    // FMC HPC 高速差分信号 — JESD204B 数据通道
    //
    // AD9144 DAC TX lanes (FPGA → 子卡, C2M)
    //   4L 模式：DP0~DP3_C2M, 10Gbps lane rate
    //--------------------------------------------------------------------------
    output wire        fmc_dp0_c2m_p, fmc_dp0_c2m_n,
    output wire        fmc_dp1_c2m_p, fmc_dp1_c2m_n,
    output wire        fmc_dp2_c2m_p, fmc_dp2_c2m_n,
    output wire        fmc_dp3_c2m_p, fmc_dp3_c2m_n,

    // AD9250 ADC RX lanes (子卡 → FPGA, M2C)
    //   2L 模式：DP0~DP1_M2C, 5Gbps lane rate
    input  wire        fmc_dp0_m2c_p, fmc_dp0_m2c_n,
    input  wire        fmc_dp1_m2c_p, fmc_dp1_m2c_n,

    //--------------------------------------------------------------------------
    // FMC HPC 参考时钟
    //--------------------------------------------------------------------------
    input  wire        fmc_gbtclk0_m2c_p, fmc_gbtclk0_m2c_n,  // GTX RefClk0 125M
    input  wire        fmc_gbtclk1_m2c_p, fmc_gbtclk1_m2c_n,  // 备用 RefClk1

    //--------------------------------------------------------------------------
    // JESD204B 同步信号 (LVDS_25)
    //--------------------------------------------------------------------------
    // DAC SYNC~ (子卡 → FPGA)
    input  wire        dac_sync0_p, dac_sync0_n,
    input  wire        dac_sync1_p, dac_sync1_n,
    // ADC SYNC~ (FPGA → 子卡)
    output wire        adc_sync_p, adc_sync_n,

    //--------------------------------------------------------------------------
    // SYSREF — JESD204B Subclass 1 确定性延迟所需
    //--------------------------------------------------------------------------
    output wire        fmc_sysref_p, fmc_sysref_n,

    //--------------------------------------------------------------------------
    // AD9250 SPI 控制 (LVCMOS25)
    //--------------------------------------------------------------------------
    output wire        ad9250_spi_csb,   // CSN (LA01_N_CC)
    output wire        ad9250_spi_sclk,  // SCLK (LA01_P_CC)
    output wire        ad9250_spi_sdio,  // SDIO (LA02_N)
    input  wire        ad9250_spi_sdo,   // SDO (读回)
    output wire        ad9250_reset,     // RSTN (CLK0_M2C_P)

    //--------------------------------------------------------------------------
    // AD9144 SPI 控制 (LVCMOS25)
    //--------------------------------------------------------------------------
    output wire        ad9144_spi_csb,   // CSN (LA10_N)
    output wire        ad9144_spi_sclk,  // SCLK (LA10_P)
    output wire        ad9144_spi_sdio,  // SDIO (LA06_P)
    input  wire        ad9144_spi_sdo,   // SDO (LA06_N)
    output wire        ad9144_reset,     // RSTN (LA14_N)
    output wire        ad9144_txen0,     // TXEN0 (LA04_P)
    output wire        ad9144_txen1,     // TXEN1 (LA04_N)

    //--------------------------------------------------------------------------
    // LMK04828 时钟芯片 SPI (LVCMOS25)
    //--------------------------------------------------------------------------
    output wire        lmk04828_spi_sclk, // SCLK (IIC_SCL)
    output wire        lmk04828_spi_sdio, // SDIO (IIC_SDA)
    output wire        lmk04828_cs_n,     // CSN (如需要)
    output wire        lmk04828_reset,    // RST

    //--------------------------------------------------------------------------
    // 子卡状态
    //--------------------------------------------------------------------------
    input  wire        fmc_prsnt,        // FMC 在位检测 (AF30)

    //--------------------------------------------------------------------------
    // 板载 LED 指示
    //--------------------------------------------------------------------------
    output wire [1:0]  led
);

    //--------------------------------------------------------------------------
    // 内部信号
    //--------------------------------------------------------------------------
    wire clk;               // 100MHz 全局时钟
    wire rst_n;             // 同步复位

    // DDS 波形生成
    wire [15:0] dac_sample; // 16bit 有符号 DAC 样本
    wire        dac_valid;

    // AD9144 SPI 配置
    wire        spi_done;
    wire        spi_busy;
    wire        ad9144_init_ok;

    // JESD204B 接口占位（待 Xilinx IP 接入）
    wire        jesd_tx_ready;
    wire        jesd_rx_ready;

    //--------------------------------------------------------------------------
    // 时钟输入缓冲 (IBUFDS + BUFG)
    //--------------------------------------------------------------------------
    wire clk_ibuf;
    IBUFDS clk_ibufds (.I(sys_clk_p), .IB(sys_clk_n), .O(clk_ibuf));
    BUFG   clk_bufg   (.I(clk_ibuf), .O(clk));
    assign rst_n = sys_rst_n;

    //--------------------------------------------------------------------------
    // 波形生成 — DDS NCO（复用已有模块）
    //
    // 当前先用 dds_compiler_wrapper 产生单音正弦波。
    // 后续替换为手写 64bit dds_nco + 多波形选择。
    //--------------------------------------------------------------------------
    reg         freq_load;
    reg  [47:0] phase_inc;
    wire        out_valid;

    localparam PHASE_INC_1MHZ = 48'h000028F5C28F5C3;

    dds_compiler_wrapper dds_inst (
        .clk       (clk),
        .rst_n     (rst_n),
        .freq_load (freq_load),
        .phase_inc (phase_inc),
        .sine_out  (dac_sample),
        .out_valid (out_valid)
    );

    // 复位后自动加载 1MHz 频率（示波器易观察）
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            freq_load <= 1'b0;
            phase_inc <= PHASE_INC_1MHZ;
        end else if (!freq_load && out_valid) begin
            freq_load <= 1'b1;
        end else begin
            freq_load <= 1'b0;
        end
    end

    //--------------------------------------------------------------------------
    // AD9144 SPI 配置控制器
    //--------------------------------------------------------------------------
    ad9144_spi_ctrl u_ad9144_spi (
        .clk       (clk),
        .rst_n     (rst_n),
        .start     (1'b1),     // 上电自动开始
        .done      (spi_done),
        .busy      (spi_busy),
        .spi_csb   (ad9144_spi_csb),
        .spi_sclk  (ad9144_spi_sclk),
        .spi_sdio  (ad9144_spi_sdio),
        .spi_sdo   (ad9144_spi_sdo),
        .init_ok   (ad9144_init_ok),
        .chip_id_l (),
        .chip_id_h ()
    );

    //--------------------------------------------------------------------------
    // AD9250 SPI 配置（占位，可选）
    //--------------------------------------------------------------------------
    // TODO: 实例化 ad9250_spi_ctrl
    assign ad9250_spi_csb  = 1'b1;
    assign ad9250_spi_sclk = 1'b0;
    assign ad9250_spi_sdio = 1'b0;
    assign ad9250_reset    = rst_n;

    //--------------------------------------------------------------------------
    // LMK04828 SPI 配置控制器
    //--------------------------------------------------------------------------
    wire lmk_spi_done;
    wire lmk_spi_busy;

    lmk04828_spi_ctrl u_lmk_spi (
        .clk       (clk),
        .rst_n     (rst_n),
        .start     (1'b1),       // 上电自动开始配置
        .done      (lmk_spi_done),
        .busy      (lmk_spi_busy),
        .spi_csb   (lmk04828_cs_n),
        .spi_sclk  (lmk04828_spi_sclk),
        .spi_sdio  (lmk04828_spi_sdio),
        .spi_sdo   (1'b0)
    );

    assign lmk04828_reset = rst_n;

    //--------------------------------------------------------------------------
    // JESD204B 接口占位
    //
    // 待接入 Xilinx JESD204 IP v7.2：
    //   1. jesd204_tx (4 lane, 10Gbps, refclk=125M, glblclk=250M)
    //   2. jesd204_rx (2 lane, 5Gbps, refclk=125M, glblclk=125M)
    //   3. jesd204_phy (GTX, 4T4R + 2R)
    //--------------------------------------------------------------------------
    // TODO: 实例化 JESD204 IP
    assign jesd_tx_ready = 1'b0;
    assign jesd_rx_ready = 1'b0;

    // SYSREF 生成（Subclass 1 需要）
    // TODO: 根据 LMK04828 OUT1 (3.90625M) 或 FPGA 内部分频生成
    assign fmc_sysref_p = 1'b0;
    assign fmc_sysref_n = 1'b1;

    // ADC SYNC
    assign adc_sync_p = 1'b0;
    assign adc_sync_n = 1'b1;

    // AD9144 控制
    assign ad9144_reset = rst_n;
    assign ad9144_txen0 = 1'b1;  // 使能 DAC0 输出
    assign ad9144_txen1 = 1'b0;  // 禁用 DAC1

    //--------------------------------------------------------------------------
    // LED 指示
    //
    // led[0]: AD9144 SPI 配置成功
    // led[1]: DDS 波形输出符号位
    //--------------------------------------------------------------------------
    assign led[0] = ad9144_init_ok;
    assign led[1] = dac_sample[15];

endmodule
