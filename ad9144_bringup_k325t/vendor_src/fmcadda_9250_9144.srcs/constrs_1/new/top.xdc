# GT Pin Locations
set_property PACKAGE_PIN C8 [get_ports refclk_p]
set_property PACKAGE_PIN AE28 [get_ports glblclk_p]
set_property IOSTANDARD LVDS_25 [get_ports glblclk_p]

set_property PACKAGE_PIN A8 [get_ports adc_rxp_a0]
set_property PACKAGE_PIN B6 [get_ports adc_rxp_a1]

set_property PACKAGE_PIN A4 [get_ports dac_txp_d0]
set_property PACKAGE_PIN B2 [get_ports dac_txp_d1]
set_property PACKAGE_PIN C4 [get_ports dac_txp_d2]
set_property PACKAGE_PIN D2 [get_ports dac_txp_d3]
#set_property PACKAGE_PIN F2 [get_ports dac_txp_d4]
#set_property PACKAGE_PIN K2 [get_ports dac_txp_d5]
#set_property PACKAGE_PIN H2 [get_ports dac_txp_d6]
#set_property PACKAGE_PIN J4 [get_ports dac_txp_d7]
# Core Time Specs
create_clock -period 8.000 -name refclk_p [get_ports refclk_p]
create_clock -period 8.000 -name glblclk_p [get_ports glblclk_p]


set_property PACKAGE_PIN AH27 [get_ports ads_sda]
set_property IOSTANDARD LVCMOS25 [get_ports ads_sda]

set_property PACKAGE_PIN AG29 [get_ports ads_sclk]
set_property IOSTANDARD LVCMOS25 [get_ports ads_sclk]

set_property PACKAGE_PIN AH29 [get_ports ads_sen_n]
set_property IOSTANDARD LVCMOS25 [get_ports ads_sen_n]

set_property PACKAGE_PIN F20 [get_ports ads_rstn]
set_property IOSTANDARD LVCMOS25 [get_ports ads_rstn]

set_property PACKAGE_PIN AA30 [get_ports das_rstn]
set_property IOSTANDARD LVCMOS25 [get_ports das_rstn]

set_property PACKAGE_PIN AD29  [get_ports das_sda]
set_property IOSTANDARD LVCMOS25 [get_ports das_sda]

set_property PACKAGE_PIN AE30 [get_ports das_sclk]
set_property IOSTANDARD LVCMOS25 [get_ports das_sclk]

set_property PACKAGE_PIN AF30 [get_ports das_sen_n]
set_property IOSTANDARD LVCMOS25 [get_ports das_sen_n]

set_property PACKAGE_PIN AJ26 [get_ports das_txen0]
set_property IOSTANDARD LVCMOS25 [get_ports das_txen0]

set_property PACKAGE_PIN AK26 [get_ports das_txen1]
set_property IOSTANDARD LVCMOS25 [get_ports das_txen1]

set_property PACKAGE_PIN B24 [get_ports lmk_sda]
set_property IOSTANDARD LVCMOS25 [get_ports lmk_sda]

set_property PACKAGE_PIN D24 [get_ports lmk_sclk]
set_property IOSTANDARD LVCMOS25 [get_ports lmk_sclk]

set_property PACKAGE_PIN C24 [get_ports lmk_cs_n]
set_property IOSTANDARD LVCMOS25 [get_ports lmk_cs_n]

set_property PACKAGE_PIN E24 [get_ports lmk_rst]
set_property IOSTANDARD LVCMOS25 [get_ports lmk_rst]

set_property PACKAGE_PIN Y28 [get_ports sysref_p]
set_property IOSTANDARD LVDS_25 [get_ports sysref_p]

set_property PACKAGE_PIN AC29 [get_ports o_rx_sync_p]
set_property IOSTANDARD LVDS_25 [get_ports o_rx_sync_p]

set_property PACKAGE_PIN AJ28 [get_ports i_tx_sync_p]
set_property IOSTANDARD LVDS_25 [get_ports i_tx_sync_p]

create_clock -period 15.384 -name sys_clk -waveform {0.000 7.692} [get_pins STARTUPE2_inst/CFGMCLK]
set_input_delay -clock [get_clocks {glblclk_p}] -min  0.45 [get_ports {sysref_p}]
set_input_delay -clock [get_clocks {glblclk_p}] -max  0.55 [get_ports {sysref_p}]

set_clock_groups -asynchronous -group [get_clocks "*glbclk*"] -group [get_clocks  "*sys*"]
set_clock_groups -asynchronous -group [get_clocks "*refclk*"] -group [get_clocks  "*sys*"]

# Unused PIN Pullnone
set_property BITSTREAM.CONFIG.UNUSEDPIN Pullnone [current_design]

# enable bitstream compression
set_property BITSTREAM.GENERAL.COMPRESS true [current_design]
