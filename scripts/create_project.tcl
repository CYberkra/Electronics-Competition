# Create Vivado project for AWG K325T
# Run: vivado -mode batch -source scripts/create_project.tcl

set script_dir [file normalize [file dirname [info script]]]
set repo_root [file normalize [file join $script_dir ".."]]
set project_dir [file join $repo_root "vivado"]
set project_name "awg_k325t"
set part "xc7k325tffg900-2"

# Create project
create_project $project_name $project_dir -part $part -force

# Set target language to Verilog
set_property target_language Verilog [current_project]

# Set default library
set_property default_lib xil_defaultlib [current_project]

# Save project
save_project_as -force $project_name $project_dir

puts "=========================================="
puts "Project created successfully"
puts "Name: $project_name"
puts "Directory: $project_dir"
puts "Part: $part"
puts "=========================================="
exit
