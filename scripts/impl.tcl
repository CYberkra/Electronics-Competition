cd "D:/projects/GPR/Electronics-Competition"
open_project vivado/awg_k325t.xpr
set_property top awg_top [current_fileset]

# Implementation
reset_run impl_1
launch_runs impl_1 -jobs 4
wait_on_run impl_1

set status [get_property PROGRESS [get_runs impl_1]]
puts "Implementation: $status"
if {$status eq "100%"} {
    # Generate bitstream
    launch_runs impl_1 -to_step write_bitstream
    wait_on_run impl_1
    puts "Bitstream generated"
}
exit
