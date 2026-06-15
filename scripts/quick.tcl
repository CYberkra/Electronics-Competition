set_param general.maxThreads 16
open_project vivado/awg_k325t.xpr
set_property top awg_top [current_fileset]
set_property verilog_define {AWG_UART_CONTROL=1} [current_fileset]
update_compile_order -fileset sources_1
reset_run synth_1
launch_runs synth_1 -jobs 8 ; wait_on_run synth_1
if {[get_property PROGRESS [get_runs synth_1]] != "100%"} { puts "SYNTH FAILED"; exit 1 }
reset_run impl_1
launch_runs impl_1 -jobs 12 -to_step write_bitstream ; wait_on_run impl_1
if {[get_property PROGRESS [get_runs impl_1]] == "100%"} { puts "BITSTREAM READY" } else { puts "IMPL FAILED" }
exit
