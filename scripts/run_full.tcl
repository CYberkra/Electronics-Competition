# AWG Full Build with timing optimization
cd "D:/projects/GPR/Electronics-Competition"
open_project vivado/awg_k325t.xpr
set_property source_mgmt_mode All [current_project]
set_property top awg_top [current_fileset]

# Synthesis with timing opt
reset_run synth_1
launch_runs synth_1 -jobs 4
wait_on_run synth_1
if {[get_property PROGRESS [get_runs synth_1]] ne "100%"} { puts "SYNTH FAILED"; exit }
open_run synth_1 -name synth_1
puts "SYNTHESIS: PASS"

# Implementation with Explore strategy for better timing
reset_run impl_1
set_property -name "STEPS.OPT_DESIGN.TCL.PRE" -value "opt_design -directive Explore" -objects [get_runs impl_1]
set_property -name "STEPS.PLACE_DESIGN.TCL.PRE" -value "place_design -directive ExtraTimingOpt" -objects [get_runs impl_1]
set_property -name "STEPS.ROUTE_DESIGN.TCL.PRE" -value "route_design -directive AggressiveExplore" -objects [get_runs impl_1]
launch_runs impl_1 -jobs 4
wait_on_run impl_1
set s [get_property PROGRESS [get_runs impl_1]]
puts "IMPL: $s"
if {$s ne "100%"} { puts "IMPL FAILED"; exit }

# Bitstream
launch_runs impl_1 -to_step write_bitstream
wait_on_run impl_1
puts "BITSTREAM: GENERATED"
exit
