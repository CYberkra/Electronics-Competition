# Board buttons used by the AD9144 AWG button variant.
set_property PACKAGE_PIN A26 [get_ports key0]
set_property IOSTANDARD LVCMOS33 [get_ports key0]

set_property PACKAGE_PIN A25 [get_ports key1]
set_property IOSTANDARD LVCMOS33 [get_ports key1]

set_property PACKAGE_PIN R24 [get_ports {led[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led[0]}]

set_property PACKAGE_PIN R23 [get_ports {led[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led[1]}]

set_false_path -from [get_ports {key0 key1}]
set_false_path -to [get_ports {led[*]}]
