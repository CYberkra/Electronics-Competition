create_project -in_memory -part xc7k325tffg900-2
set jesd_ips [get_ipdefs -filter {NAME =~ *jesd204*}]
if {[llength $jesd_ips] > 0} {
    puts "OK: Found JESD204 IP definitions:"
    foreach ip $jesd_ips {
        puts "  - [get_property NAME $ip] v[get_property VERSION $ip]"
    }
} else {
    puts "WARNING: No JESD204 IP found in catalog!"
}
close_project
