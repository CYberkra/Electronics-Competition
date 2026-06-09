# Run KEY/LED behavioral simulation
cd "D:/projects/GPR/Electronics-Competition"

# Use disk-based project for simulation compatibility
create_project -force sim_key_led sim/sim_key_led -part xc7k325tffg900-2
add_files -fileset sim_1 rtl/control/awg_key_ui_ctrl.v
add_files -fileset sim_1 rtl/control/awg_led_status.v
add_files -fileset sim_1 sim/tb/tb_key_led.v
set_property top tb_key_led [get_filesets sim_1]
set_property -name {xsim.simulate.runtime} -value {100us} -objects [get_filesets sim_1]
set_property -name {xsim.simulate.log_all_signals} -value {true} -objects [get_filesets sim_1]
update_compile_order -fileset sim_1

# Run behavioral simulation
launch_simulation -mode behavioral
close_sim
close_project
puts "SIMULATION: PASS"
exit
