# ============================================================================
# JESD204 TX IP Creation for AD9144 (Vivado 2024.1)
# ============================================================================
# Verified parameters from jesd204 v7.2 probe
# ============================================================================

set ip_name "jesd204_tx_ad9144"
set script_dir [file normalize [file dirname [info script]]]
set repo_root [file normalize [file join $script_dir ".." ".."]]
set project_dir [file join $repo_root "vivado"]
set ip_dir  [file join $project_dir "awg_k325t.srcs" "sources_1" "ip"]
set project_path [file join $project_dir "awg_k325t.xpr"]

puts "========================================"
puts "  Creating JESD204 TX IP for AD9144"
puts "========================================"

open_project $project_path
file mkdir $ip_dir

# Remove old IP if exists
if {[llength [get_ips -quiet $ip_name]] > 0} {
    set old_xci [get_files -quiet -of_objects [get_ips $ip_name]]
    if {[llength $old_xci] > 0} { remove_files $old_xci }
    file delete -force "$ip_dir/$ip_name"
}

create_ip -name jesd204 -vendor xilinx.com -library ip -version 7.2 \
    -module_name $ip_name -dir $ip_dir

puts "IP created: $ip_name"

# Set verified parameters from probe
set_property -dict [list \
    CONFIG.C_LANES                    {4} \
    CONFIG.GT_Line_Rate               {10.0} \
    CONFIG.GT_REFCLK_FREQ             {125.000} \
    CONFIG.C_NODE_IS_TRANSMIT         {1} \
    CONFIG.C_DEFAULT_SYSREF_REQUIRED  {1} \
    CONFIG.C_DEFAULT_F                {1} \
    CONFIG.C_DEFAULT_SCR              {1} \
    CONFIG.C_PLL_SELECTION            {0} \
    CONFIG.Transceiver                {GTXE2} \
] [get_ips $ip_name]

puts "Parameters configured"

# Generate output products
generate_target all [get_files -of_objects [get_ips $ip_name]]
puts "Output products generated"

close_project

puts ""
puts "========================================"
puts "  JESD204 TX IP created successfully!"
puts "========================================"
