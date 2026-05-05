# ============================================================================
# JESD204 TX IP Creation Script for AD9144 (Vivado 2024.1)
# ============================================================================
# Purpose: Create jesd204 TX IP for AD9144 4-lane configuration
# Usage:   Open project in Vivado 2024.1, then in Tcl Console:
#          source D:/awg_fpga/scripts/vivado2024.1/create_jesd204_tx_ip.tcl
#
# AD9144 Configuration (based on demo工程 + datasheet):
#   - Lanes (L): 4
#   - Lane Rate: 10 Gbps
#   - F (Octets/Frame/Lane): 1
#   - K (Frames/Multiframe): 32
#   - M (Converters): 2  (DAC0 + DAC1, or 4 if using all channels)
#   - S (Samples/Converter/Frame): 1
#   - NP (Bits/Sample): 16
#   - Subclass: 1 (deterministic latency with SYSREF)
#   - Scrambling: Enabled
#   - Ref Clock: 250 MHz (from LMK04828 OUT8/2 = 250M, or 125M from OUT0)
#
# NOTE: Run this AFTER upgrading project to 2024.1 and generating
#       output products for existing IPs.
# ============================================================================

set ip_name "jesd204_tx_ad9144"
set ip_dir  "D:/awg_fpga/vivado/awg_k325t.srcs/sources_1/ip"

puts "========================================"
puts "  Creating JESD204 TX IP for AD9144"
puts "========================================"

# -----------------------------------------------------------------------------
# Step 1: Create IP (jesd204 v7.x for 7-series in Vivado 2024.1)
# -----------------------------------------------------------------------------
# The IP name in catalog: xilinx.com:ip:jesd204:7.2
# Verify exact version in 2024.1 with: get_ipdefs -filter {NAME =~ *jesd204*}
# -----------------------------------------------------------------------------

create_ip -name jesd204 -vendor xilinx.com -library ip -version 7.2 \
    -module_name $ip_name -dir $ip_dir

puts "IP instance created: $ip_name"

# -----------------------------------------------------------------------------
# Step 2: Configure JESD204 TX Parameters
# -----------------------------------------------------------------------------
# These parameters are based on AD9144 datasheet and typical 4-lane config.
# Adjust as needed after consulting AD9144 register settings.
# -----------------------------------------------------------------------------

set_property -dict [list \
    CONFIG.C_LANES              {4} \
    CONFIG.C_LANE_RATE          {10.0} \
    CONFIG.C_REFCLK_FREQUENCY   {250.000} \
    CONFIG.C_SYSREF_REQUIRED    {true} \
    CONFIG.C_LINK_MODE          {1} \
    CONFIG.C_GT_DRP_CLK         {100} \
    CONFIG.C_PLL_SELECTION      {2} \
    CONFIG.C_RX_TPL_BUFFER      {0} \
] [get_ips $ip_name]

# NOTE: The exact CONFIG parameter names may vary by jesd204 IP version.
# If the above fails, open the IP in GUI and check the available properties:
#   report_property [get_ips $ip_name]
# Then adjust this script accordingly.

puts ""
puts "IP configuration applied (see script comments for details)."

# -----------------------------------------------------------------------------
# Step 3: Generate output products
# -----------------------------------------------------------------------------
generate_target all [get_files $ip_dir/$ip_name/$ip_name.xci]

puts ""
puts "Output products generated for $ip_name"
puts ""
puts "Next steps:"
puts "  1. Double-check IP configuration in GUI if needed"
puts "  2. Instantiate $ip_name in awg_fmc_adda_top.v"
puts "  3. Connect GTX ref clock, SYSREF, and TX lanes"
