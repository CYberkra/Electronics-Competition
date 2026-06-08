cd "D:/projects/GPR/Electronics-Competition"
open_project vivado/awg_k325t.xpr
set_property source_mgmt_mode All [current_project]
set_property top awg_top [current_fileset]

puts "Launching implementation (Explore directive)..."
reset_run impl_1
launch_runs impl_1 -jobs 4 -dir impl_explore
wait_on_run impl_1
set s [get_property PROGRESS [get_runs impl_1]]
puts "Implementation result: $s"
if {$s eq "100%"} {
    launch_runs impl_1 -to_step write_bitstream
    wait_on_run impl_1
    puts "Bitstream generated."
}
exit
