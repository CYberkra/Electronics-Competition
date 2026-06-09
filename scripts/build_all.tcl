# AWG Full Build: Synth → Impl → Bitstream
cd "D:/projects/GPR/Electronics-Competition"
open_project vivado/awg_k325t.xpr
set_property source_mgmt_mode All [current_project]
set_property top awg_top [current_fileset]

# Enable UART control + ILA debug
set_property verilog_define {AWG_UART_CONTROL=1 AWG_DEBUG_ILA=1} [current_fileset]

# Ensure ILA IP output products are generated before synthesis
catch {generate_target all [get_files */ila_awg_debug.xci] -force}
catch {reset_run ila_awg_debug_synth_1}
launch_runs ila_awg_debug_synth_1 -jobs 4
wait_on_run ila_awg_debug_synth_1

# Check all IPs
foreach xci [get_files *.xci] {
    set fpath [string map {\\ /} $xci]
    if {[regexp {/ip_\d+/} $fpath]} { continue }
    set ip_name [file rootname [file tail $xci]]
    set locked [catch {get_property IS_LOCKED [get_ips $ip_name]}]
    if {$locked} {
        upgrade_ip [get_ips $ip_name]
        generate_target all [list $xci] -force
        puts "Upgraded: $ip_name"
    }
}

update_compile_order -fileset sources_1

# Reset and launch synthesis
reset_run synth_1
puts "\n=== Synthesis ==="
launch_runs synth_1 -jobs 4
wait_on_run synth_1
if {[get_property PROGRESS [get_runs synth_1]] ne "100%"} {
    puts "SYNTHESIS FAILED"
    exit
}
open_run synth_1 -name synth_1
puts "SYNTHESIS: PASS"

# Implementation
reset_run impl_1
puts "\n=== Implementation ==="
launch_runs impl_1 -jobs 4
wait_on_run impl_1
set impl_status [get_property PROGRESS [get_runs impl_1]]
puts "Implementation: $impl_status"
if {$impl_status ne "100%"} { exit }

# Bitstream
puts "\n=== Bitstream ==="
launch_runs impl_1 -to_step write_bitstream
wait_on_run impl_1
puts "BITSTREAM: GENERATED"
puts "Location: vivado/awg_k325t.runs/impl_1/awg_top.bit"
exit
