# Program AWG debug bit and export ILA capture CSV files.

set script_dir [file normalize [file dirname [info script]]]
set repo_root [file normalize [file join $script_dir ".."]]
set bit_file [file join $repo_root "artifacts" "debug" "awg_dds_led_top_debug.bit"]
set ltx_file [file join $repo_root "artifacts" "debug" "awg_dds_led_top_debug.ltx"]
set out_dir [file join $repo_root "measurements" "ila"]

proc cleanup_and_exit {code message} {
    puts $message
    catch {close_hw_target}
    catch {disconnect_hw_server}
    catch {close_hw_manager}
    exit $code
}

if {![file exists $bit_file]} {
    puts "ERROR: debug bit not found: $bit_file"
    exit 1
}

file mkdir $out_dir

set ts [clock format [clock seconds] -format "%Y%m%d_%H%M%S"]
set run_dir [file join $out_dir "capture_$ts"]
file mkdir $run_dir

puts "AWG_DEBUG_PROGRAM_START"
puts "BIT_FILE=$bit_file"
puts "LTX_FILE=$ltx_file"
puts "CAPTURE_DIR=$run_dir"

open_hw_manager
catch {disconnect_hw_server}
connect_hw_server -allow_non_jtag

set targets [get_hw_targets *]
puts "HW_TARGETS=$targets"
if {[llength $targets] == 0} {
    cleanup_and_exit 2 "ERROR: no hardware targets found"
}

set target [lindex $targets 0]
set target_opened 0
set last_open_error ""
for {set attempt 1} {$attempt <= 3} {incr attempt} {
    puts "OPEN_TARGET_ATTEMPT=$attempt"
    if {[catch {open_hw_target $target} err]} {
        set last_open_error $err
        puts "OPEN_TARGET_FAILED=$err"
        catch {close_hw_target}
        after 1000
        catch {disconnect_hw_server}
        connect_hw_server -allow_non_jtag
        set targets [get_hw_targets *]
        puts "HW_TARGETS_RETRY=$targets"
        if {[llength $targets] > 0} {
            set target [lindex $targets 0]
        }
    } else {
        set target_opened 1
        break
    }
}

if {!$target_opened} {
    cleanup_and_exit 3 "ERROR: Digilent cable was found, but no FPGA devices were detected on the JTAG chain. Last open_hw_target error: $last_open_error"
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
set_property BSCAN_SWITCH_USER_MASK 1 $dev

set_property PROGRAM.FILE $bit_file $dev
if {[file exists $ltx_file]} {
    set_property PROBES.FILE $ltx_file $dev
}
program_hw_devices $dev
after 2000
set_property BSCAN_SWITCH_USER_MASK 1 $dev
refresh_hw_device -update_hw_probes true $dev

set ilas [get_hw_ilas]
puts "HW_ILAS=$ilas"
if {[llength $ilas] == 0} {
    cleanup_and_exit 5 "ERROR: no ILA cores found after programming"
}

foreach ila $ilas {
    current_hw_ila $ila
    puts "CAPTURING_ILA=$ila"

    if {[catch {run_hw_ila -trigger_now $ila} err]} {
        puts "trigger_now failed, falling back to default trigger: $err"
        run_hw_ila $ila
    }
    wait_on_hw_ila $ila

    set data [upload_hw_ila_data $ila]
    set ila_name $ila
    regsub -all {[^A-Za-z0-9_]} $ila_name "_" ila_name
    set csv_file [file join $run_dir "${ila_name}.csv"]
    write_hw_ila_data -csv_file $csv_file $data
    puts "ILA_CSV=$csv_file"
}

puts "AWG_DEBUG_CAPTURE_DONE"

close_hw_target
disconnect_hw_server
close_hw_manager
exit 0
