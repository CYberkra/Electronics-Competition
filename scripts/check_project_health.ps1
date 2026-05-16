[CmdletBinding()]
param(
    [string]$Python = "python",
    [switch]$SkipQtSmoke,
    [switch]$SkipStaticRtl
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = Resolve-Path (Join-Path $ScriptDir "..")

function Invoke-CheckedProcess {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Program,
        [Parameter(Mandatory = $true)]
        [string[]]$Arguments,
        [Parameter(Mandatory = $true)]
        [string]$FailureMessage
    )

    & $Program @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "$FailureMessage (exit code $LASTEXITCODE)"
    }
}

Push-Location $RepoRoot
try {
    Write-Host "[health] Upper host"
    $upperArgs = @(
        "-NoProfile",
        "-ExecutionPolicy", "Bypass",
        "-File", "ad9144_bringup_k325t\scripts\check_upper_host.ps1",
        "-Python", $Python
    )
    if ($SkipQtSmoke) {
        $upperArgs += "-SkipQtSmoke"
    }
    Invoke-CheckedProcess `
        -Program "powershell" `
        -Arguments $upperArgs `
        -FailureMessage "upper-host health check failed"

    if ($SkipStaticRtl) {
        Write-Host "[health] Skipping static RTL checks by request."
    }
    else {
        Write-Host "[health] Static AD9144 RTL wiring"
        $checks = @(
            "check_awg_button_sequence.ps1",
            "check_awg_waveform_modes.ps1",
            "check_awg_register_debug_wiring.ps1",
            "check_awg_uart_control_wiring.ps1"
        )
        foreach ($check in $checks) {
            Invoke-CheckedProcess `
                -Program "powershell" `
                -Arguments @(
                    "-NoProfile",
                    "-ExecutionPolicy", "Bypass",
                    "-File", (Join-Path "ad9144_bringup_k325t\scripts" $check)
                ) `
                -FailureMessage "$check failed"
        }
    }

    Write-Host "[health] Git whitespace check"
    Invoke-CheckedProcess `
        -Program "git" `
        -Arguments @("diff", "--check") `
        -FailureMessage "git diff --check failed"

    Write-Host "PROJECT_HEALTH_OK"
}
finally {
    Pop-Location
}
