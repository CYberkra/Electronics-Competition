# Rebuild AWG debug project with conditional ILA enabled.
# Output:
#   {repo_root}/vivado/awg_k325t.runs/impl_1/awg_dds_led_top_debug.bit
#   {repo_root}/vivado/awg_k325t.runs/impl_1/awg_dds_led_top_debug.ltx

set script_dir [file normalize [file dirname [info script]]]
set repo_root [file normalize [file join $script_dir ".."]]
set proj_dir [file join $repo_root "vivado"]
set proj_name "awg_k325t"
set ip_dir [file join $proj_dir "$proj_name.srcs" sources_1 ip]
set ila_name "ila_awg_debug"
set artifact_dir [file join $repo_root "artifacts" "debug"]

source [file join $repo_root "scripts" "vivado_threads.tcl"]

open_project [file join $proj_dir "$proj_name.xpr"]

proc ensure_source {path} {
    if {[llength [get_files -quiet $path]] == 0} {
        add_files -fileset sources_1 $path
    }
}

ensure_source [file join $repo_root "rtl" "sweep" "sweep_engine.v"]
ensure_source [file join $repo_root "rtl" "wave" "bram_wave_player.v"]

set_property top awg_dds_led_top [get_filesets sources_1]
set_property verilog_define {AWG_DEBUG_ILA} [get_filesets sources_1]

if {[llength [get_ips -quiet $ila_name]] == 0} {
    puts "Creating $ila_name..."
    file mkdir $ip_dir
    create_ip -name ila -vendor xilinx.com -library ip -module_name $ila_name -dir $ip_dir
} else {
    puts "Using existing $ila_name..."
}

set ila_ip [get_ips $ila_name]
set ila_xci [get_files -quiet [file join $ip_dir $ila_name "$ila_name.xci"]]
if {[llength $ila_xci] == 0} {
    puts "[ERROR] Could not locate $ila_name.xci"
    set_property verilog_define {} [get_filesets sources_1]
    close_project
    exit 1
}

set_property -dict [list \
    CONFIG.C_DATA_DEPTH {2048} \
    CONFIG.C_NUM_OF_PROBES {13} \
    CONFIG.C_PROBE0_WIDTH {1} \
    CONFIG.C_PROBE1_WIDTH {1} \
    CONFIG.C_PROBE2_WIDTH {1} \
    CONFIG.C_PROBE3_WIDTH {2} \
    CONFIG.C_PROBE4_WIDTH {3} \
    CONFIG.C_PROBE5_WIDTH {1} \
    CONFIG.C_PROBE6_WIDTH {48} \
    CONFIG.C_PROBE7_WIDTH {16} \
    CONFIG.C_PROBE8_WIDTH {16} \
    CONFIG.C_PROBE9_WIDTH {16} \
    CONFIG.C_PROBE10_WIDTH {1} \
    CONFIG.C_PROBE11_WIDTH {8} \
    CONFIG.C_PROBE12_WIDTH {2} \
] $ila_ip

generate_target all $ila_xci
export_ip_user_files -of_objects $ila_xci -no_script -sync -force -quiet
update_compile_order -fileset sources_1

puts "========================================"
puts "Starting debug synthesis..."
puts "========================================"
reset_run synth_1
launch_runs synth_1 -jobs $::AWG_VIVADO_JOBS
wait_on_run synth_1

set synth_status [get_property STATUS [get_runs synth_1]]
puts "Synthesis status: $synth_status"
if {[string match "*ERROR*" $synth_status] || [string match "*FAIL*" $synth_status]} {
    puts "[ERROR] Debug synthesis failed"
    set_property verilog_define {} [get_filesets sources_1]
    close_project
    exit 1
}

puts "========================================"
puts "Starting debug implementation + bitstream..."
puts "========================================"
reset_run impl_1
launch_runs impl_1 -to_step write_bitstream -jobs $::AWG_VIVADO_JOBS
wait_on_run impl_1

set impl_status [get_property STATUS [get_runs impl_1]]
puts "Implementation status: $impl_status"
if {[string match "*ERROR*" $impl_status] || [string match "*FAIL*" $impl_status]} {
    puts "[ERROR] Debug implementation failed"
    set_property verilog_define {} [get_filesets sources_1]
    close_project
    exit 1
}

set impl_dir [file join $proj_dir "${proj_name}.runs" impl_1]
set bit_file [file join $impl_dir "awg_dds_led_top.bit"]
set ltx_file [file join $impl_dir "awg_dds_led_top.ltx"]
set debug_bit [file join $impl_dir "awg_dds_led_top_debug.bit"]
set debug_ltx [file join $impl_dir "awg_dds_led_top_debug.ltx"]
set artifact_bit [file join $artifact_dir "awg_dds_led_top_debug.bit"]
set artifact_ltx [file join $artifact_dir "awg_dds_led_top_debug.ltx"]

file mkdir $artifact_dir

if {[file exists $bit_file]} {
    file copy -force $bit_file $debug_bit
    file copy -force $bit_file $artifact_bit
}
if {[file exists $ltx_file]} {
    file copy -force $ltx_file $debug_ltx
    file copy -force $ltx_file $artifact_ltx
}

puts "========================================"
puts "SUCCESS: Debug bitstream generated"
puts "  debug bit: $debug_bit"
puts "  debug ltx: $debug_ltx"
puts "  stable debug bit: $artifact_bit"
puts "  stable debug ltx: $artifact_ltx"
puts "========================================"

set_property verilog_define {} [get_filesets sources_1]
close_project
exit 0
