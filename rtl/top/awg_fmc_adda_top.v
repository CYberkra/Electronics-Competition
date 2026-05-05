//------------------------------------------------------------------------------
// AWG FMC ADDA Top Module - K325T with AD9144 + AD9250
// 【AWG FMC ADDA 顶层模块 — 骨架版】
//
// 功能说明：
//   本模块为 FMC ADDA 子卡的顶层框架，等商家引脚资料到后填入具体约束。
//   当前仅实现 SPI 配置 + 波形源（DDS），JESD204B 接口留待后续接入。
//
// 硬件连接：
//   - K325T FMC HPC 连接器
//   - AD9144: 4ch 16bit DAC, JESD204B, 最高 2.8GSPS
//   - AD9250: 2ch 14bit ADC, JESD204B, 最高 250MSPS
//   - 当前仅使用 AD9144 的 DAC0 单路输出到示波器
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
    // 连接到 Kintex-7 GTX 收发器（Bank 115/116/117）
    //
    // AD9144 (DAC TX):
    //   默认 4 lane 模式， subclass 1
    //   DP0_C2M ~ DP3_C2M = DAC 数据从 FPGA → 子卡
    //   如用更少 lane，可注释掉未用的端口
    //--------------------------------------------------------------------------
    // AD9144 JESD TX lanes (FPGA → DAC)
    output wire        fmc_dp0_c2m_p, fmc_dp0_c2m_n,
    output wire        fmc_dp1_c2m_p, fmc_dp1_c2m_n,
    output wire        fmc_dp2_c2m_p, fmc_dp2_c2m_n,
    output wire        fmc_dp3_c2m_p, fmc_dp3_c2m_n,
    // AD9144 JESD TX SYNC~ (DAC → FPGA)
    input  wire        fmc_dp0_m2c_p, fmc_dp0_m2c_n,

    // AD9250 JESD RX lanes (ADC → FPGA)
    input  wire        fmc_dp4_m2c_p, fmc_dp4_m2c_n,
    input  wire        fmc_dp5_m2c_p, fmc_dp5_m2c_n,
    // AD9250 JESD RX SYNC~ (FPGA → ADC)
    output wire        fmc_dp4_c2m_p, fmc_dp4_c2m_n,

    //--------------------------------------------------------------------------
    // FMC HPC 参考时钟
    // GTX 参考时钟，通常由子卡上的时钟芯片提供
    //--------------------------------------------------------------------------
    input  wire        fmc_gbtclk0_m2c_p, fmc_gbtclk0_m2c_n,  // GTX RefClk0
    input  wire        fmc_gbtclk1_m2c_p, fmc_gbtclk1_m2c_n,  // GTX RefClk1

    //--------------------------------------------------------------------------
    // FMC HPC 低速信号 (LA00~LA33)
    // SPI、SYSREF、复位、控制信号
    //--------------------------------------------------------------------------
    // AD9144 SPI
    output wire        ad9144_spi_csb,   // SPI Chip Select
    output wire        ad9144_spi_sclk,  // SPI Clock
    output wire        ad9144_spi_sdio,  // SPI Data (bidir, FPGA→DAC config)
    input  wire        ad9144_spi_sdo,   // SPI Data (DAC→FPGA readback)

    // AD9250 SPI (可与 AD9144 共享总线，也可独立)
    output wire        ad9250_spi_csb,
    output wire        ad9250_spi_sclk,
    output wire        ad9250_spi_sdio,
    input  wire        ad9250_spi_sdo,

    // SYSREF — JESD204B Subclass 1 确定性延迟所需
    // 可由 FPGA 生成，也可由子卡时钟芯片提供
    output wire        fmc_sysref_p, fmc_sysref_n,

    // 子卡复位/控制
    output wire        ad9144_reset,     // AD9144 硬复位，低有效
    output wire        ad9250_reset,     // AD9250 硬复位，低有效
    input  wire        fmc_prsnt,        // FMC 在位检测
    input  wire        fmc_pg_m2c,       // 子卡电源正常

    //--------------------------------------------------------------------------
    // LED 指示（复用板载 LED）
    //--------------------------------------------------------------------------
    output wire [1:0]  led
);

    //--------------------------------------------------------------------------
    // 内部信号
    //--------------------------------------------------------------------------
    wire clk;               // 100MHz 全局时钟
    wire rst_n;             // 同步复位
    wire pll_locked;        // PLL 锁定指示

    // DDS 波形生成
    wire [15:0] dac_sample; // 16bit 有符号 DAC 样本
    wire        dac_valid;

    // AD9144 SPI 配置
    wire        spi_start;
    wire        spi_done;
    wire        spi_busy;
    wire        ad9144_init_ok;

    // JESD204B 接口（占位，待 Xilinx IP 接入）
    wire        jesd_tx_ready;
    wire        jesd_rx_ready;

    //--------------------------------------------------------------------------
    // 时钟输入缓冲 (IBUFDS + BUFG)
    //--------------------------------------------------------------------------
    wire clk_ibuf;
    IBUFDS clk_ibufds (.I(sys_clk_p), .IB(sys_clk_n), .O(clk_ibuf));
    BUFG   clk_bufg   (.I(clk_ibuf), .O(clk));
    assign rst_n = sys_rst_n & pll_locked;

    //--------------------------------------------------------------------------
    // 时钟生成 — MMCM/PLL
    //
    // 100MHz → 需要生成：
    //   - JESD204B 参考时钟（取决于 lane rate，如 250MHz/312.5MHz）
    //   - SYSREF 时钟（通常为采样率的整数分频）
    //   - SPI 时钟（25MHz）
    //
    // 注意：等商家确认子卡时钟方案后再精确配置。
    //   若子卡自带时钟芯片（如 AD9528），则 FPGA 只需接收 refclk，
    //   不需要生成 DAC/ADC 采样时钟。
    //--------------------------------------------------------------------------
    // TODO: 实例化 MMCM 生成所需的时钟
    // assign pll_locked = 1'b1; // 占位

    //--------------------------------------------------------------------------
    // 波形生成 — DDS NCO（复用已有模块）
    //
    // 当前先用已有的 dds_compiler_wrapper 产生单音正弦波。
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
        .start     (pll_locked),  // PLL 锁定后自动开始配置
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
    //
    // 若 SPI 总线共享，可将 ad9250_spi_csb 接同一 CSB，
    // 或独立控制。当前保持独立以预留灵活性。
    //--------------------------------------------------------------------------
    // TODO: 实例化 ad9250_spi_ctrl
    assign ad9250_spi_csb  = 1'b1;  // 禁用
    assign ad9250_spi_sclk = 1'b0;
    assign ad9250_spi_sdio = 1'b0;

    //--------------------------------------------------------------------------
    // JESD204B 接口占位
    //
    // 待接入 Xilinx JESD204 IP v7.2：
    //   1. 在 Vivado IP Catalog 中添加 JESD204 IP
    //   2. 配置为 TX 模式（AD9144）+ RX 模式（AD9250）
    //   3. 连接 GTX 收发器和参考时钟
    //   4. 将 dac_sample → JESD204 TX data interface
    //--------------------------------------------------------------------------
    // TODO: 实例化 jesd204_tx_if + jesd204_rx_if
    assign jesd_tx_ready = 1'b0;
    assign jesd_rx_ready = 1'b0;

    // SYSREF 生成（Subclass 1 需要）
    // TODO: 根据实际采样率生成分频后的 SYSREF
    assign fmc_sysref_p = 1'b0;
    assign fmc_sysref_n = 1'b1;

    // 子卡复位
    assign ad9144_reset = rst_n;  // 低有效：rst_n=0 时复位
    assign ad9250_reset = rst_n;

    //--------------------------------------------------------------------------
    // LED 指示
    //
    // led[0]: SPI 配置成功（AD9144 init_ok）
    // led[1]: DDS 波形输出符号位（有波形时闪烁）
    //--------------------------------------------------------------------------
    assign led[0] = ad9144_init_ok;
    assign led[1] = dac_sample[15];

endmodule
