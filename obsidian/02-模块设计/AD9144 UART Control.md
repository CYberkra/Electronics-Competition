---
type: module
updated: 2026-05-07
tags:
  - ad9144
  - uart
  - awg
  - register-control
---

# AD9144 UART Control

This note records the PC-control bring-up variant for the K325T AD9144 AWG path.

## Purpose

The user-confirmed button waveform demo remains the fallback baseline. The UART variant adds a PC-side register-control path so frequency, amplitude, phase, waveform, and output enable can be changed without recompiling FPGA logic.

## Key Files

```text
D:\FPGA\ad9144_bringup_k325t\docs\ad9144_uart_control_protocol.md
D:\FPGA\ad9144_bringup_k325t\docs\next_board_session_checklist.md
D:\FPGA\ad9144_bringup_k325t\rtl\awg\uart_rx.v
D:\FPGA\ad9144_bringup_k325t\rtl\awg\uart_tx.v
D:\FPGA\ad9144_bringup_k325t\rtl\awg\ad9144_uart_reg_bridge.v
D:\FPGA\ad9144_bringup_k325t\constraints\awg_uart_k325t.xdc
D:\FPGA\ad9144_bringup_k325t\tools\awg_uart_control.py
```

## Build And Program

Build:

```powershell
& D:\vivado\Vivado\2024.1\bin\vivado.bat -mode batch -tempDir C:/tmp/vivado_awg_uart_temp -journal C:/tmp/vivado_awg_uart.jou -log C:/tmp/vivado_awg_uart.log -source D:\FPGA\ad9144_bringup_k325t\scripts\build_awg_uart_direct.tcl
```

Program:

```powershell
& D:\vivado\Vivado\2024.1\bin\vivado.bat -mode batch -source D:\FPGA\ad9144_bringup_k325t\scripts\program_awg_uart.tcl
```

Generated bit:

```text
D:\FPGA\ad9144_bringup_k325t\vivado_awg_uart\top_awg_uart.bit
```

## UART Protocol

- 115200 baud, 8N1.
- Read: `R <addr_hex_2>`.
- Write: `W <addr_hex_2> <data_hex_8>`.
- Expected ID: `R 00` returns `D 41574731`.
- Enable register control: `W 08 00000003`.
- Return to button control: `W 08 00000001`.

## Host Smoke Test

After programming, wait 12-15 seconds for AD9144 startup.

```powershell
python D:\FPGA\ad9144_bringup_k325t\tools\awg_uart_control.py --port COM3 status
python D:\FPGA\ad9144_bringup_k325t\tools\awg_uart_control.py --port COM3 preset --frequency 50000000 --amplitude 0x6000 --wave sine
```

If the COM port is not `COM3`, list ports:

```powershell
Get-PnpDevice -PresentOnly -Class Ports
```

## Status

- UART bit generated on 2026-05-07.
- Bitstream write succeeded.
- Build log has a non-blocking `blk_mem_gen_0` locked-IP critical warning.
- Timing is not final-clean: route log reports setup violations around `WNS=-3.330ns`, `TNS=-3948.764ns`; hold is clean.
- Use this as a controlled bring-up artifact, then clean CDC/reset/debug timing before final competition measurements.

## 2026-05-07 Board Check

- Board was powered and JTAG was visible as `USB Serial Converter`, `VID_0403&PID_6014`, serial `210512180081`.
- `top_awg_uart.bit` was programmed successfully.
- Vivado reported `End of startup status: HIGH`.
- Vivado detected 3 ILA cores and 1 VIO core; missing probe-file warnings only affect debug signal names.
- No Windows `COM` port was present after programming. `Win32_SerialPort` and `[System.IO.Ports.SerialPort]::GetPortNames()` returned empty.
- Next action is physical: connect or enable a USB-UART adapter to the K325T UART pins (`uart_rxd=T23`, `uart_txd=T22`). After that, run `status` and expect `ID=0x41574731`.

## 2026-05-07 CH340 Validation

- CH340 enumerated as `USB-SERIAL CH340 (COM7)`.
- Board was power-cycled, so the fixed UART bit was reprogrammed over JTAG.
- First UART bridge build responded, but every other byte was skipped:
  - `D 41574731` appeared as `D4543`
  - `OK` appeared as `O`
- Root cause:
  - `ST_SEND` advanced before `uart_tx` had accepted the byte.
  - readback captured synchronous `cfg_rdata` one clock too early.
- Fix:
  - Added `ST_SEND_BUSY` and `ST_SEND_IDLE`.
  - Added `ST_RD_CAPTURE`.
  - Added static checks so this does not regress silently.
- Rebuilt and programmed `top_awg_uart.bit`; Vivado startup status was `HIGH`.
- Raw UART checks now pass:
  - `R 00` -> `D 41574731`
  - `R 04` -> `D 20260507`
  - `W 08 00000003` -> `OK`
  - `R 08` -> `D 00000003`
- Host tool checks pass:
  - `status` reports `ID=0x41574731`.
  - `preset --frequency 50000000 --amplitude 0x6000 --wave sine` enables register control.
  - Final readback: `CONTROL=0x00000003`, `PHASE_INC=0x0CCCCCCCCCCD`, `AMPLITUDE=0x6000`, `WAVE_MODE=0`.
- Current board state after this check: fixed UART bit is loaded, register control is enabled, and output is configured as 50 MHz sine at amplitude `0x6000`.
- User confirmed OUT1 shows a normal 50 MHz sine wave with this configuration.

## UART Panel

First GUI panel:

```text
D:\FPGA\ad9144_bringup_k325t\tools\awg_uart_panel.py
```

Launch:

```powershell
python D:\FPGA\ad9144_bringup_k325t\tools\awg_uart_panel.py
```

The panel can refresh COM ports, read status, apply a frequency/amplitude/phase/waveform preset, turn output off, and return to button control.

Validation:

```text
python -m py_compile ... -> pass
python awg_uart_panel.py --smoke -> AWG_UART_PANEL_IMPORT_OK
Port enumeration -> COM7
UART status -> ID=0x41574731
```

## Vivado Thread Setting

Shared scripts now set Vivado to 8 threads by default on this i7-11800H machine:

```text
D:\FPGA\scripts\vivado_threads.tcl
D:\FPGA\ad9144_bringup_k325t\scripts\vivado_threads.tcl
```

Override before running Vivado:

```powershell
$env:AWG_VIVADO_MAX_THREADS = "4"
```

Batch verification printed `AWG_VIVADO_MAX_THREADS=8`, `AWG_VIVADO_JOBS=8`, and `VIVADO_GENERAL_MAXTHREADS=8`.
