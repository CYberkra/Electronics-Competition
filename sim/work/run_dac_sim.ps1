# Run standalone behavioral simulation for dac_edu_parallel_if
# No Vivado project required; pure Verilog compilation

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Split-Path (Split-Path $scriptDir -Parent) -Parent

$vivado_bin = "D:\vivado\Vivado\2024.1\bin"
$rtl_dir = Join-Path $repoRoot "rtl" "dac"
$tb_dir = Join-Path $repoRoot "sim" "tb"
$work_dir = $scriptDir

# Ensure work directory exists
New-Item -ItemType Directory -Path $work_dir -Force | Out-Null
Set-Location $work_dir

Write-Host "========================================"
Write-Host "Step 1: Clean previous artifacts"
Write-Host "========================================"
Remove-Item *.log, *.pb, *.jou, *.wdb, xsim.dir -Recurse -ErrorAction SilentlyContinue

Write-Host ""
Write-Host "========================================"
Write-Host "Step 2: Compile RTL source"
Write-Host "========================================"
& $vivado_bin\xvlog.bat -sv "$rtl_dir\dac_edu_parallel_if.v"
if ($LASTEXITCODE -ne 0) { Write-Host "[ERROR] xvlog failed for RTL"; exit 1 }

Write-Host ""
Write-Host "========================================"
Write-Host "Step 3: Compile testbench"
Write-Host "========================================"
& $vivado_bin\xvlog.bat -sv "$tb_dir\tb_dac_interface.v"
if ($LASTEXITCODE -ne 0) { Write-Host "[ERROR] xvlog failed for TB"; exit 1 }

Write-Host ""
Write-Host "========================================"
Write-Host "Step 4: Elaborate"
Write-Host "========================================"
& $vivado_bin\xelab.bat tb_dac_interface -s top_sim
if ($LASTEXITCODE -ne 0) { Write-Host "[ERROR] xelab failed"; exit 1 }

Write-Host ""
Write-Host "========================================"
Write-Host "Step 5: Run simulation"
Write-Host "========================================"
& $vivado_bin\xsim.bat top_sim -tclbatch "xsim_run.tcl"
if ($LASTEXITCODE -ne 0) { Write-Host "[ERROR] xsim failed"; exit 1 }

Write-Host ""
Write-Host "========================================"
Write-Host "Simulation completed"
Write-Host "========================================"
