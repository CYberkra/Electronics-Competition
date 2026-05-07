# Program the latest AWG base bitstream onto the connected K325T board.

set script_dir [file normalize [file dirname [info script]]]
set repo_root [file normalize [file join $script_dir ".."]]
set bit_file [file join $repo_root "vivado" "awg_k325t.runs" "impl_1" "awg_dds_led_top.bit"]

proc cleanup_and_exit {code message} {
    puts $message
    catch {close_hw_target}
    catch {disconnect_hw_server}
    catch {close_hw_manager}
    exit $code
}

if {![file exists $bit_file]} {
    puts "ERROR: bitstream not found: $bit_file"
    exit 1
}

open_hw_manager
catch {disconnect_hw_server}
connect_hw_server -allow_non_jtag

set targets [get_hw_targets *]
puts "HW_TARGETS=$targets"
if {[llength $targets] == 0} {
    cleanup_and_exit 2 "ERROR: no hardware targets found"
}

set target [lindex $targets 0]
if {[catch {open_hw_target $target} err]} {
    cleanup_and_exit 3 "ERROR: failed to open hardware target: $err"
}

set devs [get_hw_devices xc7k325t_0]
if {[llength $devs] == 0} {
    set devs [get_hw_devices]
}
if {[llength $devs] == 0} {
    cleanup_and_exit 4 "ERROR: no hardware devices found after opening target"
}

set dev [lindex $devs 0]
current_hw_device $dev
puts "CURRENT_DEVICE=$dev"
puts "PART=[get_property PART $dev]"

set_property PROGRAM.FILE $bit_file $dev
program_hw_devices $dev
refresh_hw_device -update_hw_probes false $dev

puts "PROGRAM_DONE=$bit_file"

close_hw_target
disconnect_hw_server
close_hw_manager
exit 0
