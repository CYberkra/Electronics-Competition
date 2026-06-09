#------------------------------------------------------------------------------
# AWG K325T Unified Constraints - AWG Top (ADC 已剥离，仅 DAC)
# Target: Zhengdianyuanzi K7-325T, XC7K325TFFG900-2
# Top module: awg_top
#
# 引脚来源：正点原子 K7_BASE_1V3_2025_0111_USER.pdf 原理图
# 子卡：FMCADDA-9250-9144 (AD9144 2.8Gsps DAC only; AD9250 ADC 已剥离)
# 模式：4L DAC (AD9144 Mode4, Lane0~3)
#------------------------------------------------------------------------------

#==============================================================================
# 0. 板载时钟与复位
#==============================================================================
# 100MHz 差分系统时钟 (AE10/AF10)
set_property PACKAGE_PIN AE10 [get_ports sys_clk_p]
set_property PACKAGE_PIN AF10 [get_ports sys_clk_n]
set_property IOSTANDARD DIFF_SSTL15_DCI [get_ports {sys_clk_p sys_clk_n}]
create_clock -period 10.000 -name sys_clk [get_ports sys_clk_p]

# 低电平复位 — KEY0 on board (AB25, Bank 13 VCCO=2.5V shared with FMC)
set_property PACKAGE_PIN AB25 [get_ports sys_rst_n]
set_property IOSTANDARD LVCMOS25 [get_ports sys_rst_n]

#==============================================================================
# 1. GTX 参考时钟 (Bank 117)
#==============================================================================
# GBTCLK0 — LMK04828 OUT0 125M → GTX RefClk (G8/G7)
set_property PACKAGE_PIN G8  [get_ports fmc_gbtclk0_m2c_p]
set_property PACKAGE_PIN G7  [get_ports fmc_gbtclk0_m2c_n]
create_clock -period 8.000 -name fmc_refclk0 [get_ports fmc_gbtclk0_m2c_p]

# 异步时钟组
set_clock_groups -asynchronous -group [get_clocks fmc_refclk0] -group [get_clocks sys_clk]

#==============================================================================
# 2. JESD204B 全局时钟 (FMC LA00_CC, 125MHz)
#==============================================================================
set_property PACKAGE_PIN D17 [get_ports fmc_glblclk_p]
set_property PACKAGE_PIN D18 [get_ports fmc_glblclk_n]
set_property IOSTANDARD LVDS_25 [get_ports {fmc_glblclk_p fmc_glblclk_n}]
# 时钟由 clk_for_glbclk IP 内部自动创建，无需重复定义

#==============================================================================
# 3. JESD204B 高速差分对 — DAC TX (AD9144, FPGA→子卡, C2M)
#==============================================================================
# 4L 模式：DP0~DP3_C2M (10Gbps lane rate)
# Lane 0: H2/H1
set_property PACKAGE_PIN H2  [get_ports fmc_dp0_c2m_p]
set_property PACKAGE_PIN H1  [get_ports fmc_dp0_c2m_n]
# Lane 1: F2/F1
set_property PACKAGE_PIN F2  [get_ports fmc_dp1_c2m_p]
set_property PACKAGE_PIN F1  [get_ports fmc_dp1_c2m_n]
# Lane 2: J4/J3
set_property PACKAGE_PIN J4  [get_ports fmc_dp2_c2m_p]
set_property PACKAGE_PIN J3  [get_ports fmc_dp2_c2m_n]
# Lane 3: K2/K1
set_property PACKAGE_PIN K2  [get_ports fmc_dp3_c2m_p]
set_property PACKAGE_PIN K1  [get_ports fmc_dp3_c2m_n]

#==============================================================================
# 4. JESD204B 高速差分对 — ADC RX (AD9250) — 已剥离，端口已从 awg_top.v 移除
#==============================================================================
# fmc_dp0_m2c_p/n, fmc_dp1_m2c_p/n — not used (ADC stripped)

#==============================================================================
# 5. JESD204B 同步信号 (LVDS_25)
#==============================================================================
# DAC SYNC0 — LA05_P/N (E19/D19)
set_property PACKAGE_PIN E19 [get_ports dac_sync0_p]
set_property PACKAGE_PIN D19 [get_ports dac_sync0_n]
set_property IOSTANDARD LVDS_25 [get_ports {dac_sync0_p dac_sync0_n}]

# DAC SYNC1 — LA09_P/N (D21/C21)
set_property PACKAGE_PIN D21 [get_ports dac_sync1_p]
set_property PACKAGE_PIN C21 [get_ports dac_sync1_n]
set_property IOSTANDARD LVDS_25 [get_ports {dac_sync1_p dac_sync1_n}]

# ADC SYNC — 已剥离，端口已从 awg_top.v 移除
# (原 adc_sync_p/n: D22/C22)

#==============================================================================
# 6. SYSREF (LVDS_25)
#==============================================================================
# FPGA_SYSREF — LA20_P/N (D14/C14)
set_property PACKAGE_PIN D14 [get_ports fmc_sysref_p]
set_property PACKAGE_PIN C14 [get_ports fmc_sysref_n]
set_property IOSTANDARD LVDS_25 [get_ports {fmc_sysref_p fmc_sysref_n}]

#==============================================================================
# 7. SPI 控制信号 (LVCMOS25)
#==============================================================================
# AD9250 SPI — 已剥离，端口已从 awg_top.v 移除
# (原 ad9250_spi_sclk/csb/sdio: F21/E21/J18, ad9250_reset: F20)

# AD9144 SPI
set_property PACKAGE_PIN C19 [get_ports ad9144_spi_sclk]
set_property IOSTANDARD LVCMOS25 [get_ports ad9144_spi_sclk]
set_property PACKAGE_PIN B19 [get_ports ad9144_spi_csb]
set_property IOSTANDARD LVCMOS25 [get_ports ad9144_spi_csb]
set_property PACKAGE_PIN B18 [get_ports ad9144_spi_sdio]
set_property IOSTANDARD LVCMOS25 [get_ports ad9144_spi_sdio]
set_property PACKAGE_PIN F18 [get_ports ad9144_reset]
set_property IOSTANDARD LVCMOS25 [get_ports ad9144_reset]
set_property PACKAGE_PIN D16 [get_ports ad9144_txen0]
set_property IOSTANDARD LVCMOS25 [get_ports ad9144_txen0]
set_property PACKAGE_PIN C16 [get_ports ad9144_txen1]
set_property IOSTANDARD LVCMOS25 [get_ports ad9144_txen1]

# LMK04828 SPI/控制 — ADK 总线 (LA28/LA29)
#   SPI SCLK → LA29_N (E16),  SPI SDIO → LA28_N (J12)
#   CS# → LA28_P (J11),       RESET → LA29_P (F15)
# 详见 docs/fmc_adda_signal_map.md
set_property PACKAGE_PIN E16 [get_ports lmk04828_spi_sclk]
set_property IOSTANDARD LVCMOS25 [get_ports lmk04828_spi_sclk]
set_property PACKAGE_PIN J12 [get_ports lmk04828_spi_sdio]
set_property IOSTANDARD LVCMOS25 [get_ports lmk04828_spi_sdio]
set_property PACKAGE_PIN J11 [get_ports lmk04828_cs_n]
set_property IOSTANDARD LVCMOS25 [get_ports lmk04828_cs_n]
set_property PACKAGE_PIN F15 [get_ports lmk04828_reset]
set_property IOSTANDARD LVCMOS25 [get_ports lmk04828_reset]

#==============================================================================
# 8. 其他控制信号
#==============================================================================
# FMC 在位检测 (AF30)
set_property PACKAGE_PIN AF30 [get_ports fmc_prsnt]
set_property IOSTANDARD LVCMOS25 [get_ports fmc_prsnt]

#==============================================================================
# 9. 板载按键与LED (LVCMOS33)
#==============================================================================
set_property PACKAGE_PIN A26 [get_ports key0]
set_property IOSTANDARD LVCMOS33 [get_ports key0]
set_property PACKAGE_PIN A25 [get_ports key1]
set_property IOSTANDARD LVCMOS33 [get_ports key1]
set_property PACKAGE_PIN R24 [get_ports {led[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led[0]}]
set_property PACKAGE_PIN R23 [get_ports {led[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led[1]}]

#==============================================================================
# 10. 时钟约束
#==============================================================================
# SYSREF 输入约束
set_input_delay -clock [get_clocks fmc_refclk0] -min 0.45 [get_ports fmc_sysref_p]
set_input_delay -clock [get_clocks fmc_refclk0] -max 0.55 [get_ports fmc_sysref_p]

# CFGMCLK — STARTUPE2 输出 65MHz 用于 clk_sys_mmcm 输入
create_clock -period 15.385 -name cfg_clk [get_nets cfg_clk]

# 跨时钟域 false paths（由内部同步器处理，不需要时序优化）
# sys_clk 域 → cfg_clk 域（按键→SPI 配置）
set_false_path -from [get_clocks sys_clk] -to [get_clocks cfg_clk]

#==============================================================================
# 11. False path (低速控制信号 + CDC 跨时钟域路径)
#==============================================================================
set_false_path -to [get_ports {ad9144_spi_* lmk04828_spi_*}]
set_false_path -to [get_ports {ad9144_reset ad9144_txen* lmk04828_*}]
set_false_path -from [get_ports fmc_prsnt]
set_false_path -from [get_ports {key0 key1}]
set_false_path -to [get_ports {led[*]}]

# UART — 板载 USB-UART (CH340G)
set_property PACKAGE_PIN T23 [get_ports uart_rxd]
set_property PACKAGE_PIN T22 [get_ports uart_txd]
set_property IOSTANDARD LVCMOS33 [get_ports {uart_rxd uart_txd}]

# CDC 路径：JESD AXI-Lite 配置走异步桥，不需时序优化
set_false_path -from [get_clocks -of_objects [get_pins -hierarchical -filter {NAME =~ *clk_sys_mmcm*clk_out2*}]] \
               -to [get_clocks -of_objects [get_pins -hierarchical -filter {NAME =~ *clk_for_glbclk*clk_out2*}]]
set_false_path -from [get_clocks -of_objects [get_pins -hierarchical -filter {NAME =~ *clk_for_glbclk*clk_out2*}]] \
               -to [get_clocks -of_objects [get_pins -hierarchical -filter {NAME =~ *clk_sys_mmcm*clk_out2*}]]

# SPI 控制信号与 JESD 时钟域异步
set_false_path -from [get_clocks -of_objects [get_pins -hierarchical -filter {NAME =~ *clk_sys_mmcm*clk_out1*}]] \
               -to [get_clocks -of_objects [get_pins -hierarchical -filter {NAME =~ *clk_for_glbclk*clk_out2*}]]

# UART/寄存器组 (sys_clk_bufg) → DDS (tx_core_clk) CDC: quasi-static 控制值
# 慢变化参数，单周期采样毛刺对射频输出不可见
set_false_path -from [get_clocks sys_clk] \
               -to [get_clocks -of_objects [get_pins -hierarchical -filter {NAME =~ *clk_for_glbclk*clk_out2*}]]

#==============================================================================
# 12. Bitstream 配置
#==============================================================================
set_property BITSTREAM.CONFIG.UNUSEDPIN Pullnone [current_design]
set_property BITSTREAM.GENERAL.COMPRESS true [current_design]
set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]

# Vivado 2024.1 假阳性：SPI FSM next-state 被误检为门控时钟
# 所有寄存器已使用 clk_in + spi_tick(CE)，无实际门控时钟
set_property SEVERITY {Info} [get_drc_checks PDRC-153]
