# AWG Scope Measurement Workflow Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn ad-hoc oscilloscope observations into repeatable measurement CSVs and short Markdown reports for the AD9144 AWG bring-up.

**Architecture:** Keep UART sweep generation separate from human measurement entry. Add a small Python utility that creates blank scope measurement templates from known profiles or existing UART sweep CSVs, and can summarize filled measurements into Markdown.

**Tech Stack:** Python 3 standard library, existing UART sweep CSV files, Markdown docs.

---

### Task 1: Scope Measurement Tool

**Files:**
- Create: `D:\FPGA\ad9144_bringup_k325t\tools\awg_scope_measurement.py`

- [x] **Step 1: Define measurement columns**

Use stable CSV columns: timestamp, source profile, target frequency, target amplitude, target wave, expected phase increment, measured frequency, Vpp, Vrms, trigger stability, visible distortion, and notes.

- [x] **Step 2: Add template generation**

Support built-in profiles: `freq_response`, `high_freq_detail`, `amplitude_linearity`, and `wave_modes`.

- [x] **Step 3: Add import from UART sweep CSV**

Allow `template --from-sweep <csv>` so PC-generated sweep records can become human-fillable measurement sheets.

- [x] **Step 4: Add Markdown summary**

Allow `report --input <csv> --out <md>` to create a concise table of target versus measured observations.

### Task 2: Measurement Documentation

**Files:**
- Create: `D:\FPGA\ad9144_bringup_k325t\docs\awg_scope_measurement.md`
- Modify: `D:\FPGA\AGENTS.md`
- Modify: `D:\awg_fpga\obsidian\02-模块设计\AD9144 UART Control.md`

- [x] **Step 1: Record how to use the tool**

Document generation, filling, and report commands.

- [x] **Step 2: Record the current board observation**

Write that frequency, amplitude, and waveform switching were observed on OUT1, and that the 400 MHz frequency jumping was confirmed to be oscilloscope-side, not FPGA register instability.

### Task 3: Verification And Commit

- [x] **Step 1: Verify Python syntax**

Run `python -m py_compile D:\FPGA\ad9144_bringup_k325t\tools\awg_scope_measurement.py`.

- [x] **Step 2: Generate a template from the latest sweep**

Run template generation from `scope_freq_response_rerun_20260507_1305.csv` into `measurements\scope_templates`.

- [x] **Step 3: Generate a Markdown report**

Run report generation on the template to verify output formatting.

- [ ] **Step 4: Commit and push**

Commit only source/docs/plan changes. Leave generated measurement CSV and report files untracked unless explicitly requested.
