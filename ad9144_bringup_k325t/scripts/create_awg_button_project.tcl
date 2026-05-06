# Create a Vivado project for the K325T AD9144 AWG button-control variant.

set proj_root "D:/FPGA/ad9144_bringup_k325t"
set proj_dir  "$proj_root/vivado_awg_button"
set part_name "xc7k325tffg900-2"
set vendor_src "D:/FPGA/FMCADDA-9250-9144/extracted_k7_full/fmcadda_9250_9144_demo_dac4L_k7/fmcadda_9250_9144.srcs"
set variant_top "$proj_root/variants/awg_button/top.v"
set coe_src "$proj_root/ip_data/sine.coe"

if {![file exists "$vendor_src/sources_1/new/top.v"]} {
    error "Vendor source tree not found: $vendor_src"
}
if {![file exists $variant_top]} {
    error "Missing AWG button top: $variant_top"
}
if {![file exists $coe_src]} {
    error "Missing ROM initialization file: $coe_src"
}

# The imported 2018.3 blk_mem_gen_0 IP records legacy COE paths.
file copy -force $coe_src "D:/FPGA/sine.coe"
file copy -force $coe_src "D:/FPGA/FMCADDA-9250-9144/sine.coe"

create_project -force ad9144_awg_button_k325t $proj_dir -part $part_name
set_property target_language Verilog [current_project]
set_property simulator_language Verilog [current_project]

foreach src [glob "$vendor_src/sources_1/new/*.v"] {
    if {[file tail $src] ne "top.v"} {
        add_files -fileset sources_1 $src
    }
}
add_files -fileset sources_1 $variant_top
add_files -fileset constrs_1 "$proj_root/constraints/top_k325t_fmc.xdc"
add_files -fileset constrs_1 "$proj_root/constraints/awg_button_k325t.xdc"

set ip_files [list \
    "$vendor_src/sources_1/ip/blk_mem_gen_0/blk_mem_gen_0.xci" \
    "$vendor_src/sources_1/ip/clk_for_glbclk/clk_for_glbclk.xci" \
    "$vendor_src/sources_1/ip/clk_sys_mmcm/clk_sys_mmcm.xci" \
    "$vendor_src/sources_1/ip/fifo_for_adc_data/fifo_for_adc_data.xci" \
    "$vendor_src/sources_1/ip/ila_for_adc_data/ila_for_adc_data.xci" \
    "$vendor_src/sources_1/ip/jesd204_phy_0/jesd204_phy_0.xci" \
    "$vendor_src/sources_1/ip/jesd204_rx/jesd204_rx.xci" \
    "$vendor_src/sources_1/ip/jesd204_tx/jesd204_tx.xci" \
    "$vendor_src/sources_1/ip/my_ila_jesd/my_ila_jesd.xci" \
    "$vendor_src/sources_1/ip/vio_for_jesd_rst/vio_for_jesd_rst.xci" \
]

foreach ip_file $ip_files {
    if {![file exists $ip_file]} {
        error "Missing IP file: $ip_file"
    }
    import_ip -files $ip_file
}

set_property top top [get_filesets sources_1]
update_compile_order -fileset sources_1
report_ip_status -name ip_status_initial

puts "PROJECT_CREATED=$proj_dir/ad9144_awg_button_k325t.xpr"
