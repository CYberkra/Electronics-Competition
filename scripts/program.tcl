# Program the K325T board with awg_top.bit
cd "D:/FPGA/awg_k325t"

open_hw_manager
connect_hw_server -url localhost:3121

# List targets and find the K325T
set targets [get_hw_targets -quiet]
if {[llength $targets] == 0} {
    puts "ERROR: No hardware targets found. Check JTAG connection."
    exit 1
}
puts "Targets: $targets"

open_hw_target [lindex $targets 0]

set devices [get_hw_devices -quiet]
if {[llength $devices] == 0} {
    puts "ERROR: No devices detected. Check power and JTAG."
    exit 1
}
puts "Devices: $devices"

set device [lindex $devices 0]
current_hw_device $device

set bitfile "vivado/awg_k325t.runs/impl_1/awg_top.bit"
if {![file exists $bitfile]} {
    puts "ERROR: Bitfile not found: $bitfile"
    exit 1
}

puts "Programming [get_property NAME $device] with $bitfile ..."
set_property PROGRAM.FILE $bitfile $device
program_hw_devices $device
puts "PROGRAMMING COMPLETE"

# Optionally refresh and check status
refresh_hw_device $device
puts "Done. Device: [get_property NAME $device] programmed."

close_hw_target
close_hw_manager
exit
