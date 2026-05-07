# Build an AWG button-control diagnostic bitstream with an extra ILA.
# The normal fallback bit remains in vivado_awg_button/top_awg_button.bit

set script_dir [file normalize [file dirname [info script]]]
set repo_root [file normalize [file join $script_dir ".." ".."]]
set bringup_root [file normalize [file join $script_dir ".."]]

source [file join $bringup_root "scripts" "synth_awg_button_direct.tcl"]

set tx_clk [get_nets -hier -quiet w_tx_core_clk]
if {[llength $tx_clk] != 1} {
    error "Expected one w_tx_core_clk net, got: $tx_clk"
}

set awg_debug_nets [list]
foreach pattern [list \
    *awg_debug_ctrl* \
    *awg_debug_samples* \
    *awg_debug_tdata_lo* \
    *awg_debug_tdata_hi* \
    *awg_debug_phase_inc* \
    *awg_debug_phase_offset* \
] {
    foreach n [get_nets -hier -quiet $pattern] {
        lappend awg_debug_nets $n
    }
}

set awg_debug_nets [lsort -unique -dictionary $awg_debug_nets]
if {[llength $awg_debug_nets] < 300} {
    puts "AWG_DEBUG_NETS=$awg_debug_nets"
    error "Too few AWG debug nets: [llength $awg_debug_nets]"
}

create_debug_core awg_button_ila ila
set_property C_DATA_DEPTH 2048 [get_debug_cores awg_button_ila]
set_property C_TRIGIN_EN false [get_debug_cores awg_button_ila]
set_property C_TRIGOUT_EN false [get_debug_cores awg_button_ila]
set_property PORT_WIDTH [llength $awg_debug_nets] [get_debug_ports awg_button_ila/probe0]
connect_debug_port awg_button_ila/clk $tx_clk
connect_debug_port awg_button_ila/probe0 $awg_debug_nets

puts "AWG_DEBUG_NET_COUNT=[llength $awg_debug_nets]"
set idx 0
foreach n $awg_debug_nets {
    puts "AWG_DEBUG_NET_INDEX=$idx NET=$n"
    incr idx
}

opt_design
place_design
phys_opt_design
route_design

set out_dir [file join $bringup_root "vivado_awg_button"]
file mkdir $out_dir

report_timing_summary -file [file join $out_dir "top_awg_button_debug_timing_routed.rpt"]
report_utilization -file [file join $out_dir "top_awg_button_debug_util_routed.rpt"]

set bit_file [file join $out_dir "top_awg_button_debug.bit"]
set ltx_file [file join $out_dir "top_awg_button_debug.ltx"]
write_debug_probes -force $ltx_file
write_bitstream -force $bit_file

puts "AWG_DEBUG_BITSTREAM=$bit_file"
puts "AWG_DEBUG_PROBES=$ltx_file"
