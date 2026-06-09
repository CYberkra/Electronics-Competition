# Update Vivado project for AWG integration
# Run: vivado -mode tcl -source scripts/update_project.tcl
# Or paste into Vivado Tcl Console

set proj_dir "D:/projects/GPR/Electronics-Competition/vivado"
set proj_file "$proj_dir/awg_k325t.xpr"
set rtl_root "D:/projects/GPR/Electronics-Competition/rtl"
set ip_root "D:/projects/GPR/Electronics-Competition/ip"
set constr_root "D:/projects/GPR/Electronics-Competition/constraints"

# Open project
open_project $proj_file

# ===== Step 1: Change top module =====
set_property top awg_top [current_fileset]
puts "Top module set to awg_top"

# ===== Step 2: Remove old constraint file =====
remove_files -fileset constrs_1 [get_files */fmc_adda.xdc]
puts "Removed old fmc_adda.xdc constraint"

# ===== Step 3: Add new constraint file =====
add_files -fileset constrs_1 -norecurse "$constr_root/awg_k325t.xdc"
set_property PROCESSING_ORDER NORMAL [get_files awg_k325t.xdc]
puts "Added awg_k325t.xdc"

# ===== Step 4: Remove old SPI duplicates =====
remove_files -fileset sources_1 [get_files */ad9144_spi_ctrl.v]
remove_files -fileset sources_1 [get_files */lmk04828_spi_ctrl.v]
remove_files -fileset sources_1 [get_files */awg_fmc_adda_top.v]
remove_files -fileset sources_1 [get_files */fmc/top.v]
puts "Removed old SPI duplicates and obsolete tops"

# ===== Step 5: Remove rtl/fmc/ JESD support modules (will re-add from rtl/jesd/) =====
# First remove the old paths
foreach f [get_files -filter {FILE_TYPE == "Verilog" && NAME =~ *fmc/*}] {
    remove_files -fileset sources_1 $f
}
puts "Removed rtl/fmc/ files"

# ===== Step 6: Add new RTL files =====
# Add all jesd/ support modules
set jesd_files [glob -nocomplain "$rtl_root/jesd/*.v"]
foreach f $jesd_files {
    add_files -fileset sources_1 -norecurse $f
    puts "  Added: $f"
}

# Add the new top
add_files -fileset sources_1 -norecurse "$rtl_root/top/awg_top.v"
puts "  Added: rtl/top/awg_top.v"

# ===== Step 7: Import bringup IPs =====
set vendor_src "D:/projects/GPR/Electronics-Competition/ad9144_bringup_k325t/vendor_src/fmcadda_9250_9144.srcs"

# Remove old jesd204_tx_ad9144 IP
remove_files -fileset sources_1 [get_files */jesd204_tx_ad9144.xci]
puts "Removed old jesd204_tx_ad9144 IP"

# Import JESD IPs from bringup
set ip_files [list \
    "$vendor_src/sources_1/ip/jesd204_phy_0/jesd204_phy_0.xci" \
    "$vendor_src/sources_1/ip/jesd204_tx/jesd204_tx.xci" \
    "$vendor_src/sources_1/ip/jesd204_rx/jesd204_rx.xci" \
    "$vendor_src/sources_1/ip/clk_for_glbclk/clk_for_glbclk.xci" \
    "$vendor_src/sources_1/ip/clk_sys_mmcm/clk_sys_mmcm.xci" \
    "$vendor_src/sources_1/ip/blk_mem_gen_0/blk_mem_gen_0.xci" \
    "$vendor_src/sources_1/ip/vio_for_jesd_rst/vio_for_jesd_rst.xci" \
    "$vendor_src/sources_1/ip/my_ila_jesd/my_ila_jesd.xci" \
]

foreach ip_file $ip_files {
    if {[file exists $ip_file]} {
        import_ip -files $ip_file
        puts "  Imported: [file tail [file dirname $ip_file]]"
    } else {
        puts "  WARNING: Missing IP: $ip_file"
    }
}

# ===== Step 8: Copy COE for IP compatibility =====
file copy -force "$rtl_root/dds/sine.coe" "D:/projects/GPR/Electronics-Competition/../sine.coe"

# ===== Step 9: Update compile order =====
update_compile_order -fileset sources_1
update_compile_order -fileset sim_1
puts "Updated compile order"

# ===== Step 10: Save =====
save_project -force
puts "Project saved"

puts "========================================="
puts "UPDATE COMPLETE"
puts "Next steps:"
puts "  1. Close and re-open the project"
puts "  2. Run 'upgrade_ip [get_ips *]'"
puts "  3. Run 'generate_target all [get_files *.xci]'"
puts "  4. Run synthesis"
puts "========================================="
exit
