# Wrapper to run Vivado batch with heartbeat for background task compatibility
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Split-Path $scriptDir -Parent

$vivado = "D:\vivado\Vivado\2024.1\bin\vivado.bat"
$tcl = Join-Path $repoRoot "scripts" "rebuild_awg_base.tcl"
$log = Join-Path $repoRoot "vivado" "rebuild_run.log"

Write-Host "========================================"
Write-Host "Starting Vivado wrapper"
Write-Host "TCL: $tcl"
Write-Host "Log: $log"
Write-Host "========================================"

# Start Vivado as child process, redirect output to log file
$proc = Start-Process -FilePath $vivado -ArgumentList "-mode","batch","-source",$tcl -RedirectStandardOutput $log -RedirectStandardError $log -PassThru -NoNewWindow

Write-Host "Vivado PID: $($proc.Id)"
Write-Host "Waiting for completion..."

# Heartbeat loop: print every 30s to keep background worker alive
while (-not $proc.HasExited) {
    Start-Sleep -Seconds 30
    $elapsed = [math]::Round((Get-Date).TimeOfDay.TotalMinutes, 1)
    Write-Host "[$(Get-Date -Format 'HH:mm:ss')] Still running... (elapsed ${elapsed}m)"
    
    # Tail last 5 lines of log so user can see progress
    if (Test-Path $log) {
        $tail = Get-Content $log -Tail 3
        foreach ($line in $tail) {
            if ($line -match "error|Error|ERROR|Starting|Complete|Finished|Status") {
                Write-Host "  >> $line"
            }
        }
    }
}

Write-Host ""
Write-Host "========================================"
Write-Host "Vivado exited with code: $($proc.ExitCode)"
Write-Host "========================================"

# Print final log tail
if (Test-Path $log) {
    Write-Host ""
    Write-Host "--- Final log tail ---"
    Get-Content $log -Tail 20
}
