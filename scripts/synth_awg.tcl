# Synthesize the unified AWG design
cd "D:/projects/GPR/Electronics-Competition"
open_project vivado/awg_k325t.xpr
set_property source_mgmt_mode None [current_project]

# Set top module
set_property top awg_top [current_fileset]

# Check what runs exist
puts "Runs: [get_runs]"
puts "Top: [get_property top [current_fileset]]"

# Identify IPs that need synthesis runs
set all_xcis [get_files *.xci]
puts "IP files: [llength $all_xcis]"

# Delete stale dds_compiler_0 run if it doesn't exist
catch {reset_run dds_compiler_0_synth_1}

# Generate targets for each top-level IP individually
foreach xci $all_xcis {
    set ip_name [file rootname [file tail $xci]]
    # Skip nested IPs (containing "ip_0" or "ip_1" in path)
    if {[regexp {/ip_\d+/} $xci]} {
        puts "  SKIP nested: $ip_name"
        continue
    }
    puts "  Generate: $ip_name"
    catch {generate_target all [list $xci] -force} result
    puts "    Result: $result"
}

# Now check IP synthesis runs
foreach xci $all_xcis {
    if {[regexp {/ip_\d+/} $xci]} { continue }
    set ip_name [file rootname [file tail $xci]]
    set run_name "${ip_name}_synth_1"
    if {[lsearch [get_runs] $run_name] < 0} {
        puts "  Creating run: $run_name"
        catch {create_run -name $run_name -parent_run synth_1 -flow "Vivado Synthesis 2024" [list $xci]}
    }
}

update_compile_order -fileset sources_1

# Reset synth_1
reset_run synth_1

# Launch synthesis
puts "Launching synth_1..."
launch_runs synth_1 -jobs 4
wait_on_run synth_1

# Check results
set synth_status [get_property PROGRESS [get_runs synth_1]]
puts "Synthesis status: $synth_status"

if {$synth_status eq "100%"} {
    open_run synth_1 -name synth_1
    puts "SYNTHESIS PASSED"
} else {
    puts "SYNTHESIS FAILED"
    puts "Last 30 lines of synth_1 runme.log:"
    set log_file "D:/projects/GPR/Electronics-Competition/vivado/awg_k325t.runs/synth_1/runme.log"
    if {[file exists $log_file]} {
        set fp [open $log_file r]
        set content [read $fp]
        close $fp
        set lines [split $content "\n"]
        set start [expr {[llength $lines] - 30}]
        if {$start < 0} {set start 0}
        foreach line [lrange $lines $start end] { puts $line }
    }
    # Also check child runs for failures
    foreach r [get_runs] {
        if {[get_property PROGRESS $r] ne "100%" && $r ne "synth_1"} {
            set rl "$r/runme.log"
            set rp "D:/projects/GPR/Electronics-Competition/vivado/awg_k325t.runs/$rl"
            if {[file exists $rp]} {
                puts "--- $r last 20 lines ---"
                set fp [open $rp r]
                set content [read $fp]
                close $fp
                set lines [split $content "\n"]
                set start [expr {[llength $lines] - 20}]
                if {$start < 0} {set start 0}
                foreach line [lrange $lines $start end] { puts $line }
            }
        }
    }
}

exit
