# Vivado Batch Simulation Script for DDS Compiler
# 自动运行行为仿真并保存波形

# 打开工程
set script_dir [file normalize [file dirname [info script]]]
set repo_root $script_dir
set project_dir [file join $repo_root "vivado"]

open_project [file join $project_dir "awg_k325t.xpr"]

# 设置顶层仿真模块
set_property top tb_dds_compiler [get_filesets sim_1]

# 运行行为仿真（不启动 GUI）
launch_simulation -mode behavioral

# 运行仿真时间
run 30us

# 保存波形数据库
save_wave_config -object [current_wave_config] [file join $project_dir "tb_dds_compiler_behav.wcfg"]

# 输出关键信号值到日志
puts "============================================"
puts "DDS Simulation Results Summary"
puts "============================================"
puts "Simulation time: 30us"
puts "Clock frequency: 100MHz"
puts ""
puts "Test stages:"
puts "  0-10us  : 1MHz sine wave"
puts "  10-20us : 2MHz sine wave"
puts "  20-25us : 0Hz DC"
puts ""
puts "Waveform saved to:"
puts "  [file join $project_dir "awg_k325t.sim" "sim_1" "behav" "xsim" "tb_dds_compiler_behav.wdb"]"
puts ""
puts "To view waveform:"
puts "  1. Open Vivado GUI"
puts "  2. File -> Open -> Open Simulation"
puts "  3. Select the .wdb file above"
puts "============================================"

# 关闭仿真
close_sim

# 关闭工程
close_project

puts "[DONE] Simulation completed successfully!"
