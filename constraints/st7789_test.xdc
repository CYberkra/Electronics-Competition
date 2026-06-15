# ST7789 test top constraints — minimal pin set
# Board clock (100MHz differential)
set_property PACKAGE_PIN AE10 [get_ports sys_clk_p]
set_property PACKAGE_PIN AF10 [get_ports sys_clk_n]
set_property IOSTANDARD DIFF_SSTL15 [get_ports sys_clk_p]
set_property IOSTANDARD DIFF_SSTL15 [get_ports sys_clk_n]

# Reset
set_property PACKAGE_PIN AB25 [get_ports sys_rst_n]
set_property IOSTANDARD LVCMOS25 [get_ports sys_rst_n]

# ST7789 TFT (P2 CMOS/CAMERA interface)
set_property PACKAGE_PIN N27 [get_ports tft_dc]
set_property PACKAGE_PIN M24 [get_ports tft_scl]
set_property PACKAGE_PIN M27 [get_ports tft_cs]
set_property PACKAGE_PIN M25 [get_ports tft_sda]
set_property PACKAGE_PIN N29 [get_ports tft_res]
set_property PACKAGE_PIN M20 [get_ports tft_blk]
set_property IOSTANDARD LVCMOS33 [get_ports {tft_dc tft_scl tft_cs tft_sda tft_res tft_blk}]

# LED (use LED1 for test status — avoids conflict with LED0)
set_property PACKAGE_PIN R23 [get_ports test_led]
set_property IOSTANDARD LVCMOS33 [get_ports test_led]

# Clocks
create_clock -period 10.0 -name sys_clk [get_ports sys_clk_p]
set_property CONFIG_VOLTAGE 3.3 [current_design]
set_property CFGBVS VCCO [current_design]
