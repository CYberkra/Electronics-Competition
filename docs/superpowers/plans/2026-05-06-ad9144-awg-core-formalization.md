# AD9144 AWG Core Formalization Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn the verified AD9144 OUT1 frequency/amplitude button demo into a reusable AWG datapath with visible waveform modes and internal observability.

**Architecture:** Keep the vendor AD9144/JESD/LMK/SPI bring-up path intact and isolate only the waveform-generation section behind a clean module boundary. The first deliverable is still hardware-visible on OUT1, while scripts verify DDS constants, packer byte order, waveform selection, and debug signal wiring before bitstream generation.

**Tech Stack:** Vivado 2024.1 Enterprise, Verilog, Xilinx 7-series JESD204 IP, PowerShell regression checks, K325T + FMCADDA-9250-9144 hardware.

---

## File Structure

- Modify: `D:\FPGA\ad9144_bringup_k325t\rtl\awg\ad9144_awg_dds4.v`
  - Extend the verified four-sample DDS source with a `wave_mode` input and non-sine waveform generation.
- Modify: `D:\FPGA\ad9144_bringup_k325t\rtl\awg\ad9144_sample_packer.v`
  - Keep the current AD9144 vendor byte order stable.
- Modify: `D:\FPGA\ad9144_bringup_k325t\variants\awg_button\top.v`
  - Add a `wave_sel` register and route it to `ad9144_awg_dds4`.
- Modify: `D:\FPGA\ad9144_bringup_k325t\scripts\check_awg_button_sequence.ps1`
  - Add static checks for waveform mode wiring and keep existing DDS/packer checks.
- Modify: `D:\FPGA\AGENTS.md`
  - Record hardware observations and the next known-good bitstream after every board-visible milestone.

## Task 1: Preserve Current Hardware Baseline

**Files:**
- Modify: `D:\FPGA\AGENTS.md`

- [ ] **Step 1: Record board observation**

Add a note that `top_awg_button.bit` was programmed successfully, AD9144 `OUT1` is present, and frequency/amplitude button changes were observed on the oscilloscope.

- [ ] **Step 2: Verify the current bitstream path exists**

Run:

```powershell
Get-Item -LiteralPath D:\FPGA\ad9144_bringup_k325t\vivado_awg_button\top_awg_button.bit
```

Expected: the file exists and has a recent `LastWriteTime`.

- [ ] **Step 3: Commit the baseline documentation**

Run:

```powershell
git -C D:\FPGA add AGENTS.md docs/superpowers/plans/2026-05-06-ad9144-awg-core-formalization.md
git -C D:\FPGA commit -m "docs: record AD9144 AWG button baseline"
```

Expected: commit succeeds without staging generated Vivado output directories.

## Task 2: Add Waveform Mode Wiring Check

**Files:**
- Modify: `D:\FPGA\ad9144_bringup_k325t\scripts\check_awg_button_sequence.ps1`

- [ ] **Step 1: Add expected wiring assertions**

Add checks that fail unless `top.v` declares a `wave_sel` register, wires `wave_mode` into `ad9144_awg_dds4`, and keeps the existing DDS4 and sample packer instances.

- [ ] **Step 2: Run the check before RTL changes**

Run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File D:\FPGA\ad9144_bringup_k325t\scripts\check_awg_button_sequence.ps1
```

Expected before Task 3: failure mentioning missing `wave_sel` or `wave_mode` wiring.

## Task 3: Add Sine/Square/Triangle/Saw Mode in DDS4

**Files:**
- Modify: `D:\FPGA\ad9144_bringup_k325t\rtl\awg\ad9144_awg_dds4.v`
- Modify: `D:\FPGA\ad9144_bringup_k325t\variants\awg_button\top.v`

- [ ] **Step 1: Extend the module interface**

Add this port to `ad9144_awg_dds4`:

```verilog
input wire [1:0] wave_mode,
```

Use this mapping:

```text
0 = sine
1 = square
2 = triangle
3 = saw
```

- [ ] **Step 2: Generate four raw waveform samples**

For each of `phase0` through `phase3`, derive the existing 12-bit ROM address and choose the raw sample by `wave_mode`:

```text
sine     = sine_rom[address]
square   = phase[47] ? -32768 : 32767
triangle = linear rise/fall from the upper address bits
saw      = linear ramp from -32768 to +32752
```

- [ ] **Step 3: Keep the existing scale/offset pipeline**

Feed the selected raw waveform samples into the existing multiply, offset, saturate, and valid pipeline. Do not change `ad9144_sample_packer.v` byte order.

- [ ] **Step 4: Add `wave_sel` control in top**

Add `wave_sel` in `top.v`. Long-press cycles `ui_mode` through frequency, amplitude, phase, and waveform:

```text
0 = frequency
1 = amplitude
2 = phase
3 = waveform
```

In waveform mode, `KEY0` increments `wave_sel` and `KEY1` decrements it. The two-bit wrap order is sine, square, triangle, saw.

## Task 4: Verify and Rebuild

**Files:**
- Modify: `D:\FPGA\ad9144_bringup_k325t\scripts\check_awg_button_sequence.ps1`
- Verify: `D:\FPGA\ad9144_bringup_k325t\vivado_awg_button\top_awg_button.bit`

- [ ] **Step 1: Run the static regression check**

Run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File D:\FPGA\ad9144_bringup_k325t\scripts\check_awg_button_sequence.ps1
```

Expected: `AWG button DDS4 wiring check PASS`.

- [ ] **Step 2: Build bitstream**

Run:

```powershell
& D:\vivado\Vivado\2024.1\bin\vivado.bat -mode batch -source D:\FPGA\ad9144_bringup_k325t\scripts\build_awg_button_direct.tcl
```

Expected: `write_bitstream completed successfully`.

- [ ] **Step 3: Program and observe OUT1**

Run:

```powershell
& D:\vivado\Vivado\2024.1\bin\vivado.bat -mode batch -source D:\FPGA\ad9144_bringup_k325t\scripts\program_awg_button.tcl
```

Expected: `End of startup status: HIGH`. After 12-15 seconds, OUT1 should still show the known-good sine output and frequency/amplitude buttons should still work.

## 2026-05-07 Follow-Up: Register Skeleton and Debug ILA

Implemented after the waveform-mode demo was hardware-confirmed:

- Added `D:\FPGA\ad9144_bringup_k325t\rtl\awg\ad9144_awg_reg_bank.v`.
- Added `D:\FPGA\ad9144_bringup_k325t\docs\awg_register_map.md`.
- Integrated the register bank in `D:\FPGA\ad9144_bringup_k325t\variants\awg_button\top.v` with `cfg_wr_en=0` and `cfg_rd_en=0`, so the verified button path remains active by default.
- Added source-level debug buses for control state, samples, final JESD TX data, phase increment, and phase offset.
- Added `D:\FPGA\ad9144_bringup_k325t\scripts\build_awg_button_debug.tcl`.
- Added `D:\FPGA\ad9144_bringup_k325t\scripts\capture_awg_button_debug.tcl`.
- Added `D:\FPGA\ad9144_bringup_k325t\scripts\check_awg_register_debug_wiring.ps1`.

Verification command:

```powershell
& D:\vivado\Vivado\2024.1\bin\vivado.bat -mode batch -tempDir C:/tmp/vivado_awg_debug_temp -journal C:/tmp/vivado_awg_button_debug.jou -log C:/tmp/vivado_awg_button_debug.log -source D:\FPGA\ad9144_bringup_k325t\scripts\build_awg_button_debug.tcl
```

Result:

- Debug bit generated: `D:\FPGA\ad9144_bringup_k325t\vivado_awg_button\top_awg_button_debug.bit`
- Debug probes generated: `D:\FPGA\ad9144_bringup_k325t\vivado_awg_button\top_awg_button_debug.ltx`
- Extra AWG debug nets connected: `384`
- Timestamp after re-verify: 2026-05-07 02:31.
- Timing still not clean: about `WNS=-3.181ns`, so use this only as a debug/bring-up bit.
- Note: a restricted agent sandbox can falsely report missing Vivado license because it cannot read `C:\Users\17844\AppData\Roaming\XilinxLicense\Xlnx_2024.lic`. Also, direct launches from `D:\FPGA` may fail after successful synthesis on `.Xil/.../straps.rtd` cleanup; using `C:/tmp` for `-tempDir`, log, and journal avoids that failure.
