#------------------------------------------------------------------------------
# FMC ADDA (AD9144 + AD9250) Pin Constraints — Template
# Target: Zhengdianyuanzi K7-325T, XC7K325TFFG900-2
#
# 说明：
#   本文件为约束模板，所有 PACKAGE_PIN 用 ### TBD ### 占位。
#   等商家提供 FMC 引脚分配表后，替换为具体引脚并删除 TBD 注释。
#
# FMC HPC 信号分组：
#   - DP0~DP9: 高速差分对（GTX 收发器），用于 JESD204B
#   - GBTCLK0/1: GTX 参考时钟
#   - LA00~LA33: 低速信号（SPI、SYSREF、控制）
#------------------------------------------------------------------------------

#==============================================================================
# 1. 板载时钟（如顶层已包含，此处可省略）
#==============================================================================
# set_property PACKAGE_PIN AE10 [get_ports sys_clk_p]
# set_property IOSTANDARD DIFF_SSTL15 [get_ports sys_clk_p]
# set_property PACKAGE_PIN AF10 [get_ports sys_clk_n]
# set_property IOSTANDARD DIFF_SSTL15 [get_ports sys_clk_n]
# create_clock -period 10.000 -name sys_clk [get_ports sys_clk_p]

#==============================================================================
# 2. FMC HPC 高速差分对 — JESD204B 数据通道
#==============================================================================
# AD9144 TX lanes (FPGA → DAC, C2M = Carrier to Mezzanine)
# 连接到 GTX 收发器 Bank 115/116/117

set_property PACKAGE_PIN ### TBD ### [get_ports fmc_dp0_c2m_p]
set_property PACKAGE_PIN ### TBD ### [get_ports fmc_dp0_c2m_n]
set_property IOSTANDARD LVDS_25 [get_ports {fmc_dp0_c2m_p fmc_dp0_c2m_n}]

set_property PACKAGE_PIN ### TBD ### [get_ports fmc_dp1_c2m_p]
set_property PACKAGE_PIN ### TBD ### [get_ports fmc_dp1_c2m_n]
set_property IOSTANDARD LVDS_25 [get_ports {fmc_dp1_c2m_p fmc_dp1_c2m_n}]

set_property PACKAGE_PIN ### TBD ### [get_ports fmc_dp2_c2m_p]
set_property PACKAGE_PIN ### TBD ### [get_ports fmc_dp2_c2m_n]
set_property IOSTANDARD LVDS_25 [get_ports {fmc_dp2_c2m_p fmc_dp2_c2m_n}]

set_property PACKAGE_PIN ### TBD ### [get_ports fmc_dp3_c2m_p]
set_property PACKAGE_PIN ### TBD ### [get_ports fmc_dp3_c2m_n]
set_property IOSTANDARD LVDS_25 [get_ports {fmc_dp3_c2m_p fmc_dp3_c2m_n}]

# AD9144 TX SYNC~ (DAC → FPGA, M2C)
set_property PACKAGE_PIN ### TBD ### [get_ports fmc_dp0_m2c_p]
set_property PACKAGE_PIN ### TBD ### [get_ports fmc_dp0_m2c_n]
set_property IOSTANDARD LVDS_25 [get_ports {fmc_dp0_m2c_p fmc_dp0_m2c_n}]

# AD9250 RX lanes (ADC → FPGA, M2C)
set_property PACKAGE_PIN ### TBD ### [get_ports fmc_dp4_m2c_p]
set_property PACKAGE_PIN ### TBD ### [get_ports fmc_dp4_m2c_n]
set_property IOSTANDARD LVDS_25 [get_ports {fmc_dp4_m2c_p fmc_dp4_m2c_n}]

set_property PACKAGE_PIN ### TBD ### [get_ports fmc_dp5_m2c_p]
set_property PACKAGE_PIN ### TBD ### [get_ports fmc_dp5_m2c_n]
set_property IOSTANDARD LVDS_25 [get_ports {fmc_dp5_m2c_p fmc_dp5_m2c_n}]

# AD9250 RX SYNC~ (FPGA → ADC, C2M)
set_property PACKAGE_PIN ### TBD ### [get_ports fmc_dp4_c2m_p]
set_property PACKAGE_PIN ### TBD ### [get_ports fmc_dp4_c2m_n]
set_property IOSTANDARD LVDS_25 [get_ports {fmc_dp4_c2m_p fmc_dp4_c2m_n}]

#==============================================================================
# 3. FMC HPC 参考时钟 — GTX RefClk
#==============================================================================
# GBTCLK0_M2C: 通常连接到 GTX Quad 115/116 的 MGTREFCLK0
set_property PACKAGE_PIN ### TBD ### [get_ports fmc_gbtclk0_m2c_p]
set_property PACKAGE_PIN ### TBD ### [get_ports fmc_gbtclk0_m2c_n]

# GBTCLK1_M2C: 通常连接到 GTX Quad 116/117 的 MGTREFCLK1
set_property PACKAGE_PIN ### TBD ### [get_ports fmc_gbtclk1_m2c_p]
set_property PACKAGE_PIN ### TBD ### [get_ports fmc_gbtclk1_m2c_n]

# 时钟约束模板（根据实际 lane rate 调整）
# 例如：lane rate = 5Gbps → refclk = 5GHz / 40 = 125MHz
# create_clock -period 8.000 -name fmc_refclk0 [get_ports fmc_gbtclk0_m2c_p]
# create_clock -period 8.000 -name fmc_refclk1 [get_ports fmc_gbtclk1_m2c_p]

#==============================================================================
# 4. FMC HPC 低速信号 — SPI / SYSREF / 控制
#==============================================================================
# AD9144 SPI (通常接 LAxx，LVCMOS25)
set_property PACKAGE_PIN ### TBD ### [get_ports ad9144_spi_csb]
set_property IOSTANDARD LVCMOS25 [get_ports ad9144_spi_csb]

set_property PACKAGE_PIN ### TBD ### [get_ports ad9144_spi_sclk]
set_property IOSTANDARD LVCMOS25 [get_ports ad9144_spi_sclk]

set_property PACKAGE_PIN ### TBD ### [get_ports ad9144_spi_sdio]
set_property IOSTANDARD LVCMOS25 [get_ports ad9144_spi_sdio]

set_property PACKAGE_PIN ### TBD ### [get_ports ad9144_spi_sdo]
set_property IOSTANDARD LVCMOS25 [get_ports ad9144_spi_sdo]

# AD9250 SPI
set_property PACKAGE_PIN ### TBD ### [get_ports ad9250_spi_csb]
set_property IOSTANDARD LVCMOS25 [get_ports ad9250_spi_csb]

set_property PACKAGE_PIN ### TBD ### [get_ports ad9250_spi_sclk]
set_property IOSTANDARD LVCMOS25 [get_ports ad9250_spi_sclk]

set_property PACKAGE_PIN ### TBD ### [get_ports ad9250_spi_sdio]
set_property IOSTANDARD LVCMOS25 [get_ports ad9250_spi_sdio]

set_property PACKAGE_PIN ### TBD ### [get_ports ad9250_spi_sdo]
set_property IOSTANDARD LVCMOS25 [get_ports ad9250_spi_sdo]

# SYSREF — JESD204B Subclass 1 所需
# 若使用差分 SYSREF：
set_property PACKAGE_PIN ### TBD ### [get_ports fmc_sysref_p]
set_property PACKAGE_PIN ### TBD ### [get_ports fmc_sysref_n]
set_property IOSTANDARD LVDS_25 [get_ports {fmc_sysref_p fmc_sysref_n}]

# 子卡控制信号
set_property PACKAGE_PIN ### TBD ### [get_ports ad9144_reset]
set_property IOSTANDARD LVCMOS25 [get_ports ad9144_reset]

set_property PACKAGE_PIN ### TBD ### [get_ports ad9250_reset]
set_property IOSTANDARD LVCMOS25 [get_ports ad9250_reset]

set_property PACKAGE_PIN ### TBD ### [get_ports fmc_prsnt]
set_property IOSTANDARD LVCMOS25 [get_ports fmc_prsnt]

set_property PACKAGE_PIN ### TBD ### [get_ports fmc_pg_m2c]
set_property IOSTANDARD LVCMOS25 [get_ports fmc_pg_m2c]

#==============================================================================
# 5. 板载 LED（如顶层已包含，此处可省略）
#==============================================================================
# set_property PACKAGE_PIN R24 [get_ports {led[0]}]
# set_property PACKAGE_PIN R23 [get_ports {led[1]}]
# set_property IOSTANDARD LVCMOS33 [get_ports {led[*]}]

#==============================================================================
# 6. False path / 异步约束
#==============================================================================
# SPI 和低速控制信号不关键
set_false_path -to [get_ports {ad9144_spi_csb ad9144_spi_sclk ad9144_spi_sdio}]
set_false_path -to [get_ports {ad9250_spi_csb ad9250_spi_sclk ad9250_spi_sdio}]
set_false_path -to [get_ports {ad9144_reset ad9250_reset}]
set_false_path -from [get_ports {fmc_prsnt fmc_pg_m2c}]

# JESD204B 的 SYNC~ 和 SYSREF 需要特殊时序约束（待 IP 配置后添加）
