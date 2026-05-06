set bit_file "D:/FPGA/ad9144_bringup_k325t/vivado_awg_button/top_awg_button.bit"

if {![file exists $bit_file]} {
    error "Missing bitstream: $bit_file"
}

open_hw_manager
connect_hw_server -allow_non_jtag
open_hw_target

set dev [lindex [get_hw_devices xc7k325t_0] 0]
if {$dev eq ""} {
    error "xc7k325t_0 not found"
}

current_hw_device $dev
set_property PROGRAM.FILE $bit_file $dev
program_hw_devices $dev
refresh_hw_device $dev

puts "PROGRAMMED_BITSTREAM=$bit_file"
