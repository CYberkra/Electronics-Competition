#------------------------------------------------------------------------------
# Create JESD204 IP for FMC ADDA (AD9144 + AD9250)
# Target: Kintex-7 XC7K325TFFG900-2
#------------------------------------------------------------------------------

set proj_dir "D:/awg_fpga/vivado"
set proj_name "awg_k325t"

open_project [file join $proj_dir "$proj_name.xpr"]

#==============================================================================
# 1. Create JESD204 TX IP for AD9144 (4 Lane, 10Gbps)
#==============================================================================
set tx_ip "jesd204_tx"
create_ip -name jesd204 -vendor xilinx.com -library ip -version 7.2 -module_name $tx_ip

set_property -dict [list \
    CONFIG.C_NODE_IS_TRANSMIT {1} \
    CONFIG.C_LANES {4} \
    CONFIG.C_LINE_RATE {10} \
    CONFIG.C_REFCLK_FREQUENCY {125} \
    CONFIG.C_SYSREF_REQUIRED {1} \
    CONFIG.C_SUBCLASS {1} \
    CONFIG.C_F {1} \
    CONFIG.C_K {32} \
    CONFIG.C_M {2} \
    CONFIG.C_SCR {1} \
    CONFIG.C_LINKS {1} \
    CONFIG.C_PLL_SELECTION {2} \
    CONFIG.C_TRANSCEIVER {GTX} \
    CONFIG.C_GT_LineRate {10.0} \
    CONFIG.C_GT_REFCLK_FREQ {125.000} \
    CONFIG.C_GT_DRPCLK {100} \
] [get_ips $tx_ip]

generate_target {instantiation_template} [get_ips $tx_ip]
generate_target all [get_ips $tx_ip]

#==============================================================================
# 2. Create JESD204 RX IP for AD9250 (2 Lane, 5Gbps)
#==============================================================================
set rx_ip "jesd204_rx"
create_ip -name jesd204 -vendor xilinx.com -library ip -version 7.2 -module_name $rx_ip

set_property -dict [list \
    CONFIG.C_NODE_IS_TRANSMIT {0} \
    CONFIG.C_LANES {2} \
    CONFIG.C_LINE_RATE {5} \
    CONFIG.C_REFCLK_FREQUENCY {125} \
    CONFIG.C_SYSREF_REQUIRED {1} \
    CONFIG.C_SUBCLASS {1} \
    CONFIG.C_F {2} \
    CONFIG.C_K {32} \
    CONFIG.C_M {2} \
    CONFIG.C_SCR {1} \
    CONFIG.C_LINKS {1} \
    CONFIG.C_PLL_SELECTION {2} \
    CONFIG.C_TRANSCEIVER {GTX} \
    CONFIG.C_GT_LineRate {5.0} \
    CONFIG.C_GT_REFCLK_FREQ {125.000} \
    CONFIG.C_GT_DRPCLK {100} \
] [get_ips $rx_ip]

generate_target {instantiation_template} [get_ips $rx_ip]
generate_target all [get_ips $rx_ip]

#==============================================================================
# 3. Create JESD204 PHY for combined TX/RX
#==============================================================================
set phy_ip "jesd204_phy"
create_ip -name jesd204_phy -vendor xilinx.com -library ip -version 3.2 -module_name $phy_ip

set_property -dict [list \
    CONFIG.C_LANES {4} \
    CONFIG.C_RX_LANES {2} \
    CONFIG.C_TX_LANES {4} \
    CONFIG.C_LINE_RATE {10} \
    CONFIG.C_REFCLK_FREQUENCY {125} \
    CONFIG.C_TRANSCEIVER {GTX} \
    CONFIG.C_PLL_SELECTION {2} \
    CONFIG.C_GT_LineRate {10.0} \
    CONFIG.C_GT_REFCLK_FREQ {125.000} \
    CONFIG.C_GT_DRPCLK {100} \
] [get_ips $phy_ip]

generate_target {instantiation_template} [get_ips $phy_ip]
generate_target all [get_ips $phy_ip]

#==============================================================================
# 4. Save project
#==============================================================================
save_project_as -force [file join $proj_dir "$proj_name.xpr"]
close_project

puts "JESD204 IP creation completed."
puts "  TX: $tx_ip (4L, 10Gbps)"
puts "  RX: $rx_ip (2L, 5Gbps)"
puts "  PHY: $phy_ip (4TX + 2RX)"
