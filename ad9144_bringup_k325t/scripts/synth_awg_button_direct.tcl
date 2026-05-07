# Recreate the AWG button project and run synthesis inside this Vivado process.

set script_dir [file normalize [file dirname [info script]]]
set proj_root [file normalize [file join $script_dir ".."]]

source [file join $proj_root "scripts" "vivado_threads.tcl"]
source [file join $proj_root "scripts" "create_awg_button_project.tcl"]

set ips [get_ips -quiet *]
if {[llength $ips] > 0} {
    set locked_ips [get_ips -quiet -filter {IS_LOCKED == 1}]
    if {[llength $locked_ips] > 0} {
        puts "UPGRADING_LOCKED_IPS=$locked_ips"
        upgrade_ip $locked_ips
    }

    foreach xci [get_files -all -filter {FILE_TYPE == IP}] {
        catch {set_property generate_synth_checkpoint false $xci} msg
    }

    generate_target all $ips
}

update_compile_order -fileset sources_1

set out_dir [file join $proj_root "vivado_awg_button"]
file mkdir $out_dir

synth_design -top top -part xc7k325tffg900-2 -flatten_hierarchy rebuilt
write_checkpoint -force [file join $out_dir "top_awg_button_synth.dcp"]
report_utilization -file [file join $out_dir "top_awg_button_synth_util.rpt"]
report_timing_summary -file [file join $out_dir "top_awg_button_synth_timing.rpt"]

puts "SYNTH_AWG_BUTTON_DCP=[file join $out_dir "top_awg_button_synth.dcp"]"
