# Generate all IP output products for unified AWG design
cd "D:/projects/GPR/Electronics-Competition"
open_project vivado/awg_k325t.xpr
set_property source_mgmt_mode None [current_project]
set_property top awg_top [current_fileset]

# Get all non-nested XCI files (skip */ip_0/* and */ip_1/*)
set xci_files [get_files *.xci]
puts "Total XCIs: [llength $xci_files]"

foreach xci $xci_files {
    set fpath [string map {\\ /} $xci]
    # Skip nested IPs deeper than one level
    if {[regexp {/ip_\d+/} $fpath]} {
        set ip_name [file rootname [file tail $xci]]
        puts "  SKIP nested: $ip_name"
        continue
    }
    set ip_name [file rootname [file tail $xci]]
    puts "  Processing: $ip_name"

    # Create synthesis run if needed
    set run_name "${ip_name}_synth_1"
    if {[lsearch [get_runs] $run_name] < 0} {
        catch {create_run -name $run_name -parent_run synth_1 -flow "Vivado Synthesis 2024" [list $xci]}
        puts "    Created run: $run_name"
    }

    # Generate targets - catch errors for nested IP issues
    set result [catch {generate_target all [list $xci] -force} msg]
    if {$result != 0} {
        puts "    generate_target warning: $msg"
        # Try just synthesis target
        catch {synth_ip [list $xci]} msg2
        if {$msg2 ne ""} {
            puts "    synth_ip result: $msg2"
        }
    } else {
        puts "    Targets generated OK"
    }
}

update_compile_order -fileset sources_1
puts "All IPs ready."

# Now synth the new IP runs
set ip_runs [list]
foreach xci $xci_files {
    set fpath [string map {\\ /} $xci]
    if {[regexp {/ip_\d+/} $fpath]} { continue }
    set ip_name [file rootname [file tail $xci]]
    set run_name "${ip_name}_synth_1"
    if {[lsearch [get_runs] $run_name] >= 0} {
        lappend ip_runs $run_name
    }
}

if {[llength $ip_runs] > 0} {
    puts "Launching IP synthesis: [join $ip_runs {, }]"
    foreach run $ip_runs { catch {reset_run $run} }
    launch_runs $ip_runs -jobs 4
    wait_on_runs $ip_runs
    puts "IP synthesis complete"
}

exit
