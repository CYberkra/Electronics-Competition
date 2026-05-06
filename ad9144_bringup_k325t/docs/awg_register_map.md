# AD9144 AWG Register Map Draft

This is the first register-control boundary for moving from the button demo to a PC-controlled AWG. The current top-level ties the write/read interface idle, so the verified KEY0/KEY1 behavior stays unchanged. Future UART/PCIe/XDMA control logic should drive this bank instead of editing the AWG datapath directly.

## Clock Domain

- Current skeleton clock: `w_tx_core_clk`
- Current write path: tied idle in `variants/awg_button/top.v`
- Current default: `CONTROL[1]=0`, so button-selected values drive the waveform generator

## Addresses

| Address | Name | Access | Description |
|---:|---|---|---|
| `0x00` | `ID` | RO | `0x41574731`, ASCII `AWG1` |
| `0x04` | `VERSION` | RO | `0x20260507` |
| `0x08` | `CONTROL` | RW | bit0 `output_enable`, bit1 `use_reg_control` |
| `0x0C` | `STATUS` | RO | output/link/sample status flags |
| `0x10` | `PHASE_INC_LO` | RW | DDS phase increment bits `[31:0]` |
| `0x14` | `PHASE_INC_HI` | RW | DDS phase increment bits `[47:32]` in low 16 bits |
| `0x18` | `PHASE_OFFSET_LO` | RW | DDS phase offset bits `[31:0]` |
| `0x1C` | `PHASE_OFFSET_HI` | RW | DDS phase offset bits `[47:32]` in low 16 bits |
| `0x20` | `AMPLITUDE` | RW | Q15 amplitude scale, low 16 bits |
| `0x24` | `OFFSET` | RW | signed output offset, low 16 bits |
| `0x28` | `WAVE_MODE` | RW | `0=sine`, `1=square`, `2=triangle`, `3=saw` |
| `0x2C` | `APPLY` | WO | any write toggles `update_toggle` for future CDC/event handling |
| `0x30` | `BUTTON_STATE` | RO | packed current button-demo mode selections |

## Control Semantics

- `CONTROL[0] output_enable`
  - reset default: `1`
  - `1`: pass generated samples to JESD TX
  - `0`: drive zero samples into JESD TX
- `CONTROL[1] use_reg_control`
  - reset default: `0`
  - `0`: use current KEY0/KEY1 demo selections
  - `1`: use register values for frequency, phase, amplitude, offset, and waveform

## Reset Defaults

| Field | Default | Meaning |
|---|---:|---|
| `CONTROL` | `0x00000001` | output enabled, button control active |
| `PHASE_INC` | `0x0CCCCCCCCCCD` | known-good 50 MHz demo setting |
| `PHASE_OFFSET` | `0x000000000000` | 0 degree phase |
| `AMPLITUDE` | `0x6000` | same as current button-demo default |
| `OFFSET` | `0x0000` | no offset |
| `WAVE_MODE` | `0` | sine |

## Next Integration Step

Add a real configuration master in a slower control clock domain, then synchronize `APPLY` into `w_tx_core_clk`. Until that exists, do not set `CONTROL[1]=1` from top-level constants; the hardware-verified fallback should remain button controlled.
