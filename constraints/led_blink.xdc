# Minimal LED blink test constraints
set_property PACKAGE_PIN AE10 [get_ports sys_clk_p]
set_property PACKAGE_PIN AF10 [get_ports sys_clk_n]
set_property IOSTANDARD DIFF_SSTL15 [get_ports {sys_clk_p sys_clk_n}]
create_clock -period 10.0 -name sys_clk [get_ports sys_clk_p]

set_property PACKAGE_PIN AB25 [get_ports sys_rst_n]
set_property IOSTANDARD LVCMOS25 [get_ports sys_rst_n]

set_property PACKAGE_PIN R24 [get_ports led0]
set_property PACKAGE_PIN R23 [get_ports led1]
set_property IOSTANDARD LVCMOS33 [get_ports {led0 led1}]

set_property CONFIG_VOLTAGE 3.3 [current_design]
set_property CFGBVS VCCO [current_design]
