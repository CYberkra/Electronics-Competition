# DEPRECATED: This script is from an early project iteration.
# Use scripts/vivado2024.1/probe_jesd204_params.tcl for current IP probing.
# This script remains for reference only.
#
# Inspect DDS Compiler IP parameters
# Run: vivado -mode batch -source scripts/inspect_ip_params.tcl

set script_dir [file normalize [file dirname [info script]]]
set repo_root [file normalize [file join $script_dir ".."]]
set project_dir [file join $repo_root "vivado"]
set project_name "awg_k325t"

open_project [file join $project_dir "$project_name.xpr"]



set ip_name "dds_compiler_0"
set ip [get_ips $ip_name]

# List all parameters and their values
puts "=========================================="
puts "DDS Compiler IP Parameters"
puts "=========================================="

foreach prop [list_property $ip CONFIG.*] {
    set val [get_property $prop $ip]
    set enabled [get_property ${prop}.IS_ENABLED $ip]
    puts "$prop = $val (enabled: $enabled)"
}

puts "=========================================="

# Save to file
set out_file [file join $repo_root ".sisyphus" "evidence" "dds_compiler_params.txt"]
file mkdir [file dirname $out_file]
set fh [open $out_file w]
puts $fh "DDS Compiler v6.0 Parameter Dump"
puts $fh "================================="
puts $fh "Timestamp: [clock format [clock seconds]]"
puts $fh ""
foreach prop [list_property $ip CONFIG.*] {
    set val [get_property $prop $ip]
    set enabled [get_property ${prop}.IS_ENABLED $ip]
    puts $fh "$prop = $val (enabled: $enabled)"
}
close $fh

puts "Parameter dump saved to: $out_file"

close_project
exit
