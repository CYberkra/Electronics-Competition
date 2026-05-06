# Build a bitstream for the AD9144 AWG button-control variant.

source D:/FPGA/ad9144_bringup_k325t/scripts/synth_awg_button_direct.tcl

opt_design
place_design
phys_opt_design
route_design

report_timing_summary -file D:/FPGA/ad9144_bringup_k325t/vivado_awg_button/top_awg_button_timing_routed.rpt
report_utilization -file D:/FPGA/ad9144_bringup_k325t/vivado_awg_button/top_awg_button_util_routed.rpt

set bit_file "D:/FPGA/ad9144_bringup_k325t/vivado_awg_button/top_awg_button.bit"
write_bitstream -force $bit_file

puts "BITSTREAM=$bit_file"
