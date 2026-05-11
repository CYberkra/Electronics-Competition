# Competition Measurement Report Template

This document is the working report for the fixed-hardware K325T + AD9144 AWG demo. Fill it during oscilloscope sessions and keep the raw CSV/screenshots next to this file under `ad9144_bringup_k325t/measurements/`.

## Hardware Boundary

| Item | Current Hardware | Competition Impact |
|---|---|---|
| FPGA board | ALINX / Openedv K325T, XC7K325TFFG900-2 | Digital baseband, UART control, JESD204 TX |
| DAC card | FMCADDA-9250-9144, AD9144 OUT1 used for scope validation | Single verified analog output path |
| Effective DDS sample rate | 1.0 GSa/s host model, four samples per JESD beat | Enough for a credible AWG demo, not enough to claim full 5 GSa/s output |
| Budget limit | No new high-end RF/DAC hardware | Score through completeness, measurement rigor, calibration, and honest limitations |

## Known Good Start

1. Program the UART bitstream.
2. Wait 12-15 seconds after programming.
3. Read UART status and confirm `ID=0x41574731`.
4. Load the baseline preset:

```powershell
python ad9144_bringup_k325t\tools\awg_uart_control.py --port COM7 demo baseline_50m
```

Expected scope observation on `OUT1`: stable 50 MHz sine wave with visible amplitude response to later preset changes.

## Demo Preset Checklist

Generate the dry-run list before the session:

```powershell
python ad9144_bringup_k325t\tools\awg_uart_control.py demo --list
```

| Preset | What It Demonstrates | Scope Channel | Pass Criteria | Result |
|---|---|---|---|---|
| `baseline_50m` | Known-good sine output | OUT1 | Stable 50 MHz sine | |
| `low_1m` | Low-frequency control | OUT1 | Frequency near 1 MHz | |
| `mid_100m` | Mid-band frequency point | OUT1 | Frequency near 100 MHz | |
| `high_300m` | High-frequency reachable point | OUT1 | Frequency near 300 MHz, distortion noted | |
| `amp_low_50m` | Lower amplitude setting | OUT1 | Vpp lower than baseline | |
| `amp_high_50m` | Higher amplitude setting | OUT1 | Vpp higher than baseline without severe clipping | |
| `square_50m` | Waveform selection | OUT1 | Square-like waveform visible | |
| `triangle_50m` | Waveform selection | OUT1 | Triangle-like waveform visible | |
| `saw_50m` | Waveform selection | OUT1 | Sawtooth-like waveform visible | |

## Frequency Response Table

| Target Frequency | Command / Preset | Measured Frequency | Vpp | Visible Distortion | Note |
|---:|---|---:|---:|---|---|
| 1 MHz | `low_1m` | | | | |
| 50 MHz | `baseline_50m` | | | | |
| 100 MHz | `mid_100m` | | | | |
| 300 MHz | `high_300m` | | | | |
| 400 MHz | manual or sweep | | | | Mark as measurement-limited if counter jumps |

## Amplitude Linearity Table

Keep frequency at 50 MHz. Use 50 ohm termination consistently.

| Amplitude Code | Command / Preset | Measured Vpp | Relative Gain | Visible Clipping | Note |
|---:|---|---:|---:|---|---|
| `0x3000` | `amp_low_50m` | | | | |
| `0x6000` | `baseline_50m` | | | | |
| `0x7000` | `amp_high_50m` | | | | |

## Waveform Mode Table

| Waveform | Command / Preset | Expected Shape | Observed Shape | Artifact / Distortion Note |
|---|---|---|---|---|
| sine | `baseline_50m` | Smooth sine | | |
| square | `square_50m` | Fast transitions, bandwidth-limited edges | | |
| triangle | `triangle_50m` | Linear ramp up/down, rounded by analog path | | |
| sawtooth | `saw_50m` | Ramp with reset edge, bandwidth-limited reset | | |

## Calibration Experiment

Goal: show that the system can compensate measured amplitude roll-off even when the hardware cannot meet the full contest bandwidth target.

1. Measure Vpp at 50 MHz, 100 MHz, 200 MHz, 300 MHz with amplitude `0x6000`.
2. Choose 50 MHz as the reference Vpp.
3. Compute gain correction:

```text
gain_code = round(reference_vpp / measured_vpp * 0x8000)
```

4. Clamp `gain_code` to `0xFFFF`.
5. Write each correction into the matching calibration-table bin.
6. Repeat the sweep and compare Vpp spread before/after.
7. After filling the scope CSV, derive the table and load it with the host tools:

```powershell
python ad9144_bringup_k325t\tools\awg_scope_measurement.py calibration --input ad9144_bringup_k325t\measurements\scope_templates\<filled>.csv
python ad9144_bringup_k325t\tools\awg_uart_control.py cal load --input ad9144_bringup_k325t\measurements\calibration_tables\<filled>_calibration.csv --dry-run
python ad9144_bringup_k325t\tools\awg_uart_control.py --port COM7 cal load --input ad9144_bringup_k325t\measurements\calibration_tables\<filled>_calibration.csv --enable
```

| Frequency | Before Vpp | Gain Code | After Vpp | Improvement |
|---:|---:|---:|---:|---:|
| 50 MHz | | `0x8000` | | |
| 100 MHz | | | | |
| 200 MHz | | | | |
| 300 MHz | | | | |

## Claims For Slides

Use only claims supported by filled measurements.

| Claim | Evidence File / Table | Status |
|---|---|---|
| UART-controlled frequency, amplitude, phase, and waveform selection | Demo preset checklist | |
| 48-bit DDS provides sub-mHz theoretical frequency resolution | Register formula and source code | |
| OUT1 verified on real hardware for multiple waveforms | Waveform mode table and screenshots | |
| Amplitude calibration path exists and can reduce measured roll-off | Calibration experiment table | |
| Full 5 GSa/s / 1 GHz analog performance is limited by fixed hardware | Hardware boundary table | |
