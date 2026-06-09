# Run standalone behavioral simulation for a specific testbench
# Usage: .\sim\run_sim.ps1 -Tb awg_core
#   -Tb awg_core      # AWG Core (dds_nco + sine_lut + wave_shape_gen + awg_core)
#   -Tb awg_key_ui    # Key control UI
#   -Tb awg_led       # LED status
#   -Tb awg_cal       # AWG calibration
#   -Tb dds_compiler  # DDS Compiler IP wrapper

param([string]$Tb = "awg_core")

$repo_root = Split-Path -Parent $PSScriptRoot
$vivado_bin = if (Test-Path "D:\Xilinx\Vivado\2024.1\bin") { "D:\Xilinx\Vivado\2024.1\bin" } else { throw "Vivado 2024.1 not found" }

$rtl_dirs = @(
    "$repo_root\rtl\dds",
    "$repo_root\rtl\dsp",
    "$repo_root\rtl\sweep",
    "$repo_root\rtl\wave"
)

$tb_map = @{
    "awg_core"     = @{ tb="tb_awg_core";     rtl="dds_nco.v,sine_lut.v,wave_shape_gen.v,sample_mux.v,amp_offset_scale.v,sweep_engine.v,bram_wave_player.v,awg_core.v" }
    "awg_key_ui"   = @{ tb="tb_awg_key_ui_ctrl"; rtl="awg_key_ui_ctrl.v" }
    "awg_led"      = @{ tb="tb_awg_led_status";  rtl="awg_led_status.v" }
    "awg_cal"      = @{ tb="tb_awg_cal";         rtl="ad9144_awg_cal.v" }
    "dds_compiler" = @{ tb="tb_dds_compiler";    rtl="dds_compiler_wrapper.v" }
}

if (-not $tb_map.ContainsKey($Tb)) {
    Write-Host "Unknown testbench: $Tb. Options: $($tb_map.Keys -join ', ')"
    exit 1
}

$info = $tb_map[$Tb]
$tb_file = "$repo_root\sim\tb\$($info.tb).v"
if (-not (Test-Path $tb_file)) { throw "Testbench not found: $tb_file" }

$work_dir = "$repo_root\sim\work"
New-Item -ItemType Directory -Path $work_dir -Force | Out-Null
Set-Location $work_dir

# Clean previous artifacts
Remove-Item *.log, *.pb, *.jou, *.wdb, xsim.dir -Recurse -ErrorAction SilentlyContinue

# Copy sine_table.hex for $readmemh path resolution
Copy-Item "$repo_root\ad9144_sine_4096.hex" "$work_dir\sine_table.hex" -Force

Write-Host "=== Sim: $($info.tb) ==="

# Compile RTL
foreach ($rtl in $info.rtl.Split(',')) {
    Write-Host "  compile: $rtl"
    & $vivado_bin\xvlog.bat -sv "$repo_root\rtl\jesd\$rtl" -quiet 2>$null
    if ($LASTEXITCODE -ne 0) {
        # Try other RTL directories
        $found = $false
        foreach ($d in $rtl_dirs) {
            $p = "$d\$rtl"
            if (Test-Path $p) { & $vivado_bin\xvlog.bat -sv $p -quiet; $found = $true; break }
        }
        if (-not $found) { Write-Host "  WARNING: $rtl not found" }
    }
}

# Compile testbench
Write-Host "  compile: $($info.tb).v"
& $vivado_bin\xvlog.bat -sv $tb_file
if ($LASTEXITCODE -ne 0) { exit 1 }

# Elaborate
& $vivado_bin\xelab.bat $($info.tb) -s top_sim
if ($LASTEXITCODE -ne 0) { exit 1 }

# Run
Set-Content -Path "xsim_run.tcl" -Value "run all"
& $vivado_bin\xsim.bat top_sim -tclbatch "xsim_run.tcl"
if ($LASTEXITCODE -ne 0) { exit 1 }

Write-Host "=== Simulation completed ==="
