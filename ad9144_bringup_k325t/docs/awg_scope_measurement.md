# AD9144 AWG Scope Measurement Workflow

This workflow keeps oscilloscope observations tied to the UART register settings that produced them.

## Generate A Blank Template

Use a built-in profile:

```powershell
python D:\FPGA\ad9144_bringup_k325t\tools\awg_scope_measurement.py template --profile freq_response --out D:\FPGA\ad9144_bringup_k325t\measurements\scope_templates\freq_response.csv
```

Available profiles:

- `freq_response`: 1, 5, 10, 20, 50, 100, 200, 300, 400 MHz sine at amplitude `0x6000`.
- `high_freq_detail`: 250, 300, 350, 380, 400 MHz sine at amplitude `0x6000`.
- `amplitude_linearity`: 50 MHz sine at amplitude `0x1000` through `0x7000`.
- `wave_modes`: 50 MHz sine/square/triangle/saw at amplitude `0x6000`.

Or create a measurement sheet from a UART sweep CSV:

```powershell
python D:\FPGA\ad9144_bringup_k325t\tools\awg_scope_measurement.py template --from-sweep D:\FPGA\ad9144_bringup_k325t\measurements\uart_sweeps\scope_freq_response_rerun_20260507_1305.csv --out D:\FPGA\ad9144_bringup_k325t\measurements\scope_templates\scope_freq_response_rerun_20260507_1305_scope_template.csv
```

## Fill During Measurement

Fill these columns by hand while observing OUT1:

- `measured_frequency_hz`
- `measured_vpp_v`
- `measured_vrms_v`
- `trigger_stability`: for example `stable`, `counter jumps`, `trigger unstable`.
- `visible_distortion`: for example `none`, `mild`, `obvious`, `clipped`.
- `note`

Keep `termination=50ohm` when the oscilloscope input is set to 50 ohm or an external 50 ohm load is used.

## Generate A Markdown Report

```powershell
python D:\FPGA\ad9144_bringup_k325t\tools\awg_scope_measurement.py report --input D:\FPGA\ad9144_bringup_k325t\measurements\scope_templates\scope_freq_response_rerun_20260507_1305_scope_template.csv --out D:\FPGA\ad9144_bringup_k325t\measurements\scope_reports\scope_freq_response_rerun_20260507_1305.md
```

## Current Board Observation

On 2026-05-07, OUT1 was verified to respond to UART-controlled frequency, amplitude, and waveform changes. The 400 MHz point appeared to have jumping frequency on the oscilloscope, but repeated UART readback showed stable FPGA registers:

```text
PHASE_INC=0x666666666666
AMPLITUDE=0x6000
WAVE_MODE=0
CONTROL=0x00000003
```

So that symptom is currently classified as oscilloscope-side measurement/counter/trigger behavior, not FPGA register-control instability.
