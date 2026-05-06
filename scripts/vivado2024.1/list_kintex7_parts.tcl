set parts [get_parts -filter {FAMILY == "kintex7"}]
puts "Kintex-7 parts available: [llength $parts]"
foreach p $parts {
    puts "  [get_property NAME $p]"
}
