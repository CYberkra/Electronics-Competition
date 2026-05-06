# Rebuild AWG Base Project (DDS IP + DAC Interface)
# Target: awg_dds_led_top -> bitstream

set script_dir [file normalize [file dirname [info script]]]
set repo_root [file normalize [file join $script_dir ".."]]
set proj_dir [file join $repo_root "vivado"]
set proj_name "awg_k325t"

# Open project
open_project [file join $proj_dir "$proj_name.xpr"]

# Ensure top module is set
set_property top awg_dds_led_top [get_filesets sources_1]
update_compile_order -fileset sources_1
update_compile_order -fileset sim_1

# Run synthesis
puts "========================================"
puts "Starting Synthesis..."
puts "========================================"
reset_run synth_1
launch_runs synth_1 -jobs 4
wait_on_run synth_1

set synth_status [get_property STATUS [get_runs synth_1]]
puts "Synthesis status: $synth_status"

if {[string match "*ERROR*" $synth_status] || [string match "*FAIL*" $synth_status]} {
    puts "[ERROR] Synthesis failed!"
    close_project
    exit 1
}

# Run implementation + bitstream
puts ""
puts "========================================"
puts "Starting Implementation + Bitstream..."
puts "========================================"
reset_run impl_1
launch_runs impl_1 -to_step write_bitstream -jobs 4
wait_on_run impl_1

set impl_status [get_property STATUS [get_runs impl_1]]
puts "Implementation status: $impl_status"

if {[string match "*ERROR*" $impl_status] || [string match "*FAIL*" $impl_status]} {
    puts "[ERROR] Implementation failed!"
    close_project
    exit 1
}

# Report results
set bit_file [file join $proj_dir "${proj_name}.runs" impl_1 "awg_dds_led_top.bit"]
set bin_file [file join $proj_dir "${proj_name}.runs" impl_1 "awg_dds_led_top.bin"]
set timing_rpt [file join $proj_dir "${proj_name}.runs" impl_1 "awg_dds_led_top_timing_summary_routed.rpt"]

puts ""
puts "========================================"
puts "SUCCESS: Bitstream generated!"
puts "  .bit: $bit_file"
puts "  .bin: $bin_file"
puts "  Timing report: $timing_rpt"
puts "========================================"

close_project
exit 0
