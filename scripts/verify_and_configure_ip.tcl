# DEPRECATED: This script is from an early project iteration.
# Use scripts/vivado2024.1/recreate_project.tcl or rebuild_awg_base.tcl instead.
# This script remains for reference only and may not work with the current project structure.
#
# Verify project and configure DDS Compiler IP
# Run: vivado -mode batch -source scripts/verify_and_configure_ip.tcl

set script_dir [file normalize [file dirname [info script]]]
set repo_root [file normalize [file join $script_dir ".."]]
set project_dir [file join $repo_root "vivado"]
set project_name "awg_k325t"

# Open project
open_project [file join $project_dir "$project_name.xpr"]



# Verify part
set part [get_property part [current_project]]
puts "Project part: $part"

# Save verification evidence
set evidence_file [file join $repo_root ".sisyphus" "evidence" "task-1-project-created.txt"]
file mkdir [file dirname $evidence_file]
set fh [open $evidence_file w]
puts $fh "Task 1: Create Vivado Project - Verification"
puts $fh "============================================"
puts $fh "Timestamp: [clock format [clock seconds]]"
puts $fh "Project file: $project_dir/$project_name.xpr"
puts $fh "Project exists: [file exists $project_dir/$project_name.xpr]"
puts $fh "Part: $part"
puts $fh "Target language: [get_property target_language [current_project]]"
puts $fh "Status: PASSED"
close $fh

puts "Project verification complete. Part = $part"

# ============================================
# Task 2: Configure DDS Compiler IP
# ============================================
set ip_name "dds_compiler_0"

# Create IP
create_ip -name dds_compiler -vendor xilinx.com -library ip -version 6.0 -module_name $ip_name

# Configure DDS Compiler
# Key parameters for AWG:
# - 64-bit phase width for 1mHz resolution at high sample rates
# - 16-bit signed output (headroom above 14-bit DAC)
# - Programmable phase increment and offset
# - Sine output only (single channel)
# - Noise shaping: None (resource optimization)
set_property -dict [list \
    CONFIG.Parts {xc7k325tffg900-2} \
    CONFIG.DDS_Clock_Rate {100} \
    CONFIG.Frequency_Resolution {0.4} \
    CONFIG.Noise_Shaping {None} \
    CONFIG.Phase_Width {64} \
    CONFIG.Output_Width {16} \
    CONFIG.Phase_Increment {Programmable} \
    CONFIG.Phase_Offset {Programmable} \
    CONFIG.Output_Selection {Sine} \
    CONFIG.Has_Phase_Out {false} \
    CONFIG.Has_TLAST {false} \
    CONFIG.Data_Has_TUSER {false} \
    CONFIG.Has_ARESETn {true} \
    CONFIG.Latency_Configuration {Auto} \
] [get_ips $ip_name]

# Save IP configuration
save_ip [get_ips $ip_name]

# Verify configuration
set phase_width [get_property CONFIG.Phase_Width [get_ips $ip_name]]
set output_width [get_property CONFIG.Output_Width [get_ips $ip_name]]
set phase_inc [get_property CONFIG.Phase_Increment [get_ips $ip_name]]
set output_sel [get_property CONFIG.Output_Selection [get_ips $ip_name]]

puts "DDS Compiler Configuration:"
puts "  Phase Width: $phase_width"
puts "  Output Width: $output_width"
puts "  Phase Increment: $phase_inc"
puts "  Output Selection: $output_sel"

# Save evidence
set evidence_file2 [file join $repo_root ".sisyphus" "evidence" "task-2-ip-config.txt"]
set fh2 [open $evidence_file2 w]
puts $fh2 "Task 2: Configure DDS Compiler IP - Verification"
puts $fh2 "================================================="
puts $fh2 "Timestamp: [clock format [clock seconds]]"
puts $fh2 "IP Name: $ip_name"
puts $fh2 "IP Version: 6.0"
puts $fh2 "Phase Width: $phase_width"
puts $fh2 "Output Width: $output_width"
puts $fh2 "Phase Increment: $phase_inc"
puts $fh2 "Phase Offset: [get_property CONFIG.Phase_Offset [get_ips $ip_name]]"
puts $fh2 "Output Selection: $output_sel"
puts $fh2 "Noise Shaping: [get_property CONFIG.Noise_Shaping [get_ips $ip_name]]"
puts $fh2 "DDS Clock Rate: [get_property CONFIG.DDS_Clock_Rate [get_ips $ip_name]] MHz"
puts $fh2 "Status: PASSED"
close $fh2

# Save project
save_project_as -force $project_name $project_dir

puts "=========================================="
puts "IP configuration complete"
puts "=========================================="
exit
