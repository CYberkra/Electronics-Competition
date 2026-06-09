# Shared Vivado runtime settings for the K325T AWG scripts.
#
# Override from PowerShell when needed:
#   $env:AWG_VIVADO_MAX_THREADS = "4"

if {[info exists ::env(AWG_VIVADO_MAX_THREADS)]} {
    set ::AWG_VIVADO_THREADS $::env(AWG_VIVADO_MAX_THREADS)
} else {
    set ::AWG_VIVADO_THREADS 8
}

if {![string is integer -strict $::AWG_VIVADO_THREADS]} {
    set ::AWG_VIVADO_THREADS 8
}
if {$::AWG_VIVADO_THREADS < 1} {
    set ::AWG_VIVADO_THREADS 1
}
if {$::AWG_VIVADO_THREADS > 8} {
    set ::AWG_VIVADO_THREADS 8
}

set ::AWG_VIVADO_JOBS $::AWG_VIVADO_THREADS
set_param general.maxThreads $::AWG_VIVADO_THREADS

puts "AWG_VIVADO_MAX_THREADS=$::AWG_VIVADO_THREADS"
puts "AWG_VIVADO_JOBS=$::AWG_VIVADO_JOBS"
puts "VIVADO_GENERAL_MAXTHREADS=[get_param general.maxThreads]"
