set_param general.maxThreads 16
# Quick rebuild: setup sources, synthesize, implement, generate bitstream
# Usage: vivado -mode batch -source scripts/fix_synth.tcl
cd "D:/FPGA/awg_k325t"
open_project vivado/awg_k325t.xpr

set_property source_mgmt_mode All [current_project]
set_property top awg_top [current_fileset]

# Enable UART control (115200 8N1 register bridge)
set_property verilog_define {AWG_UART_CONTROL=1} [current_fileset]

# Add any missing source files
foreach f [glob -nocomplain {rtl/**/*.v} {rtl/**/*.sv}] {
    if {[get_files -quiet -of [get_filesets sources_1] -filter "NAME == \"$f\""] eq ""} {
        add_files -norecurse -fileset [get_filesets sources_1] $f
    }
}
foreach f [glob -nocomplain {constraints/*.xdc}] {
    if {[get_files -quiet -of [get_filesets constrs_1] -filter "NAME == \"$f\""] eq ""} {
        add_files -norecurse -fileset [get_filesets constrs_1] $f
    }
}
foreach ip_dir [lsort [glob -nocomplain {vivado/awg_k325t.srcs/sources_1/ip/*}]] {
    set xci [file join $ip_dir "[file tail $ip_dir].xci"]
    if {[file exists $xci] && [get_files -quiet -filter "NAME == \"$xci\""] eq ""} {
        add_files -norecurse $xci
    }
}

# Regenerate IP targets
foreach xci [get_files *.xci] {
    if {![regexp {/ip_\d+/} [get_property NAME $xci]]} {
        generate_target all [list $xci] -force
    }
}

# Build
puts "\n=== Synth ===" ; catch {reset_run synth_1}
launch_runs synth_1 -jobs 8; wait_on_run synth_1
puts "Synth: [get_property PROGRESS [get_runs synth_1]]"

launch_runs impl_1 -jobs 12 -to_step write_bitstream; wait_on_run impl_1
puts "Impl: [get_property PROGRESS [get_runs impl_1]]"

if {[get_property PROGRESS [get_runs impl_1]] eq "100%"} {
    puts "BITSTREAM READY"
} else {
    puts "=== ERRORS ==="
    foreach logf {vivado/awg_k325t.runs/synth_1/runme.log vivado/awg_k325t.runs/impl_1/runme.log} {
        if {[file exists $logf]} { set fp [open $logf r]; puts [read $fp]; close $fp }
    }
}
exit
