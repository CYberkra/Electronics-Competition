# AD9144 Qt Upper Host

This is the main PC-side application for the K325T + FMCADDA-9250-9144 AWG demo. It supersedes the first Tkinter panel while keeping the existing CLI tools as the protocol back end.

## Scope

The app covers the current fixed-hardware competition workflow:

- UART register control through CH340.
- Frequency, phase, amplitude, offset, waveform, range, output gate, and calibration control.
- Digital waveform preview from the same DDS/LUT model used by `awg_wave_quality.py`.
- Manual oscilloscope CSV template/report workflow.
- 16-bin amplitude calibration table generation, editing, dump, and load.
- Portable Windows executable packaging through PyInstaller.

It intentionally does **not** automate the oscilloscope through SCPI/VISA yet. For the current stage, scope measurements are imported/exported as CSV files.

## Install

From the repository root:

```powershell
python -m pip install -r ad9144_bringup_k325t\requirements-upper-host.txt
```

## Launch

```powershell
python ad9144_bringup_k325t\launch_upper_host.py
```

Alternative module form:

```powershell
python -m ad9144_bringup_k325t.upper_host
```

The legacy Tkinter panel remains available:

```powershell
python ad9144_bringup_k325t\tools\awg_uart_panel.py
```

## Smoke Check

The preferred no-hardware check compiles the upper-host modules, runs backend regression tests, then runs the Qt window offscreen. Use it before pushing changes to the PC-side tooling.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File ad9144_bringup_k325t\scripts\check_upper_host.ps1
```

Expected terminal marker:

```text
UPPER_HOST_CHECK_OK
```

The lower-level Qt smoke check can still be run directly. It creates the Qt window offscreen, generates a preview waveform, creates a scope template/report/calibration CSV, and runs a digital waveform QA CSV.

```powershell
$env:QT_QPA_PLATFORM = "offscreen"
python ad9144_bringup_k325t\launch_upper_host.py --smoke
```

Expected terminal marker:

```text
UPPER_HOST_SMOKE_OK
```

## Build Portable EXE

```powershell
ad9144_bringup_k325t\scripts\build_upper_host.ps1
```

Default output:

```text
artifacts\upper_host\ad9144_upper_host\ad9144_upper_host.exe
```

`artifacts/` is ignored by Git. Rebuild the EXE locally when needed.

## Page Guide

### Dashboard

- Shows current connection, board ID/version, derived frequency, waveform/range, calibration state, and JESD/status flags.
- Shows a local digital waveform preview. This is a code-domain preview, not an analog scope capture.
- Quick actions: read status, apply baseline, return to button control, output off.

### Control

- Manual controls for frequency, sample rate, amplitude, offset, phase, waveform, range, output enable, register-control enable, and calibration enable.
- Demo preset loader for competition points such as `baseline_50m`, `low_1m`, `mid_100m`, `high_300m`, `amp_low_50m`, `amp_high_50m`, and waveform modes.
- `Apply Preset` writes the current form to hardware and sets `CONTROL[1]=1`.
- `Button Control` returns the board to physical-button mode with `CONTROL[1]=0`.

### Measurements

- Generate blank scope templates from built-in profiles:
  - `freq_response`
  - `high_freq_detail`
  - `amplitude_linearity`
  - `wave_modes`
- Import a filled scope CSV and generate a Markdown report.
- Derive a 16-bin calibration CSV from filled `measured_vpp_v` values.
- Run digital waveform QA profiles: `quick`, `wave`, `amplitude`, `full`.

### Calibration

- Load, edit, and save calibration CSV files.
- Fill a unity table (`gain_q15=0x8000`, `offset=0`).
- Dump the current hardware calibration table over UART.
- Load the current table to hardware and optionally enable calibration.
- Enable/disable `CAL_ENABLE` independently.

## Recommended Board Workflow

1. Program the UART-control bitstream.
2. Wait 12-15 seconds for vendor AD9144/clock setup.
3. Detect COM port:

```powershell
Get-PnpDevice -PresentOnly -Class Ports
```

4. Launch the Qt upper host.
5. Select the CH340 COM port and click `Read Status`.
6. Confirm `ID=0x41574731`.
7. Apply `baseline_50m` and observe OUT1.
8. Use `Measurements` to create/fill a scope CSV.
9. Generate report and calibration table.
10. Use `Calibration` to load/enable the table, then repeat the measurement sweep.

## Implementation Notes

- The app imports the existing CLI modules instead of duplicating protocol math.
- `tools/*.py` now support both direct script execution and package import.
- Qt binding is forced to PySide6 for pyqtgraph compatibility.
- All generated measurements, reports, and EXE outputs remain ignored by Git.
