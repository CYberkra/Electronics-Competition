# AD9144 Bring-Up Package

> Standalone AD9144/JESD204B bring-up for K325T + FMCADDA-9250-9144
> Verified chain: PC GUI/CLI → UART → Register Bank → DDS4 → JESD204 TX → AD9144 OUT1

## OVERVIEW

This is a **self-contained bring-up package** for the AD9144 high-speed DAC path. It does not depend on the main `awg_k325t` Vivado project. Use it to verify JESD204 link establishment before integrating into the full AWG system.

## STRUCTURE

```
ad9144_bringup_k325t/
├── rtl/awg/                    # AWG RTL (DDS4, UART, reg bank)
│   ├── ad9144_awg_dds4.v       # 4096-point sine LUT + waveform modes
│   ├── ad9144_sample_packer.v  # 4-sample JESD beat packing
│   ├── ad9144_uart_reg_bridge.v# UART → AXI-Lite register interface
│   ├── ad9144_awg_reg_bank.v   # Register map (ID, VERSION, CONTROL, etc.)
│   ├── uart_rx.v / uart_tx.v   # 115200 baud UART
├── variants/awg_button/        # Board-button demo variant
│   └── top.v                   # 987-line top with vendor JESD init
├── constraints/                # XDC for K325T FMC HPC
├── scripts/                    # Build & program Tcl scripts
├── tools/                      # Python host utilities
│   ├── awg_uart_control.py     # CLI register control
│   ├── awg_uart_panel.py       # Tkinter GUI panel
│   ├── awg_uart_sweep.py       # Automated sweep + CSV logger
│   ├── awg_wave_quality.py     # Digital waveform THD/spur check
│   └── awg_scope_measurement.py# Oscilloscope measurement templates
├── docs/                       # Protocol docs & handoff notes
└── README.md                   # Detailed bring-up guide
```

## WHERE TO LOOK

| Task | Location | Notes |
|------|----------|-------|
| Build bitstream | `scripts/build_awg_uart_direct.tcl` | Main UART-control variant |
| Program board | `scripts/program_awg_uart.tcl` | Via JTAG, wait 12-15s after |
| Control from PC | `tools/awg_uart_control.py --port COMx status` | Requires CH340 USB-UART |
| GUI control | `tools/awg_uart_panel.py` | Tkinter, COM7 default |
| Competition demo presets | `tools/awg_uart_control.py demo --list` | Fixed sequence for scope sessions |
| Register map | `docs/ad9144_uart_control_protocol.md` | 115200 8N1, hex addr/data |
| Waveform quality | `tools/awg_wave_quality.py --profile quick` | Digital-only THD check |
| Debug ILA build | `scripts/build_awg_button_debug.tcl` | 384 extra probes, timing unclean |

## KEY MODULES

| Module | Purpose | Lines |
|--------|---------|-------|
| `variants/awg_button/top.v` | Top-level: vendor JESD init + AWG + UART | 987 |
| `rtl/awg/ad9144_awg_dds4.v` | Waveform gen: sine/square/triangle/saw | 208 |
| `rtl/awg/ad9144_sample_packer.v` | Packs 4 DAC samples per JESD TX beat | — |
| `rtl/awg/ad9144_uart_reg_bridge.v` | UART command parser → reg read/write | 378 |
| `rtl/awg/ad9144_awg_reg_bank.v` | Register map, default CONTROL=0x1 | — |

## CONVENTIONS

- **Vivado**: 2024.1 Enterprise (Standard lacks K325T + JESD204 support)
- **Target**: `xc7k325tffg900-2`
- **FMC**: Bank 117 GTX (HPC connector)
- **RefClk**: 125 MHz from LMK04828 → `GBTCLK0_M2C_P/N` (G8/G7)
- **UART**: Pins T23 (RXD) / T22 (TXD), 115200 8N1
- **Reset wait**: 12-15 seconds after programming (vendor rst_module delay)
- **Bitstreams**: Never commit `.bit`/`.ltx`/logs; rebuild from scripts

## ANTI-PATTERNS

- **DO NOT** use Vivado 2024.2 — JESD204 v7.2 IP removed for 7-series
- **DO NOT** use hardcoded `D:/awg_fpga` paths in new scripts
- **DO NOT** judge output before 12s post-programming (reset delay)
- **DO NOT** treat debug bitstream (`_debug.bit`) as timing-clean release
- **DO NOT** commit generated artifacts: `vivado_awg_*/`, `*.bit`, `*.ltx`, logs

## BASELINE

```text
ID=0x41574731  VERSION=0x20260507
50 MHz sine:  PHASE_INC=0x0CCCCCCCCCCD  AMPLITUDE=0x6000  WAVE_MODE=0
CONTROL=0x3   (output_enable=1, use_reg_control=1)
```

`OUTPUT_EN` at `0x38` is a compatibility alias for `CONTROL[0]`; both read
and write the same datapath gate that drives zero samples when disabled.
Calibration table gain is unsigned Q1.15: `0x4000=0.5`, `0x8000=1.0`,
`0xFFFF~=2.0`; the upper halfword remains a signed 16-bit offset.

## COMMANDS

```powershell
# Build UART-control variant
& $env:VIVADO_PATH -mode batch -source scripts/build_awg_uart_direct.tcl

# Program
& $env:VIVADO_PATH -mode batch -source scripts/program_awg_uart.tcl

# Check status (after 12-15s wait)
python tools/awg_uart_control.py --port COM7 status

# Apply 50 MHz sine preset
python tools/awg_uart_control.py --port COM7 preset --frequency 50000000 --amplitude 0x6000 --wave sine

# List and run competition demo presets
python tools/awg_uart_control.py demo --list
python tools/awg_uart_control.py --port COM7 demo baseline_50m
python tools/awg_uart_control.py --port COM7 demo all --step-delay 2.0

# Quick sweep
python tools/awg_uart_sweep.py --port COM7 --profile quick --settle 0.05

# Fill scope CSV, then derive a calibration table
python tools/awg_scope_measurement.py calibration --input measurements/scope_templates/<filled>.csv

# Load calibration table to hardware
python tools/awg_uart_control.py cal load --input measurements/calibration_tables/<filled>_calibration.csv --dry-run
python tools/awg_uart_control.py --port COM7 cal load --input measurements/calibration_tables/<filled>_calibration.csv --enable

# Dump calibration table from hardware
python tools/awg_uart_control.py --port COM7 cal dump --out measurements/calibration_tables/<readback>.csv

# Digital quality check
python tools/awg_wave_quality.py --profile quick

# RTL calibration testbench
& $env:VIVADO_PATH -mode batch -source scripts/run_tb_awg_cal.tcl
```

## NOTES

- **Timing**: Routed WNS ~ -3.3 ns (known vendor/debug/CDC paths). Bitstream generates but is demo-quality only.
- **Debug**: `build_awg_button_debug.tcl` adds 384 ILA probes. Use for ILA bring-up, not release.
- **Scope artifacts at 400 MHz**: Oscilloscope counter behavior, not FPGA register instability.
- **Calibration workflow**: use `tools/awg_scope_measurement.py calibration` to derive `CAL_TABLE[0:15]` CSV, then `tools/awg_uart_control.py cal load` to program the entries and `cal enable/disable` to switch the compensation path.
- **CH340 USB-UART**: Required for PC control; JTAG alone only programs bitstream.
