# Create a Vivado project for the K325T AD9144 AWG button-control variant.
# The vendor_src path points to external vendor demo sources (not in this repo).
# Override it by setting the VENDOR_SRC environment variable before running.

set script_dir [file normalize [file dirname [info script]]]
set proj_root [file normalize [file join $script_dir ".."]]

if {![info exists proj_dir]} {
    set proj_dir  "$proj_root/vivado_awg_button"
}
if {![info exists project_name]} {
    set project_name "ad9144_awg_button_k325t"
}
if {![info exists part_name]} {
    set part_name "xc7k325tffg900-2"
}
if {![info exists vendor_src]} {
    # Allow override via environment variable VENDOR_SRC
    if {[info exists ::env(VENDOR_SRC)]} {
        set vendor_src $::env(VENDOR_SRC)
    } else {
        # Default: assume vendor sources are at a sibling directory named FMCADDA-9250-9144
        set vendor_src [file normalize [file join $proj_root ".." "FMCADDA-9250-9144" "extracted_k7_full" "fmcadda_9250_9144_demo_dac4L_k7" "fmcadda_9250_9144.srcs"]]
    }
}
if {![info exists variant_top]} {
    set variant_top "$proj_root/variants/awg_button/top.v"
}
if {![info exists coe_src]} {
    set coe_src "$proj_root/ip_data/sine.coe"
}
if {![info exists extra_constraints]} {
    set extra_constraints [list]
}
if {![info exists verilog_defines]} {
    set verilog_defines [list]
}

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
# Copy to well-known locations the IP expects.
set coe_copy_dir [file normalize [file join $proj_root ".." ".."]]
file copy -force $coe_src [file join $coe_copy_dir "sine.coe"]
file copy -force $coe_src [file join $coe_copy_dir "FMCADDA-9250-9144" "sine.coe"]

create_project -force $project_name $proj_dir -part $part_name
set_property target_language Verilog [current_project]
set_property simulator_language Verilog [current_project]
if {[llength $verilog_defines] > 0} {
    set_property verilog_define $verilog_defines [get_filesets sources_1]
}

foreach src [glob "$vendor_src/sources_1/new/*.v"] {
    if {[file tail $src] ne "top.v"} {
        add_files -fileset sources_1 $src
    }
}
foreach src [glob "$proj_root/rtl/awg/*.v"] {
    add_files -fileset sources_1 $src
}
add_files -fileset sources_1 $variant_top
add_files -fileset constrs_1 "$proj_root/constraints/top_k325t_fmc.xdc"
add_files -fileset constrs_1 "$proj_root/constraints/awg_button_k325t.xdc"
foreach extra_xdc $extra_constraints {
    if {![file exists $extra_xdc]} {
        error "Missing extra constraint file: $extra_xdc"
    }
    add_files -fileset constrs_1 $extra_xdc
}

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

puts "PROJECT_CREATED=$proj_dir/$project_name.xpr"
