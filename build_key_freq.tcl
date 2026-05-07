# Rebuild AWG DDS LED Demo with key-controlled frequency
# Target: xc7k325tffg900-2

set script_dir [file normalize [file dirname [info script]]]
set repo_root [file normalize [file join $script_dir ""]]
set proj_dir [file join $repo_root "vivado"]
set proj_name "awg_k325t"
set top_module "awg_dds_led_top"

source [file join $repo_root "scripts" "vivado_threads.tcl"]

# Open project
open_project [file join $proj_dir "$proj_name.xpr"]

# Set top module
set_property top $top_module [get_filesets sources_1]
update_compile_order -fileset sources_1

# Run synthesis
puts "Starting synthesis..."
reset_run synth_1
launch_runs synth_1 -jobs $::AWG_VIVADO_JOBS
wait_on_run synth_1

set synth_status [get_property STATUS [get_runs synth_1]]
puts "Synthesis status: $synth_status"
if {[string match "*ERROR*" $synth_status]} {
    puts "ERROR: Synthesis failed!"
    close_project
    exit 1
}

# Run implementation + bitstream
puts "Starting implementation..."
reset_run impl_1
launch_runs impl_1 -to_step write_bitstream -jobs $::AWG_VIVADO_JOBS
wait_on_run impl_1

set impl_status [get_property STATUS [get_runs impl_1]]
puts "Implementation status: $impl_status"
if {[string match "*ERROR*" $impl_status]} {
    puts "ERROR: Implementation failed!"
    close_project
    exit 1
}

# Report results
set bit_file [file join $proj_dir "${proj_name}.runs" impl_1 "${top_module}.bit"]
set bin_file [file join $proj_dir "${proj_name}.runs" impl_1 "${top_module}.bin"]

puts "=========================================="
puts "Bitstream generated successfully!"
puts "  .bit file: $bit_file"
puts "  .bin file: $bin_file"
puts "=========================================="

close_project
puts "All done. Use Vivado Hardware Manager to program the board."
