# AWG Fast Incremental Build (no reset_runs — 3-5x faster after first build)
cd "D:/projects/GPR/Electronics-Competition"
open_project vivado/awg_k325t.xpr
set_property source_mgmt_mode All [current_project]
set_property top awg_top [current_fileset]
set_property verilog_define {AWG_UART_CONTROL=1 AWG_DEBUG_ILA=1} [current_fileset]

# Skip IP regeneration and run synthesis incrementally
update_compile_order -fileset sources_1

puts "\n=== Incremental Synthesis ==="
launch_runs synth_1 -jobs 4
wait_on_run synth_1
if {[get_property PROGRESS [get_runs synth_1]] ne "100%"} {
    puts "SYNTHESIS FAILED"
    exit
}
puts "SYNTHESIS: PASS"

# Implementation (skip reset)
puts "\n=== Incremental Implementation ==="
launch_runs impl_1 -jobs 4
wait_on_run impl_1
if {[get_property PROGRESS [get_runs impl_1]] ne "100%"} { exit }

# Bitstream
puts "\n=== Bitstream ==="
launch_runs impl_1 -to_step write_bitstream
wait_on_run impl_1
puts "BITSTREAM: GENERATED"
puts "Location: vivado/awg_k325t.runs/impl_1/awg_top.bit"
exit
