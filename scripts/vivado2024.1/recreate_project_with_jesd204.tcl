# ============================================================================
# Recreate AWG project + JESD204 IP for Vivado 2024.1
# ============================================================================

set project_name "awg_k325t"
set project_dir  "D:/awg_fpga/vivado"
set part         "xc7k325tffg900-2"
set ip_name      "jesd204_tx_ad9144"
set ip_dir       "D:/awg_fpga/vivado/awg_k325t.srcs/sources_1/ip"

puts "========================================"
puts "  Creating fresh Vivado 2024.1 project"
puts "========================================"

# Step 1: Clean ALL old files (including srcs)
foreach f [list \
    "$project_dir/${project_name}.xpr" \
    "$project_dir/${project_name}.cache" \
    "$project_dir/${project_name}.runs" \
    "$project_dir/${project_name}.sim" \
    "$project_dir/${project_name}.gen" \
    "$project_dir/${project_name}.hw" \
    "$project_dir/${project_name}.ip_user_files" \
    "$project_dir/${project_name}.srcs" \
] {
    if {[file exists $f]} { file delete -force $f; puts "  Deleted: $f" }
}

# Step 2: Create project
create_project $project_name $project_dir -part $part -force
puts "  Project created"

# Step 3: Add RTL
add_files -fileset sources_1 [list \
    "D:/awg_fpga/rtl/top/awg_dds_led_top.v" \
    "D:/awg_fpga/rtl/dds/dds_compiler_wrapper.v" \
    "D:/awg_fpga/rtl/dds/dds_nco.v" \
    "D:/awg_fpga/rtl/dds/sine_lut.v" \
    "D:/awg_fpga/rtl/dds/wave_shape_gen.v" \
    "D:/awg_fpga/rtl/dsp/sample_mux.v" \
    "D:/awg_fpga/rtl/dsp/amp_offset_scale.v" \
    "D:/awg_fpga/rtl/dsp/awg_core.v" \
    "D:/awg_fpga/rtl/control/awg_key_ui_ctrl.v" \
    "D:/awg_fpga/rtl/dac/dac_edu_parallel_if.v" \
]
puts "  RTL added"

# Step 4: Create DDS Compiler IP
puts "  Creating DDS Compiler IP..."
file mkdir "$project_dir/$project_name.srcs/sources_1/ip"
create_ip -name dds_compiler -vendor xilinx.com -library ip -version 6.0 \
    -module_name dds_compiler_0 -dir "$project_dir/$project_name.srcs/sources_1/ip"
set_property -dict [list \
    CONFIG.PartsPresent {Phase_Generator_and_SIN_COS_LUT} \
    CONFIG.Phase_Width {48} \
    CONFIG.Output_Width {16} \
    CONFIG.Has_Phase_Out {false} \
    CONFIG.Noise_Shaping {None} \
    CONFIG.Phase_Increment {Programmable} \
    CONFIG.DDS_Clock_Rate {100} \
] [get_ips dds_compiler_0]
generate_target all [get_ips dds_compiler_0]
puts "  DDS IP done"

# Step 5: Add constraints
add_files -fileset constrs_1 "D:/awg_fpga/constraints/awg_dds_led_top.xdc"
puts "  Constraints added"

# Step 6: Set top
set_property source_mgmt_mode None [current_project]
set_property top awg_dds_led_top [get_filesets sources_1]
update_compile_order -fileset sources_1
puts "  Top set"

# Step 7: Create JESD204 TX IP
puts "  Creating JESD204 TX IP..."
create_ip -name jesd204 -vendor xilinx.com -library ip -version 7.2 \
    -module_name $ip_name -dir $ip_dir
set_property -dict [list \
    CONFIG.C_LANES                    {4} \
    CONFIG.GT_Line_Rate               {10.0} \
    CONFIG.GT_REFCLK_FREQ             {125.000} \
    CONFIG.C_NODE_IS_TRANSMIT         {1} \
    CONFIG.C_DEFAULT_SYSREF_REQUIRED  {1} \
    CONFIG.C_DEFAULT_F                {1} \
    CONFIG.C_DEFAULT_SCR              {1} \
    CONFIG.Transceiver                {GTXE2} \
] [get_ips $ip_name]
generate_target all [get_files -of_objects [get_ips $ip_name]]
puts "  JESD204 IP done"

# Step 8: Close
close_project
puts ""
puts "========================================"
puts "  Project + JESD204 IP done!"
puts "========================================"
