create_project -in_memory -part xc7k325tffg900-2
puts "All JESD204 related IPs:"
set all_ips [get_ipdefs -filter {NAME =~ "*jesd*"}]
foreach ip $all_ips {
    puts "  [get_property VLNV $ip]"
}

puts "\nAll transceiver related IPs:"
set gt_ips [get_ipdefs -filter {NAME =~ "*gt*" || NAME =~ "*phy*"}]
foreach ip $gt_ips {
    set name [get_property NAME $ip]
    if {[string match "*gt*" $name] || [string match "*phy*" $name]} {
        puts "  [get_property VLNV $ip]"
    }
}

exit
