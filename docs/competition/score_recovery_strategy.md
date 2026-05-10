# Fixed-Hardware Score Recovery Strategy

This strategy assumes the team will not buy additional high-end RF/DAC hardware. The goal is to maximize score from demonstrable engineering work on the existing K325T + FMCADDA-9250-9144 platform.

## Positioning

Do not claim the current hardware fully satisfies the highest analog-output targets. Present the project as a completed AWG prototype that proves the digital baseband, JESD204 DAC path, PC control, measurement workflow, and calibration strategy.

## High-Value Score Areas

| Area | Why It Scores | Concrete Deliverable |
|---|---|---|
| System completeness | Judges can operate a real end-to-end AWG, not just see isolated RTL | GUI + UART + FPGA + AD9144 OUT1 demo |
| Control precision | 48-bit DDS is a strong mathematical feature | Frequency-control formula, phase increment readback, low-frequency examples |
| Waveform diversity | Shows arbitrary-waveform direction even with a simple LUT engine | sine/square/triangle/saw demos and screenshots |
| Measurement rigor | Converts limited hardware into credible engineering evidence | `competition_measurement_report.md`, CSV templates, scope screenshots |
| Calibration | Shows awareness of analog non-idealities and a way to compensate them | before/after amplitude-response table |
| Automation | Reduces live-demo risk and improves repeatability | named demo presets, dry-run list, sweep scripts |
| Honest limitations | Avoids losing trust on impossible hardware claims | explicit hardware boundary slide |

## Recommended Demo Flow

1. Show hardware chain:

```text
PC GUI/CLI -> UART -> K325T register bank -> DDS4 -> JESD204 TX -> AD9144 -> OUT1 -> oscilloscope
```

2. Read status from the GUI and show `ID=0x41574731`.
3. Apply `baseline_50m`; show 50 MHz sine.
4. Apply `amp_low_50m` and `amp_high_50m`; show Vpp changes.
5. Apply `low_1m`, `mid_100m`, `high_300m`; show frequency control.
6. Apply square, triangle, and saw presets; show waveform switching.
7. Show the measurement report tables and calibration method.
8. Close with the hardware limitation and the upgrade path.

## What To Avoid

- Do not claim true 5 GSa/s analog output from the current OUT1 measurement.
- Do not claim 1 GHz analog bandwidth unless measured with credible termination, probe setup, and screenshots.
- Do not spend time designing new analog front-end hardware that cannot be built before the contest.
- Do not rely on only live oscilloscope operation; keep screenshots and CSV evidence ready.

## Next Engineering Tasks

| Priority | Task | Success Criterion |
|---:|---|---|
| 1 | Run the named demo presets on hardware | Each preset has a pass/fail row in the measurement report |
| 2 | Fill the frequency-response table | At least 1, 50, 100, and 300 MHz measured |
| 3 | Fill the amplitude-linearity table | `0x3000`, `0x6000`, `0x7000` measured at 50 MHz |
| 4 | Capture waveform screenshots | sine/square/triangle/saw screenshots saved |
| 5 | Run a simple calibration before/after | Vpp spread improvement documented |
| 6 | Prepare slides from evidence | Every claim points to a measurement or source file |

## Upgrade Path If Hardware Becomes Available

If funding appears later, the best upgrade is not a random analog board. The next hardware should specifically improve the bottleneck that limits contest score: a DAC path with documented >=5 GSa/s update rate, >=1 GHz usable analog output bandwidth, clean clocking, and a reference design compatible with the selected FPGA or a replacement FPGA board.

