[CmdletBinding()]
param(
    [string]$Python = "python",
    [switch]$SkipQtSmoke
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$BringupRoot = Resolve-Path (Join-Path $ScriptDir "..")
$RepoRoot = Resolve-Path (Join-Path $BringupRoot "..")

function Invoke-Python {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$PythonArgs
    )

    & $Python @PythonArgs
    if ($LASTEXITCODE -ne 0) {
        throw "Python command failed with exit code $LASTEXITCODE`: $Python $($PythonArgs -join ' ')"
    }
}

Push-Location $RepoRoot
try {
    Write-Host "[1/3] Compiling upper-host Python modules..."
    Invoke-Python -PythonArgs @(
        "-m", "compileall", "-q",
        "ad9144_bringup_k325t\launch_upper_host.py",
        "ad9144_bringup_k325t\upper_host",
        "ad9144_bringup_k325t\tools",
        "ad9144_bringup_k325t\tests"
    )

    Write-Host "[2/3] Running no-hardware backend regression tests..."
    Invoke-Python -PythonArgs @(
        "-m", "unittest", "discover",
        "-s", "ad9144_bringup_k325t\tests",
        "-p", "test_*.py",
        "-v"
    )

    if ($SkipQtSmoke) {
        Write-Host "[3/3] Skipping Qt offscreen smoke check by request."
    }
    else {
        Write-Host "[3/3] Running Qt offscreen smoke check..."
        $HadQtPlatform = Test-Path Env:\QT_QPA_PLATFORM
        $OldQtPlatform = $env:QT_QPA_PLATFORM
        try {
            if (-not $HadQtPlatform -or [string]::IsNullOrWhiteSpace($env:QT_QPA_PLATFORM)) {
                $env:QT_QPA_PLATFORM = "offscreen"
            }

            $SmokeOutput = & $Python @("ad9144_bringup_k325t\launch_upper_host.py", "--smoke") 2>&1
            $SmokeExit = $LASTEXITCODE
            $SmokeOutput | ForEach-Object { Write-Host $_ }
            if ($SmokeExit -ne 0) {
                throw "Qt smoke check failed with exit code $SmokeExit"
            }
            if (($SmokeOutput -join "`n") -notmatch "UPPER_HOST_SMOKE_OK") {
                throw "Qt smoke check did not print UPPER_HOST_SMOKE_OK"
            }
        }
        finally {
            if ($HadQtPlatform) {
                $env:QT_QPA_PLATFORM = $OldQtPlatform
            }
            else {
                Remove-Item Env:\QT_QPA_PLATFORM -ErrorAction SilentlyContinue
            }
        }
    }

    Write-Host "UPPER_HOST_CHECK_OK"
}
finally {
    Pop-Location
}
