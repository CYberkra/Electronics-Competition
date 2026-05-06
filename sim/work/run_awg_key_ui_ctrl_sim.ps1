# Run standalone behavioral simulation for AWG key UI control

$ErrorActionPreference = "Stop"

$vivado_bin = "D:\vivado\Vivado\2024.1\bin"
$rtl_ctrl = "D:\awg_fpga\rtl\control"
$tb_dir = "D:\awg_fpga\sim\tb"
$work_dir = "D:\awg_fpga\sim\work\awg_key_ui_ctrl"

New-Item -ItemType Directory -Path $work_dir -Force | Out-Null
Set-Location $work_dir
Set-Content -Path "xsim_run.tcl" -Value "run all"

Write-Host "========================================"
Write-Host "Step 1: Clean previous artifacts"
Write-Host "========================================"
Remove-Item *.log, *.pb, *.jou, *.wdb, xsim.dir -Recurse -ErrorAction SilentlyContinue

Write-Host ""
Write-Host "========================================"
Write-Host "Step 2: Compile RTL sources"
Write-Host "========================================"

& $vivado_bin\xvlog.bat -sv "$rtl_ctrl\awg_key_ui_ctrl.v"
if ($LASTEXITCODE -ne 0) { exit 1 }

Write-Host ""
Write-Host "========================================"
Write-Host "Step 3: Compile testbench"
Write-Host "========================================"
& $vivado_bin\xvlog.bat -sv "$tb_dir\tb_awg_key_ui_ctrl.v"
if ($LASTEXITCODE -ne 0) { exit 1 }

Write-Host ""
Write-Host "========================================"
Write-Host "Step 4: Elaborate"
Write-Host "========================================"
& $vivado_bin\xelab.bat tb_awg_key_ui_ctrl -s top_sim
if ($LASTEXITCODE -ne 0) { exit 1 }

Write-Host ""
Write-Host "========================================"
Write-Host "Step 5: Run simulation"
Write-Host "========================================"
& $vivado_bin\xsim.bat top_sim -tclbatch "xsim_run.tcl"
if ($LASTEXITCODE -ne 0) { exit 1 }

Write-Host ""
Write-Host "========================================"
Write-Host "Simulation completed"
Write-Host "========================================"
