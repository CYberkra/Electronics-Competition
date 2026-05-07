set script_dir [file normalize [file dirname [info script]]]
set proj_root [file normalize [file join $script_dir ".."]]

set bit_file [file join $proj_root "vivado_awg_button" "top_awg_button_debug.bit"]
set probes_file [file join $proj_root "vivado_awg_button" "top_awg_button_debug.ltx"]
set out_dir [file join $proj_root "vivado_awg_button" "awg_debug_capture"]
file mkdir $out_dir

if {![file exists $bit_file]} {
    error "Missing debug bitstream: $bit_file"
}
if {![file exists $probes_file]} {
    error "Missing debug probes file: $probes_file"
}

puts "CAPTURE_AWG_BUTTON_DEBUG_START"
puts "BIT_FILE=$bit_file"
puts "PROBES_FILE=$probes_file"

open_hw_manager
connect_hw_server -allow_non_jtag
open_hw_target

set dev [lindex [get_hw_devices xc7k325t*] 0]
if {$dev eq ""} {
    error "No xc7k325t hardware device found"
}

current_hw_device $dev
set_property PROGRAM.FILE $bit_file $dev
set_property PROBES.FILE $probes_file $dev
program_hw_devices $dev
puts "PROGRAM_DONE"
puts "WAIT_AFTER_PROGRAM_MS=12000"
after 12000
refresh_hw_device $dev

set awg_ila ""
foreach ila [get_hw_ilas] {
    set probe_names [join [get_hw_probes -of_objects $ila] " "]
    if {[string match "*awg_debug_ctrl*" $probe_names] || [string match "*awg_debug_samples*" $probe_names]} {
        set awg_ila $ila
        break
    }
}

if {$awg_ila eq ""} {
    puts "AVAILABLE_ILAS=[get_hw_ilas]"
    foreach ila [get_hw_ilas] {
        puts "ILA=$ila PROBES=[get_hw_probes -of_objects $ila]"
    }
    error "Could not find AWG debug ILA"
}

current_hw_ila $awg_ila
puts "AWG_ILA=$awg_ila"
puts "AWG_ILA_PROBES=[get_hw_probes -of_objects $awg_ila]"

set run_status [catch {run_hw_ila $awg_ila} run_msg]
puts "AWG_RUN_STATUS=$run_status"
puts "AWG_RUN_MSG=$run_msg"
if {$run_status != 0} {
    error $run_msg
}

set wait_status [catch {wait_on_hw_ila $awg_ila} wait_msg]
puts "AWG_WAIT_STATUS=$wait_status"
puts "AWG_WAIT_MSG=$wait_msg"
if {$wait_status != 0} {
    error $wait_msg
}

set upload_status [catch {upload_hw_ila_data $awg_ila} data_obj]
puts "AWG_UPLOAD_STATUS=$upload_status"
puts "AWG_UPLOAD_OBJ=$data_obj"
if {$upload_status != 0} {
    error $data_obj
}

set stamp [clock format [clock seconds] -format "%Y%m%d_%H%M%S"]
set csv_file "$out_dir/awg_button_debug_$stamp.csv"
set write_status [catch {write_hw_ila_data -force -csv_file $csv_file $data_obj} write_msg]
puts "AWG_WRITE_STATUS=$write_status"
puts "AWG_WRITE_MSG=$write_msg"
puts "AWG_CSV_FILE=$csv_file"
if {$write_status != 0} {
    error $write_msg
}

puts "CAPTURE_AWG_BUTTON_DEBUG_END"
