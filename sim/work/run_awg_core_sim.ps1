# Run standalone behavioral simulation for AWG Core
# Tests: dds_nco + sine_lut + wave_shape_gen + sample_mux + amp_offset_scale

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Split-Path (Split-Path $scriptDir -Parent) -Parent

$vivado_bin = "D:\vivado\Vivado\2024.1\bin"
$rtl_dds = Join-Path $repoRoot "rtl" "dds"
$rtl_dsp = Join-Path $repoRoot "rtl" "dsp"
$tb_dir = Join-Path $repoRoot "sim" "tb"
$work_dir = $scriptDir

New-Item -ItemType Directory -Path $work_dir -Force | Out-Null
Set-Location $work_dir

Write-Host "========================================"
Write-Host "Step 1: Clean previous artifacts"
Write-Host "========================================"
Remove-Item *.log, *.pb, *.jou, *.wdb, xsim.dir -Recurse -ErrorAction SilentlyContinue

# Copy sine_table.hex to work directory (for $readmemh path resolution)
Copy-Item "$rtl_dds\sine_table.hex" "$work_dir\sine_table.hex" -Force

Write-Host ""
Write-Host "========================================"
Write-Host "Step 2: Compile RTL sources"
Write-Host "========================================"

& $vivado_bin\xvlog.bat -sv "$rtl_dds\dds_nco.v"
if ($LASTEXITCODE -ne 0) { exit 1 }

& $vivado_bin\xvlog.bat -sv "$rtl_dds\sine_lut.v"
if ($LASTEXITCODE -ne 0) { exit 1 }

& $vivado_bin\xvlog.bat -sv "$rtl_dds\wave_shape_gen.v"
if ($LASTEXITCODE -ne 0) { exit 1 }

& $vivado_bin\xvlog.bat -sv "$rtl_dsp\sample_mux.v"
if ($LASTEXITCODE -ne 0) { exit 1 }

& $vivado_bin\xvlog.bat -sv "$rtl_dsp\amp_offset_scale.v"
if ($LASTEXITCODE -ne 0) { exit 1 }

Write-Host ""
Write-Host "========================================"
Write-Host "Step 3: Compile testbench"
Write-Host "========================================"
& $vivado_bin\xvlog.bat -sv "$tb_dir\tb_awg_core.v"
if ($LASTEXITCODE -ne 0) { exit 1 }

Write-Host ""
Write-Host "========================================"
Write-Host "Step 4: Elaborate"
Write-Host "========================================"
& $vivado_bin\xelab.bat tb_awg_core -s top_sim
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
