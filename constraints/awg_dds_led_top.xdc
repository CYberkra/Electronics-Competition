# AWG DDS LED Demo - K325T Pin Constraints
# Target: xc7k325tffg900-2

# Differential 100MHz clock
set_property PACKAGE_PIN AE10 [get_ports sys_clk_p]
set_property IOSTANDARD DIFF_SSTL15_DCI [get_ports sys_clk_p]
set_property PACKAGE_PIN AF10 [get_ports sys_clk_n]
set_property IOSTANDARD DIFF_SSTL15_DCI [get_ports sys_clk_n]

# Active-low reset (KEY0 on board)
set_property PACKAGE_PIN AB25 [get_ports sys_rst_n]
set_property IOSTANDARD LVCMOS33 [get_ports sys_rst_n]

# Keys (frequency control)
set_property PACKAGE_PIN A26 [get_ports key0]
set_property IOSTANDARD LVCMOS33 [get_ports key0]
set_property PACKAGE_PIN A25 [get_ports key1]
set_property IOSTANDARD LVCMOS33 [get_ports key1]

# LEDs (only 2 available on K325T core board)
set_property PACKAGE_PIN R24 [get_ports {led[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led[0]}]
set_property PACKAGE_PIN R23 [get_ports {led[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led[1]}]

# Teaching DAC interface (3PD9708E / ATK-HS-ADDA)
set_property PACKAGE_PIN AH22 [get_ports da_clk]
set_property IOSTANDARD LVCMOS33 [get_ports da_clk]

set_property PACKAGE_PIN AB22 [get_ports {da_data[7]}]
set_property PACKAGE_PIN AG20 [get_ports {da_data[6]}]
set_property PACKAGE_PIN AB23 [get_ports {da_data[5]}]
set_property PACKAGE_PIN AH20 [get_ports {da_data[4]}]
set_property PACKAGE_PIN AC22 [get_ports {da_data[3]}]
set_property PACKAGE_PIN AH21 [get_ports {da_data[2]}]
set_property PACKAGE_PIN AD22 [get_ports {da_data[1]}]
set_property PACKAGE_PIN AJ21 [get_ports {da_data[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {da_data[*]}]

# Create clock constraint
create_clock -period 10.000 -name sys_clk [get_ports sys_clk_p]

# False path for LED outputs (not timing critical)
set_false_path -to [get_ports {led[*]}]
set_false_path -to [get_ports {da_data[*]}]
set_false_path -to [get_ports da_clk]
