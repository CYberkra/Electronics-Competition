# Upgrade all locked IPs for Vivado 2024.1
cd "D:/projects/GPR/Electronics-Competition"
open_project vivado/awg_k325t.xpr

# Report locked IPs
set locked_ips [get_ips -quiet -filter "IS_LOCKED == 1"]
puts "Locked IPs: [llength $locked_ips]"
foreach ip $locked_ips {
    puts "  $ip"
}

# Upgrade all IPs
if {[llength $locked_ips] > 0} {
    puts "Upgrading IPs..."
    upgrade_ip $locked_ips
}

# Regenerate all targets
puts "Regenerating targets..."
foreach ip $locked_ips {
    set xci [get_property IP_FILE $ip]
    if {[file exists $xci]} {
        puts "  Generating target for: $ip"
    }
}

# Generate all output products
puts "Generating all output products..."
generate_target all [get_files *.xci] -force

puts "IP upgrade complete"
exit
