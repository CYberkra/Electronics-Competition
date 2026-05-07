# AWG GUI Sweep And Wave Quality Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add PC-side checks that can be run while the oscilloscope is unavailable: one-click UART sweep logging from the GUI and a digital waveform FFT self-check.

**Architecture:** Keep the FPGA bitstream unchanged. Reuse the existing UART register protocol for repeatable sweep CSV capture, and model `ad9144_awg_dds4.v` in Python with the same sine ROM, waveform modes, amplitude scaling, and saturation behavior.

**Tech Stack:** Python 3, Tkinter, pyserial, numpy, Vivado-generated RTL assets.

---

### Task 1: Reusable UART Sweep API

**Files:**
- Modify: `D:\FPGA\ad9144_bringup_k325t\tools\awg_uart_sweep.py`

- [x] **Step 1: Add a programmatic helper**

Add `run_profile(...)` so GUI code can run the same sweep logic without fabricating CLI arguments by hand.

- [x] **Step 2: Keep CLI behavior stable**

`main()` still parses the same options and prints `SWEEP_CSV=<path>`.

- [x] **Step 3: Verify dry-run**

Run:
```powershell
python D:\FPGA\ad9144_bringup_k325t\tools\awg_uart_sweep.py --dry-run --out C:\tmp\awg_sweep_api_verify.csv
```

Expected: exit 0 and CSV with quick profile rows.

### Task 2: GUI One-Click Sweep

**Files:**
- Modify: `D:\FPGA\ad9144_bringup_k325t\tools\awg_uart_panel.py`
- Modify: `D:\FPGA\ad9144_bringup_k325t\docs\awg_uart_panel.md`

- [x] **Step 1: Add sweep controls**

Add sweep profile selection, CSV path entry, and a `Run Sweep` button.

- [x] **Step 2: Run sweep in the existing worker thread**

Call `run_profile(...)`, restore 50 MHz sine by default, then refresh the status panel.

- [x] **Step 3: Verify GUI imports**

Run:
```powershell
python D:\FPGA\ad9144_bringup_k325t\tools\awg_uart_panel.py --smoke
```

Expected: `AWG_UART_PANEL_IMPORT_OK`.

### Task 3: Digital Waveform FFT Self-Check

**Files:**
- Create: `D:\FPGA\ad9144_bringup_k325t\tools\awg_wave_quality.py`
- Create: `D:\FPGA\ad9144_bringup_k325t\docs\awg_wave_quality.md`

- [x] **Step 1: Model the RTL output path**

Load `ad9144_sine_4096.hex`, generate four samples per beat, implement sine/square/triangle/saw modes, Q15 amplitude scaling, offset addition, and signed 16-bit saturation.

- [x] **Step 2: Add FFT metrics**

Report fundamental bin, fundamental frequency, THD over harmonics 2-5, and largest non-harmonic spur for each profile point.

- [x] **Step 3: Verify default run**

Run:
```powershell
python D:\FPGA\ad9144_bringup_k325t\tools\awg_wave_quality.py --profile quick --out D:\FPGA\ad9144_bringup_k325t\reports\wave_quality\quick_latest.csv
```

Expected: exit 0 and CSV rows for 10 MHz, 50 MHz, and 100 MHz sine.

### Task 4: Durable Notes And Commit

**Files:**
- Modify: `D:\FPGA\AGENTS.md`
- Modify: `D:\awg_fpga\obsidian\02-模块设计\AD9144 UART Control.md`

- [x] **Step 1: Record the commands and caveats**

Document GUI sweep usage, wave-quality limitations, output paths, and the current no-scope workflow.

- [x] **Step 2: Run verification**

Run `py_compile`, GUI smoke, sweep dry-run, wave-quality quick run, and git diff checks.

- [x] **Step 3: Commit and push**

Commit tracked source/docs changes to `main`. Leave generated measurement CSVs and Vivado outputs untracked.
