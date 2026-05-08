# AD9144 AWG Register Map

## Overview

This register bank controls the AWG datapath including DDS parameters, waveform selection, amplitude/offset, digital calibration, and output range selection.

## Clock Domain

- Clock: `w_tx_core_clk` (250 MHz from JESD TX core)
- Write/Read: synchronous to `w_tx_core_clk`
- Reset: `rst_n` (active low, async assert, sync release)

## Register Addresses

| Address | Name | Access | Description |
|---:|---|---|---|
| `0x00` | `ID` | RO | `0x41574731`, ASCII `AWG1` |
| `0x04` | `VERSION` | RO | `0x20260507` |
| `0x08` | `CONTROL` | RW | bit0 `output_enable`, bit1 `use_reg_control` |
| `0x0C` | `STATUS` | RO | output/link/cal/sample status flags |
| `0x10` | `PHASE_INC_LO` | RW | DDS phase increment bits `[31:0]` |
| `0x14` | `PHASE_INC_HI` | RW | DDS phase increment bits `[47:32]` in low 16 bits |
| `0x18` | `PHASE_OFFSET_LO` | RW | DDS phase offset bits `[31:0]` |
| `0x1C` | `PHASE_OFFSET_HI` | RW | DDS phase offset bits `[47:32]` in low 16 bits |
| `0x20` | `AMPLITUDE` | RW | Q15 amplitude scale, low 16 bits |
| `0x24` | `OFFSET` | RW | signed output offset, low 16 bits |
| `0x28` | `WAVE_MODE` | RW | `0=sine`, `1=square`, `2=triangle`, `3=saw` |
| `0x2C` | `APPLY` | WO | any write toggles `update_toggle` |
| `0x30` | `BUTTON_STATE` | RO | packed button-demo mode selections |
| `0x34` | `RANGE_SEL` | RW | analog frontend range: `0=high`, `1=low`, `2=ultra-low` |
| `0x38` | `OUTPUT_EN` | RW | bit0: analog output enable (for relay/PE4302) |
| `0x3C` | `CAL_ENABLE` | RW | bit0: enable digital calibration |
| `0x40`–`0x7C` | `CAL_TABLE[0]`–`CAL_TABLE[15]` | RW | calibration coefficients (step 4) |

## STATUS Register (`0x0C`)

| Bit | Name | Description |
|---:|---|---|
| 0 | `output_enable` | current output enable state |
| 1 | `use_reg_control` | `1`=register control, `0`=button control |
| 2 | `tx_ready` | JESD TX `tready` |
| 3 | `tx_sync` | JESD TX sync status |
| 4 | `sysref_seen` | SYSREF detected |
| 5 | `sample_valid` | sample generator valid |
| 6 | `update_toggle` | toggles on each APPLY write |
| 7 | `output_en` | analog output enable state |
| 9:8 | `range_sel` | current range selection |
| 10 | `cal_enable` | calibration enabled |

## Calibration Table (`0x40`–`0x7C`)

Each calibration entry is 32-bit:
- `[31:16]` = signed 16-bit offset
- `[15:0]` = signed 16-bit gain coefficient (Q15, `0x7FFF` = 1.0)

Frequency bins: `phase_inc[47:44]` selects 1 of 16 entries.

## Control Semantics

- `CONTROL[0] output_enable`
  - reset: `1`
  - `1`: pass samples to JESD TX
  - `0`: drive zero samples
- `CONTROL[1] use_reg_control`
  - reset: `0`
  - `0`: use KEY0/KEY1 demo
  - `1`: use register values
- `CAL_ENABLE[0] cal_enable`
  - reset: `0`
  - `0`: bypass calibration (raw amplitude)
  - `1`: apply freq-dependent gain/offset from CAL_TABLE

## Reset Defaults

| Field | Default | Meaning |
|---|---:|---|
| `CONTROL` | `0x00000001` | output on, button control |
| `PHASE_INC` | `0x0CCCCCCCCCCD` | 50 MHz sine |
| `PHASE_OFFSET` | `0x000000000000` | 0° |
| `AMPLITUDE` | `0x6000` | ~75% scale |
| `OFFSET` | `0x0000` | no offset |
| `WAVE_MODE` | `0` | sine |
| `RANGE_SEL` | `0` | high range |
| `OUTPUT_EN` | `1` | analog output on |
| `CAL_ENABLE` | `0` | calibration off |
| `CAL_TABLE[n]` | `{0x0000, 0x7FFF}` | zero offset, unity gain |

## Integration Notes

1. Write registers in any order
2. Write `APPLY` (`0x2C`) to commit changes
3. If `use_reg_control=1`, DDS uses register values; otherwise button values
4. Calibration applies to amplitude **after** register/bottom selection, **before** DDS waveform generation
5. Calibration coefficients are written via `0x40`–`0x7C`; address = `0x40 + 4*n`

---
**Last Updated**: 2026-05-08
**Version**: 0x20260508 (added calibration + range control)
