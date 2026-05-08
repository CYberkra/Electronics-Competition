@echo off
setlocal

set "SCRIPT_DIR=%~dp0"
set "REPO_ROOT=%SCRIPT_DIR%.."

echo [%date% %time%] Starting Vivado rebuild...
D:\vivado\Vivado\2024.1\bin\vivado.bat -mode batch -source "%REPO_ROOT%\scripts\rebuild_awg_base.tcl" > "%REPO_ROOT%\vivado\rebuild_run.log" 2>&1
echo [%date% %time%] Vivado finished with exit code %ERRORLEVEL%

endlocal
