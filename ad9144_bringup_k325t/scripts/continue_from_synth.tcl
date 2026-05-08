# Continue implementation from existing synthesis checkpoint
set script_dir [file normalize [file dirname [info script]]]
set repo_root [file normalize [file join $script_dir ".."]]
set out_dir [file join $repo_root "vivado_awg_uart"]

open_checkpoint [file join $out_dir "top_awg_uart_synth.dcp"]

opt_design
place_design
phys_opt_design
route_design

report_timing_summary -file [file join $out_dir "top_awg_uart_timing_routed.rpt"]
report_utilization -file [file join $out_dir "top_awg_uart_util_routed.rpt"]

set bit_file [file join $out_dir "top_awg_uart.bit"]
write_bitstream -force $bit_file

puts "UART_BITSTREAM=$bit_file"
