set script_dir [file normalize [file dirname [info script]]]
set repo_root [file normalize [file join $script_dir ".." ".."]]
set project_dir [file join $repo_root "vivado"]
set ip_dir [file join $project_dir "awg_k325t.srcs" "sources_1" "ip"]

open_project [file join $project_dir "awg_k325t.xpr"]
file mkdir $ip_dir
create_ip -name jesd204 -vendor xilinx.com -library ip -version 7.2 -module_name jesd204_tx_probe -dir $ip_dir
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
file delete -force [file join $ip_dir "jesd204_tx_probe"]
save_project
close_project
