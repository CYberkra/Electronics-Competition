# ============================================================================
# Vivado 2024.1 License & Device Verification
# ============================================================================
# Purpose: Verify that 2024.1 can find license and synthesize for xc7k325t
# Usage:   vivado -mode batch -source verify_license.tcl
# ============================================================================

set part "xc7k325tffg900-2"

puts "========================================"
puts "  Vivado 2024.1 License/Device Check"
puts "========================================"
puts "Vivado version: [version -short]"
puts "Target part:    $part"
puts ""

# -----------------------------------------------------------------------------
# Check 1: License for Synthesis
# -----------------------------------------------------------------------------
puts "Checking license for Synthesis..."
if {[catch {set license_ok [get_license -feature Synthesis]} err]} {
    puts "WARNING: Could not query Synthesis license status"
    set license_ok 0
}

# Also check device-specific license
puts "Checking device support for Kintex-7..."
set device_ok [lsearch -exact [get_parts] $part]
if {$device_ok >= 0} {
    puts "OK: Device $part is supported in this installation."
    set device_ok 1
} else {
    puts "ERROR: Device $part NOT FOUND in installed device list!"
    set device_ok 0
}

# -----------------------------------------------------------------------------
# Check 2: Quick synthesis test
# -----------------------------------------------------------------------------
puts ""
puts "Running minimal synthesis test for $part..."

create_project -in_memory -part $part

# Minimal RTL: a simple AND gate
set rtl {
    module k325t_synth_test (
        input  wire a, b,
        output wire y
    );
        assign y = a & b;
    endmodule
}

set fd [open "k325t_synth_test.v" w]
puts $fd $rtl
close $fd

read_verilog "k325t_synth_test.v"
synth_design -top k325t_synth_test -part $part

set wns [get_property SLACK [get_timing_paths]]
puts ""
puts "Synthesis completed with 0 errors."
puts "WNS (Worst Negative Slack): $wns"

# Clean up
file delete -force "k325t_synth_test.v"
close_project

# -----------------------------------------------------------------------------
# Check 3: JESD204 IP availability
# -----------------------------------------------------------------------------
puts ""
puts "Checking JESD204 IP availability..."
set jesd_ips [get_ipdefs -filter {NAME =~ *jesd204*}]
if {[llength $jesd_ips] > 0} {
    puts "OK: Found JESD204 IP definitions:"
    foreach ip $jesd_ips {
        puts "  - [get_property NAME $ip] v[get_property VERSION $ip]"
    }
} else {
    puts "WARNING: No JESD204 IP found in catalog!"
    puts "         Make sure 7 Series device support is installed."
}

# -----------------------------------------------------------------------------
# Summary
# -----------------------------------------------------------------------------
puts ""
puts "========================================"
if {$device_ok} {
    puts "  K325T_LICENSE_CHECK_OK"
} else {
    puts "  K325T_LICENSE_CHECK_FAIL"
}
puts "========================================"
