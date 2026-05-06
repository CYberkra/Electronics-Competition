# AD9144 UART Control Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a non-destructive UART control path for the AD9144 AWG demo so the next board session can switch from button control to PC-controlled frequency, amplitude, phase, waveform, and output enable.

**Architecture:** Keep the existing AD9144 button bitstream path intact. Add an `AWG_UART_CONTROL` compile-time variant that exposes `uart_rxd/uart_txd`, parses simple ASCII register commands, and drives the existing `ad9144_awg_reg_bank` interface.

**Tech Stack:** Verilog RTL, Vivado 2024.1 batch Tcl, PowerShell static checks, Python 3 host utility with optional `pyserial`.

---

### Task 1: Protocol and Bring-Up Docs

**Files:**
- Create: `D:\FPGA\ad9144_bringup_k325t\docs\ad9144_uart_control_protocol.md`
- Create: `D:\FPGA\ad9144_bringup_k325t\docs\next_board_session_checklist.md`
- Modify: `D:\FPGA\AGENTS.md`

- [x] **Step 1: Define the register-line protocol**

Use fixed ASCII lines at 115200-8N1:

```text
W 08 00000003
R 0C
```

Expected responses:

```text
OK
D 00000033
ERR
```

- [x] **Step 2: Document tomorrow's board flow**

The checklist must include power, JTAG/UART cables, program bitstream, wait 12-15 seconds, measure OUT1, then enable register control from the PC.

### Task 2: FPGA UART Register Bridge

**Files:**
- Create: `D:\FPGA\ad9144_bringup_k325t\rtl\awg\uart_rx.v`
- Create: `D:\FPGA\ad9144_bringup_k325t\rtl\awg\uart_tx.v`
- Create: `D:\FPGA\ad9144_bringup_k325t\rtl\awg\ad9144_uart_reg_bridge.v`
- Modify: `D:\FPGA\ad9144_bringup_k325t\variants\awg_button\top.v`

- [x] **Step 1: Add synthesizable UART RX/TX primitives**

Implement 8N1 RX/TX with integer `CLK_HZ / BAUD` timing.

- [x] **Step 2: Add ASCII register bridge**

Parse `W aa dddddddd` and `R aa`, drive one-cycle `cfg_wr_en` / `cfg_rd_en`, and return `OK`, `D dddddddd`, or `ERR`.

- [x] **Step 3: Wire through `AWG_UART_CONTROL` only**

Default button builds must keep `cfg_wr_en=0`, `cfg_rd_en=0`, and have no UART top-level ports.

### Task 3: Vivado Variant Scripts

**Files:**
- Modify: `D:\FPGA\ad9144_bringup_k325t\scripts\create_awg_button_project.tcl`
- Create: `D:\FPGA\ad9144_bringup_k325t\constraints\awg_uart_k325t.xdc`
- Create: `D:\FPGA\ad9144_bringup_k325t\scripts\create_awg_uart_project.tcl`
- Create: `D:\FPGA\ad9144_bringup_k325t\scripts\synth_awg_uart_direct.tcl`
- Create: `D:\FPGA\ad9144_bringup_k325t\scripts\build_awg_uart_direct.tcl`
- Create: `D:\FPGA\ad9144_bringup_k325t\scripts\program_awg_uart.tcl`

- [x] **Step 1: Parameterize the existing project creator**

Allow separate project name, project directory, extra constraints, and Verilog defines.

- [x] **Step 2: Add UART pins**

Use `uart_rxd -> T23`, `uart_txd -> T22`, `LVCMOS33`.

- [x] **Step 3: Build UART bitstream with `C:/tmp` temp dir**

Use the known workaround for Vivado `.Xil/.../straps.rtd` cleanup issues.

### Task 4: PC Host Utility

**Files:**
- Create: `D:\FPGA\ad9144_bringup_k325t\tools\awg_uart_control.py`

- [x] **Step 1: Implement register read/write commands**

Support `read`, `write`, `status`, and `preset`.

- [x] **Step 2: Implement AWG high-level commands**

Translate frequency to 48-bit phase increment using `sample_rate=1_000_000_000` by default.

### Task 5: Verification and Commit

**Files:**
- Create: `D:\FPGA\ad9144_bringup_k325t\scripts\check_awg_uart_control_wiring.ps1`
- Modify: `D:\FPGA\AGENTS.md`
- Modify: `D:\awg_fpga\obsidian` if present and writable

- [x] **Step 1: Run static checks**

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File D:\FPGA\ad9144_bringup_k325t\scripts\check_awg_button_sequence.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File D:\FPGA\ad9144_bringup_k325t\scripts\check_awg_waveform_modes.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File D:\FPGA\ad9144_bringup_k325t\scripts\check_awg_register_debug_wiring.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File D:\FPGA\ad9144_bringup_k325t\scripts\check_awg_uart_control_wiring.ps1
```

- [x] **Step 2: Run Vivado syntax/synthesis check**

Prefer:

```powershell
& D:\vivado\Vivado\2024.1\bin\vivado.bat -mode batch -tempDir C:/tmp/vivado_awg_uart_temp -journal C:/tmp/vivado_awg_uart.jou -log C:/tmp/vivado_awg_uart.log -source D:\FPGA\ad9144_bringup_k325t\scripts\build_awg_uart_direct.tcl
```

- [x] **Step 3: Commit and push `main`**

Commit only source, scripts, and docs. Do not add Vivado generated directories.

### Implementation Result

- UART bitstream generated: `D:\FPGA\ad9144_bringup_k325t\vivado_awg_uart\top_awg_uart.bit`
- Build log: `C:\tmp\vivado_awg_uart.log`
- `write_bitstream completed successfully`
- Timing caveat: routed build still reports setup violations (`WNS=-3.330ns`, `TNS=-3948.764ns`), so this remains a bring-up/demo bit until CDC/reset/debug timing cleanup is completed.
- Main branch commit: `a8cc9c1` (`feat: add AD9144 UART control variant`)
