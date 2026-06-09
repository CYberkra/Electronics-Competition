#------------------------------------------------------------------------------
# FMC ADDA (AD9144 DAC only; AD9250 ADC 已剥离) Pin Constraints
# Target: Zhengdianyuanzi K7-325T, XC7K325TFFG900-2
#
# 引脚来源：正点原子 K7_BASE_1V3_2025_0111_USER.pdf 原理图
#   J34A = DP0 + GBTCLK0 + 部分 LA
#   J34B = LA 信号 + CLK0/CLK1 + PRSNT
#   J34E = DP1~DP9 + GBTCLK1
#
# 子卡：FMCADDA-9250-9144 (AD9144 2.8Gsps DAC only; AD9250 ADC 已剥离)
# 模式：4L DAC (AD9144 Mode4, Lane0~3)
#------------------------------------------------------------------------------

#==============================================================================
# 1. GTX 参考时钟
#==============================================================================
# GBTCLK0 — LMK04828 OUT0 125M → GTX RefClk
set_property PACKAGE_PIN G8  [get_ports fmc_gbtclk0_m2c_p]
set_property PACKAGE_PIN G7  [get_ports fmc_gbtclk0_m2c_n]

# GBTCLK1 — 备用参考时钟 (未使用，端口未在 awg_top.v 中声明)
# set_property PACKAGE_PIN J8  [get_ports fmc_gbtclk1_m2c_p]
# set_property PACKAGE_PIN J7  [get_ports fmc_gbtclk1_m2c_n]

# 时钟约束：fmc_refclk0 定义见 awg_k325t.xdc（主约束文件）

#==============================================================================
# 2. JESD204B 高速差分对 — DAC TX (AD9144, FPGA → 子卡, C2M)
#==============================================================================
# 4L 模式：DP0~DP3_C2M (10Gbps lane rate)
set_property PACKAGE_PIN H2  [get_ports fmc_dp0_c2m_p]
set_property PACKAGE_PIN H1  [get_ports fmc_dp0_c2m_n]

set_property PACKAGE_PIN F2  [get_ports fmc_dp1_c2m_p]
set_property PACKAGE_PIN F1  [get_ports fmc_dp1_c2m_n]

set_property PACKAGE_PIN J4  [get_ports fmc_dp2_c2m_p]
set_property PACKAGE_PIN J3  [get_ports fmc_dp2_c2m_n]

set_property PACKAGE_PIN K2  [get_ports fmc_dp3_c2m_p]
set_property PACKAGE_PIN K1  [get_ports fmc_dp3_c2m_n]

# 8L 模式扩展：DP4~DP7_C2M（如需满速率，取消注释并填入引脚）
# set_property PACKAGE_PIN ??? [get_ports fmc_dp4_c2m_p]
# set_property PACKAGE_PIN ??? [get_ports fmc_dp4_c2m_n]
# set_property PACKAGE_PIN ??? [get_ports fmc_dp5_c2m_p]
# set_property PACKAGE_PIN ??? [get_ports fmc_dp5_c2m_n]
# set_property PACKAGE_PIN ??? [get_ports fmc_dp6_c2m_p]
# set_property PACKAGE_PIN ??? [get_ports fmc_dp6_c2m_n]
# set_property PACKAGE_PIN ??? [get_ports fmc_dp7_c2m_p]
# set_property PACKAGE_PIN ??? [get_ports fmc_dp7_c2m_n]

#==============================================================================
# 3. JESD204B 高速差分对 — ADC RX (AD9250) — 已剥离，端口已移除
#==============================================================================
# fmc_dp0_m2c_p/n (G4/G3), fmc_dp1_m2c_p/n (F6/F5) — not used

#==============================================================================
# 4. JESD204B 同步信号 (LVDS_25)
#==============================================================================
# DAC SYNC0 — LA05_P/N (J34A D11/D12 → E19/D19)
set_property PACKAGE_PIN E19 [get_ports dac_sync0_p]
set_property PACKAGE_PIN D19 [get_ports dac_sync0_n]
set_property IOSTANDARD LVDS_25 [get_ports {dac_sync0_p dac_sync0_n}]

# DAC SYNC1 — LA09_P/N (J34A D14/D15 → D21/C21)
set_property PACKAGE_PIN D21 [get_ports dac_sync1_p]
set_property PACKAGE_PIN C21 [get_ports dac_sync1_n]
set_property IOSTANDARD LVDS_25 [get_ports {dac_sync1_p dac_sync1_n}]

# ADC SYNC — 已剥离，端口已移除 (原 D22/C22)

#==============================================================================
# 5. SYSREF (LVDS_25)
#==============================================================================
# FPGA_SYSREF — LA20_P/N (J34B G22/G23 → D14/C14)
set_property PACKAGE_PIN D14 [get_ports fmc_sysref_p]
set_property PACKAGE_PIN C14 [get_ports fmc_sysref_n]
set_property IOSTANDARD LVDS_25 [get_ports {fmc_sysref_p fmc_sysref_n}]

#==============================================================================
# 6. SPI 控制信号 (LVCMOS25)
#==============================================================================
# AD9250 SPI/RSTN — 已剥离，端口已移除
# (原 ad9250_spi_sclk/csb/sdio: F21/E21/J18, ad9250_reset: F20)

# AD9144 SPI — LA10_P/N (SCLK/CSN) + LA06_P (SDIO)
set_property PACKAGE_PIN C19 [get_ports ad9144_spi_sclk]
set_property IOSTANDARD LVCMOS25 [get_ports ad9144_spi_sclk]

set_property PACKAGE_PIN B19 [get_ports ad9144_spi_csb]
set_property IOSTANDARD LVCMOS25 [get_ports ad9144_spi_csb]

set_property PACKAGE_PIN B18 [get_ports ad9144_spi_sdio]
set_property IOSTANDARD LVCMOS25 [get_ports ad9144_spi_sdio]

# AD9144 RSTN — LA14_N (J34B C19 → F18)
set_property PACKAGE_PIN F18 [get_ports ad9144_reset]
set_property IOSTANDARD LVCMOS25 [get_ports ad9144_reset]

# AD9144 TXEN — LA04_P/N (J34B H10/H11 → D16/C16)
set_property PACKAGE_PIN D16 [get_ports ad9144_txen0]
set_property IOSTANDARD LVCMOS25 [get_ports ad9144_txen0]

set_property PACKAGE_PIN C16 [get_ports ad9144_txen1]
set_property IOSTANDARD LVCMOS25 [get_ports ad9144_txen1]

# LMK04828 SPI/控制
#   SPI SCLK → LA29_N (J34B G31 → E16) — ADK总线
#   SPI SDIO → LA28_N (J34B H32 → J12) — ADK总线
#   CS# → LA28_P (J34B H31 → J11)
#   RESET → LA29_P (J34B G30 → F15)
set_property PACKAGE_PIN E16 [get_ports lmk04828_spi_sclk]
set_property IOSTANDARD LVCMOS25 [get_ports lmk04828_spi_sclk]

set_property PACKAGE_PIN J12 [get_ports lmk04828_spi_sdio]
set_property IOSTANDARD LVCMOS25 [get_ports lmk04828_spi_sdio]

set_property PACKAGE_PIN J11 [get_ports lmk04828_cs_n]
set_property IOSTANDARD LVCMOS25 [get_ports lmk04828_cs_n]

set_property PACKAGE_PIN F15 [get_ports lmk04828_reset]
set_property IOSTANDARD LVCMOS25 [get_ports lmk04828_reset]

#==============================================================================
# 7. 其他控制信号
#==============================================================================
# FMC 在位检测
set_property PACKAGE_PIN AF30 [get_ports fmc_prsnt]
set_property IOSTANDARD LVCMOS25 [get_ports fmc_prsnt]

#==============================================================================
# 8. 时钟约束
#==============================================================================
# SYSREF 输入约束
set_input_delay -clock [get_clocks fmc_refclk0] -min 0.45 [get_ports fmc_sysref_p]
set_input_delay -clock [get_clocks fmc_refclk0] -max 0.55 [get_ports fmc_sysref_p]

# 异步时钟组
set_clock_groups -asynchronous -group [get_clocks fmc_refclk0] -group [get_clocks sys_clk]

#==============================================================================
# 9. False path
#==============================================================================
set_false_path -to [get_ports {ad9144_spi_* lmk04828_spi_*}]
set_false_path -to [get_ports {ad9144_reset ad9144_txen*}]
set_false_path -from [get_ports fmc_prsnt]

#==============================================================================
# 10. Bitstream 配置
#==============================================================================
set_property BITSTREAM.CONFIG.UNUSEDPIN Pullnone [current_design]
set_property BITSTREAM.GENERAL.COMPRESS true [current_design]
