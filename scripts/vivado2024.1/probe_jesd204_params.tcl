open_project "D:/awg_fpga/vivado/awg_k325t.xpr"
file mkdir "D:/awg_fpga/vivado/awg_k325t.srcs/sources_1/ip"
create_ip -name jesd204 -vendor xilinx.com -library ip -version 7.2 -module_name jesd204_tx_probe -dir "D:/awg_fpga/vivado/awg_k325t.srcs/sources_1/ip"
puts ""
puts "=== JESD204 TX Available CONFIG Parameters ==="
set props [list_property [get_ips jesd204_tx_probe] -regexp {CONFIG\..*}]
foreach p $props {
    set val [get_property $p [get_ips jesd204_tx_probe]]
    puts "$p = $val"
}
puts ""
puts "=== Done ==="
remove_files [get_files jesd204_tx_probe.xci]
file delete -force "D:/awg_fpga/vivado/awg_k325t.srcs/sources_1/ip/jesd204_tx_probe"
save_project
close_project
