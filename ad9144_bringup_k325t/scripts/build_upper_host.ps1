param(
    [string]$Python = "python",
    [string]$Name = "ad9144_upper_host",
    [string]$DistDir = ""
)

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$BringupRoot = Resolve-Path (Join-Path $ScriptDir "..")
$RepoRoot = Resolve-Path (Join-Path $BringupRoot "..")

if ([string]::IsNullOrWhiteSpace($DistDir)) {
    $DistDir = Join-Path $RepoRoot "artifacts/upper_host"
}

$launcher = Join-Path $BringupRoot "launch_upper_host.py"
$buildRoot = Join-Path $RepoRoot "build"
$work = Join-Path $buildRoot "$Name.work"
$lutData = "$(Join-Path $BringupRoot 'rtl/awg/ad9144_sine_4096.hex');ad9144_bringup_k325t/rtl/awg"
$readmeData = "$(Join-Path $BringupRoot 'README.md');ad9144_bringup_k325t"
$docsData = "$(Join-Path $BringupRoot 'docs');ad9144_bringup_k325t/docs"

$env:PYQTGRAPH_QT_LIB = "PySide6"
$env:QT_API = "pyside6"

& $Python -c "import PySide6, pyqtgraph, serial, numpy, PyInstaller; print('UPPER_HOST_BUILD_DEPS_OK')"
if ($LASTEXITCODE -ne 0) {
    throw "Selected Python does not have the upper-host dependencies. Run: python -m pip install -r requirements-upper-host.txt"
}

& $Python -m PyInstaller `
    --noconfirm `
    --clean `
    --onedir `
    --name $Name `
    --hidden-import pyqtgraph `
    --hidden-import PySide6 `
    --exclude-module PyQt6 `
    --exclude-module PyQt5 `
    --exclude-module PySide2 `
    --distpath $DistDir `
    --workpath $work `
    --specpath $buildRoot `
    --add-data $lutData `
    --add-data $readmeData `
    --add-data $docsData `
    $launcher
