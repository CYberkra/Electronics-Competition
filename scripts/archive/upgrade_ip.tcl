# ============================================================================
# Vivado 2024.1 IP Upgrade Script
# ============================================================================
# Purpose: Open existing 2024.2 project in 2024.1 and upgrade all IPs
# Usage:   vivado -mode batch -source upgrade_ip.tcl
#          (run from D:\awg_fpga or adjust project_path below)
# ============================================================================

set script_dir [file normalize [file dirname [info script]]]
set repo_root [file normalize [file join $script_dir ".." ".."]]

set project_path [file join $repo_root "vivado" "awg_k325t.xpr"]
set output_dir   [file join $repo_root "vivado"]

puts "========================================"
puts "  Opening project: $project_path"
puts "========================================"

open_project $project_path

# -----------------------------------------------------------------------------
# Step 1: Upgrade all IPs that need upgrading
# -----------------------------------------------------------------------------
puts ""
puts "Checking for IPs that need upgrade..."
set ips_to_upgrade [get_ips -filter {IS_LOCKED==1 || UPGRADE_VERSIONS != {}}]

if {[llength $ips_to_upgrade] > 0} {
    puts "Found [llength $ips_to_upgrade] IP(s) to upgrade:"
    foreach ip $ips_to_upgrade {
        puts "  - $ip"
    }

    puts ""
    puts "Upgrading IPs..."
    upgrade_ip $ips_to_upgrade
    puts "IP upgrade complete."
} else {
    puts "No IPs require upgrade."
}

# -----------------------------------------------------------------------------
# Step 2: Generate Output Products for all IPs
# -----------------------------------------------------------------------------
puts ""
puts "Generating output products for all IPs..."
set all_ips [get_ips]
foreach ip $all_ips {
    puts "  Generating: $ip"
    generate_target all [get_files $ip.xci]
}
puts "Output products generated."

# -----------------------------------------------------------------------------
# Step 3: Save and close
# -----------------------------------------------------------------------------
puts ""
puts "Saving project..."
save_project_as -force awg_k325t $output_dir
close_project

puts ""
puts "========================================"
puts "  Project upgraded successfully!"
puts "========================================"
puts ""
puts "Next steps:"
puts "  1. Open the upgraded project in Vivado 2024.1 GUI"
puts "  2. Run Synthesis → Implementation → Generate Bitstream"
puts "  3. Create JESD204 IP via Tools → Create and Package New IP"
