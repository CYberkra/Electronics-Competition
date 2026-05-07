# Create a Vivado project for the K325T AD9144 AWG UART-control variant.

set script_dir [file normalize [file dirname [info script]]]
set proj_root [file normalize [file join $script_dir ".."]]
set proj_dir "$proj_root/vivado_awg_uart"
set project_name "ad9144_awg_uart_k325t"
set verilog_defines [list AWG_UART_CONTROL]
set extra_constraints [list "$proj_root/constraints/awg_uart_k325t.xdc"]

source [file join $proj_root "scripts" "create_awg_button_project.tcl"]
