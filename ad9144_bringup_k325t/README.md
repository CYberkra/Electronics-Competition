# K325T AD9144 AWG Bring-Up

This folder contains the current K325T + FMCADDA-9250-9144 AD9144 AWG bring-up work.

## Current Phase

The current working path is the UART-controlled AD9144 AWG demo:

```text
PC GUI/CLI -> CH340 UART -> K325T register bank -> DDS4 sample generator -> JESD204 TX -> AD9144 OUT1
```

Verified on 2026-05-07:

- OUT1 responds to UART-controlled frequency changes.
- OUT1 responds to UART-controlled amplitude changes.
- OUT1 responds to sine/square/triangle/saw waveform mode changes.
- Coarse sine sweep looked broadly normal through 300 MHz.
- A 400 MHz counter/frequency jump was traced to oscilloscope measurement behavior; FPGA readback stayed stable.

## One-Minute Start

1. Power the K325T board and FMCADDA-9250-9144 card.
2. Connect JTAG and the CH340 UART adapter.
3. Program the UART bit:

```powershell
# Set VIVADO_PATH environment variable to your Vivado 2024.1 installation
$env:VIVADO_PATH = "D:\Xilinx\Vivado\2024.1\bin\vivado.bat"
& $env:VIVADO_PATH -mode batch -source scripts\program_awg_uart.tcl
```

4. Wait 12-15 seconds for AD9144/clock setup.
5. Detect the COM port:

```powershell
Get-PnpDevice -PresentOnly -Class Ports
```

6. Start the Qt upper host:

```powershell
python ad9144_bringup_k325t\launch_upper_host.py
```

7. In the app, choose the COM port, click `Read Status`, then load a known baseline:

```text
Frequency Hz: 50000000
Sample Rate: 1000000000
Amplitude: 0x6000
Offset: 0
Phase deg: 0
Wave: sine
```

## Important Commands

Install upper-host dependencies:

```powershell
python -m pip install -r ad9144_bringup_k325t\requirements-upper-host.txt
```

Run the full no-hardware upper-host check:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File ad9144_bringup_k325t\scripts\check_upper_host.ps1
```

Run the Qt upper host:

```powershell
python ad9144_bringup_k325t\launch_upper_host.py
```

Run the no-hardware smoke check:

```powershell
$env:QT_QPA_PLATFORM = "offscreen"
python ad9144_bringup_k325t\launch_upper_host.py --smoke
```

Build a portable EXE:

```powershell
ad9144_bringup_k325t\scripts\build_upper_host.ps1
```

Build the UART-control bitstream if the generated bit is missing or stale:

```powershell
$env:VIVADO_PATH = "D:\Xilinx\Vivado\2024.1\bin\vivado.bat"
& $env:VIVADO_PATH -mode batch -tempDir C:/tmp/vivado_awg_uart_temp -journal C:/tmp/vivado_awg_uart.jou -log C:/tmp/vivado_awg_uart.log -source scripts\build_awg_uart_direct.tcl
```

CLI status check:

```powershell
python tools\awg_uart_control.py --port COM7 status
```

CLI preset:

```powershell
python tools\awg_uart_control.py --port COM7 preset --frequency 50000000 --amplitude 0x6000 --wave sine
```

List competition demo presets without touching hardware:

```powershell
python tools\awg_uart_control.py demo --list
python tools\awg_uart_control.py demo baseline_50m --dry-run
```

Apply a named competition demo preset:

```powershell
python tools\awg_uart_control.py --port COM7 demo baseline_50m
python tools\awg_uart_control.py --port COM7 demo all --step-delay 2.0
```

Run a repeatable UART sweep:

```powershell
python tools\awg_uart_sweep.py --port COM7 --profile quick --settle 0.05 --out measurements\uart_sweeps\quick_latest.csv
```

Derive a calibration table from a filled scope CSV:

```powershell
python tools\awg_scope_measurement.py calibration --input measurements\scope_templates\<filled>.csv --out measurements\calibration_tables\<filled>_calibration.csv
python tools\awg_uart_control.py cal load --input measurements\calibration_tables\<filled>_calibration.csv --dry-run
python tools\awg_uart_control.py --port COM7 cal load --input measurements\calibration_tables\<filled>_calibration.csv --enable
```

Run digital waveform self-check:

```powershell
python tools\awg_wave_quality.py --profile quick --out reports\wave_quality\quick_latest.csv
```

Create a fillable oscilloscope measurement sheet:

```powershell
python tools\awg_scope_measurement.py template --profile freq_response
```

## Documentation Map

- Phase handoff: `docs\phase_handoff_2026-05-07.md`
- Next board checklist: `docs\next_board_session_checklist.md`
- UART protocol: `docs\ad9144_uart_control_protocol.md`
- Register map: `docs\awg_register_map.md`
- Qt upper host: `docs\upper_host_qt.md`
- Legacy Tkinter GUI notes: `docs\awg_uart_panel.md`
- Digital waveform quality: `docs\awg_wave_quality.md`
- Scope measurement workflow: `docs\awg_scope_measurement.md`
- Competition measurement report: `docs\competition_measurement_report.md`
- Calibration workflow: `docs\awg_scope_measurement.md` and `tools\awg_uart_control.py cal`
- Fixed-hardware score recovery strategy: `..\docs\competition\score_recovery_strategy.md`

## Generated Files Policy

Vivado output directories, bitstreams, reports, measurement CSVs, and local logs are intentionally not tracked by Git. Rebuild them from the checked-in scripts when needed.
