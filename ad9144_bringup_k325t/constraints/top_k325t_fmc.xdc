# K325T FMCADDA-9250-9144 bring-up constraints
# Target board: Zhengdianyuanzi Kintex-7 K325T, xc7k325tffg900-2
# Top module: vendor demo module "top"
#
# Sources:
# - K7_BASE_1V3_2025_0111_USER.pdf, sheet 15, FMC HPC connectors J34A/J34B/J34E
# - FMCADDA-9250-9144 manual, FMC HPC signal table
#
# Notes:
# - This replaces the vendor demo top.xdc. The vendor top.xdc targets another
#   board/GT bank and must not be used on the K325T FMC connector.
# - Low speed FMC LA pins use VADJ/VCCIO_B17. The existing K325T notes use
#   LVCMOS25/LVDS_25 for this FMC daughter card.

# -----------------------------------------------------------------------------
# GTX reference clock and high speed serial lanes
# -----------------------------------------------------------------------------

# FPGA_REF_CLK_P/N -> GBTCLK0_M2C_P/N -> Bank 117 GTX refclk, 125 MHz
set_property PACKAGE_PIN G8 [get_ports refclk_p]
set_property PACKAGE_PIN G7 [get_ports refclk_n]
create_clock -period 8.000 -name refclk_p [get_ports refclk_p]

# AD9250 JESD204B RX lanes, daughter card -> FPGA
# JESD_AD0_P/N -> DP0_M2C_P/N
set_property PACKAGE_PIN G4 [get_ports adc_rxp_a0]
set_property PACKAGE_PIN G3 [get_ports adc_rxn_a0]

# JESD_AD1_P/N -> DP1_M2C_P/N
set_property PACKAGE_PIN F6 [get_ports adc_rxp_a1]
set_property PACKAGE_PIN F5 [get_ports adc_rxn_a1]

# AD9144 JESD204B TX lanes, FPGA -> daughter card
# JESD_DA0_P/N -> DP0_C2M_P/N
set_property PACKAGE_PIN H2 [get_ports dac_txp_d0]
set_property PACKAGE_PIN H1 [get_ports dac_txn_d0]

# JESD_DA1_P/N -> DP1_C2M_P/N
set_property PACKAGE_PIN F2 [get_ports dac_txp_d1]
set_property PACKAGE_PIN F1 [get_ports dac_txn_d1]

# JESD_DA2_P/N -> DP2_C2M_P/N
set_property PACKAGE_PIN J4 [get_ports dac_txp_d2]
set_property PACKAGE_PIN J3 [get_ports dac_txn_d2]

# JESD_DA3_P/N -> DP3_C2M_P/N
set_property PACKAGE_PIN K2 [get_ports dac_txp_d3]
set_property PACKAGE_PIN K1 [get_ports dac_txn_d3]

# -----------------------------------------------------------------------------
# JESD clocks and sync pins on FMC LA pairs
# -----------------------------------------------------------------------------

# FPGA_JESDCLK_P/N -> LA00_CC_P/N, 125 MHz input to clk_for_glbclk
set_property PACKAGE_PIN D17 [get_ports glblclk_p]
set_property PACKAGE_PIN D18 [get_ports glblclk_n]
set_property IOSTANDARD LVDS_25 [get_ports {glblclk_p glblclk_n}]
create_clock -period 8.000 -name glblclk_p [get_ports glblclk_p]

# FPGA_SYSREF_P/N -> LA20_P/N
set_property PACKAGE_PIN D14 [get_ports sysref_p]
set_property PACKAGE_PIN C14 [get_ports sysref_n]
set_property IOSTANDARD LVDS_25 [get_ports {sysref_p sysref_n}]

# DAC_SYNC0_P/N -> LA05_P/N, AD9144 SYNC input to JESD TX core
set_property PACKAGE_PIN E19 [get_ports i_tx_sync_p]
set_property PACKAGE_PIN D19 [get_ports i_tx_sync_n]
set_property IOSTANDARD LVDS_25 [get_ports {i_tx_sync_p i_tx_sync_n}]

# ADC_SYNC_P/N -> LA13_P/N, JESD RX sync output to AD9250
set_property PACKAGE_PIN D22 [get_ports o_rx_sync_p]
set_property PACKAGE_PIN C22 [get_ports o_rx_sync_n]
set_property IOSTANDARD LVDS_25 [get_ports {o_rx_sync_p o_rx_sync_n}]

set_input_delay -clock [get_clocks glblclk_p] -min 0.45 [get_ports sysref_p]
set_input_delay -clock [get_clocks glblclk_p] -max 0.55 [get_ports sysref_p]

# -----------------------------------------------------------------------------
# AD9250 SPI/control pins
# -----------------------------------------------------------------------------

# FMC_ADC_SDIO -> LA02_N
set_property PACKAGE_PIN J18 [get_ports ads_sda]
set_property IOSTANDARD LVCMOS25 [get_ports ads_sda]

# FMC_ADC_SCLK -> LA01_P_CC
set_property PACKAGE_PIN F21 [get_ports ads_sclk]
set_property IOSTANDARD LVCMOS25 [get_ports ads_sclk]

# FMC_ADC_CSN -> LA01_N_CC
set_property PACKAGE_PIN E21 [get_ports ads_sen_n]
set_property IOSTANDARD LVCMOS25 [get_ports ads_sen_n]

# FMC_ADC_RSTN -> CLK0_M2C_P
set_property PACKAGE_PIN F20 [get_ports ads_rstn]
set_property IOSTANDARD LVCMOS25 [get_ports ads_rstn]

# -----------------------------------------------------------------------------
# AD9144 SPI/control pins
# -----------------------------------------------------------------------------

# FMC_DAC_SDIO -> LA06_P. Vendor SPI module uses one bidirectional SDA pin.
set_property PACKAGE_PIN B18 [get_ports das_sda]
set_property IOSTANDARD LVCMOS25 [get_ports das_sda]

# FMC_DAC_SCLK -> LA10_P
set_property PACKAGE_PIN C19 [get_ports das_sclk]
set_property IOSTANDARD LVCMOS25 [get_ports das_sclk]

# FMC_DAC_CSN -> LA10_N
set_property PACKAGE_PIN B19 [get_ports das_sen_n]
set_property IOSTANDARD LVCMOS25 [get_ports das_sen_n]

# FMC_DAC_RSTN -> LA14_N
set_property PACKAGE_PIN F18 [get_ports das_rstn]
set_property IOSTANDARD LVCMOS25 [get_ports das_rstn]

# FMC_DAC_TXEN0/TXEN1 -> LA04_P/N
set_property PACKAGE_PIN D16 [get_ports das_txen0]
set_property IOSTANDARD LVCMOS25 [get_ports das_txen0]

set_property PACKAGE_PIN C16 [get_ports das_txen1]
set_property IOSTANDARD LVCMOS25 [get_ports das_txen1]

# -----------------------------------------------------------------------------
# LMK04828 SPI/control pins
# -----------------------------------------------------------------------------

# FMC_ADK_SDIO -> LA28_N. This is the vendor lmk_sda signal.
set_property PACKAGE_PIN J12 [get_ports lmk_sda]
set_property IOSTANDARD LVCMOS25 [get_ports lmk_sda]

# FMC_ADK_SCLK -> LA29_N
set_property PACKAGE_PIN E16 [get_ports lmk_sclk]
set_property IOSTANDARD LVCMOS25 [get_ports lmk_sclk]

# FMC_ADK_CSB -> LA28_P
set_property PACKAGE_PIN J11 [get_ports lmk_cs_n]
set_property IOSTANDARD LVCMOS25 [get_ports lmk_cs_n]

# FMC_ADK_RST -> LA29_P
set_property PACKAGE_PIN F15 [get_ports lmk_rst]
set_property IOSTANDARD LVCMOS25 [get_ports lmk_rst]

# -----------------------------------------------------------------------------
# Timing groups and bitstream properties
# -----------------------------------------------------------------------------

# STARTUPE2 CFGMCLK is the vendor demo internal oscillator clock.
create_clock -period 15.384 -name cfgmclk [get_pins STARTUPE2_inst/CFGMCLK]

set_clock_groups -asynchronous -group [get_clocks *glblclk*] -group [get_clocks *cfgmclk*]
set_clock_groups -asynchronous -group [get_clocks *refclk*] -group [get_clocks *cfgmclk*]

set_property BITSTREAM.CONFIG.UNUSEDPIN Pullnone [current_design]
set_property BITSTREAM.GENERAL.COMPRESS true [current_design]
