# Build minimal KEY->LED test (no FMC/JESD dependency)
cd "D:/projects/GPR/Electronics-Competition"
create_project -force vivado/test_led -part xc7k325tffg900-2
set_property target_language Verilog [current_project]

set srcs [get_filesets sources_1]
add_files -norecurse -fileset $srcs rtl/top/awg_test_led.v

set constrs [get_filesets constrs_1]
add_files -norecurse -fileset $constrs constraints/awg_k325t.xdc

set_property top awg_test_led [current_fileset]
update_compile_order -fileset sources_1

reset_run synth_1
launch_runs synth_1 -jobs 4
wait_on_run synth_1
if {[get_property PROGRESS [get_runs synth_1]] ne "100%"} { exit 1 }
open_run synth_1

reset_run impl_1
launch_runs impl_1 -jobs 4 -to_step write_bitstream
wait_on_run impl_1
if {[get_property PROGRESS [get_runs impl_1]] eq "100%"} {
    puts "BITSTREAM: vivado/test_led.runs/impl_1/awg_test_led.bit"
}
exit
