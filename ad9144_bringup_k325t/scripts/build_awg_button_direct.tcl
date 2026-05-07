# Build a bitstream for the AD9144 AWG button-control variant.

set script_dir [file normalize [file dirname [info script]]]
set repo_root [file normalize [file join $script_dir ".."]]

source [file join $repo_root "scripts" "synth_awg_button_direct.tcl"]

opt_design
place_design
phys_opt_design
route_design

set rpt_dir [file join $repo_root "vivado_awg_button"]
file mkdir $rpt_dir

report_timing_summary -file [file join $rpt_dir "top_awg_button_timing_routed.rpt"]
report_utilization -file [file join $rpt_dir "top_awg_button_util_routed.rpt"]

set bit_file [file join $rpt_dir "top_awg_button.bit"]
write_bitstream -force $bit_file

puts "BITSTREAM=$bit_file"
