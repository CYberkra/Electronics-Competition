@echo off
REM ============================================================================
REM Quick launcher: Open AWG project in Vivado 2024.1
REM ============================================================================

set "SCRIPT_DIR=%~dp0"
set "REPO_ROOT=%SCRIPT_DIR%..\.."
set VIVADO2024_1=D:\vivado\Vivado\2024.1\bin\vivado.bat
set PROJECT=%REPO_ROOT%\vivado\awg_k325t.xpr

if not exist "%VIVADO2024_1%" (
    echo [ERROR] Vivado 2024.1 not found at %VIVADO2024_1%
    echo Please complete installation first.
    pause
    exit /b 1
)

echo Opening project in Vivado 2024.1...
echo   Vivado:  %VIVADO2024_1%
echo   Project: %PROJECT%
echo.

"%VIVADO2024_1%" "%PROJECT%"
