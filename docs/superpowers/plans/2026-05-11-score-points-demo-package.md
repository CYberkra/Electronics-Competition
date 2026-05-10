# Score Points Demo Package Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [x]`) syntax for tracking.

**Goal:** Build a competition-oriented demo and measurement package for the existing K325T + AD9144 hardware so the team can earn points from system completeness, repeatable control, and quantified reporting even without buying new analog hardware.

**Architecture:** Keep the hardware data path unchanged. Add host-side demo presets, a repeatable measurement report template, and documentation that maps each achievable scoring item to a concrete test or artifact.

**Tech Stack:** Python 3 host tools, Tkinter GUI, PowerShell/Vivado verification scripts, Markdown reports.

---

## File Structure

- Modify `ad9144_bringup_k325t/tools/awg_uart_control.py`: add named competition demo presets and a dry-run capable `demo` command.
- Modify `ad9144_bringup_k325t/tools/awg_uart_panel.py`: expose the same demo presets in the GUI without changing the existing manual controls.
- Create `ad9144_bringup_k325t/docs/competition_measurement_report.md`: fillable report for measured frequency, Vpp, waveform modes, calibration, and limitations.
- Create `docs/competition/score_recovery_strategy.md`: project-level strategy for scoring with fixed hardware.
- Modify `ad9144_bringup_k325t/README.md`: add a short competition demo entry point.

### Task 1: CLI Demo Presets

**Files:**
- Modify: `ad9144_bringup_k325t/tools/awg_uart_control.py`

- [x] Add a `DEMO_PRESETS` table with fixed names, frequency, amplitude, phase, wave, and notes.
- [x] Refactor preset application into a reusable function.
- [x] Add `demo --list`, `demo --dry-run`, and `demo <name>` subcommands.
- [x] Verify with `python ad9144_bringup_k325t/tools/awg_uart_control.py demo --list` and `python ad9144_bringup_k325t/tools/awg_uart_control.py demo baseline_50m --dry-run`.

### Task 2: GUI Demo Presets

**Files:**
- Modify: `ad9144_bringup_k325t/tools/awg_uart_panel.py`

- [x] Import `DEMO_PRESETS`.
- [x] Add a `Demo Preset` combobox and `Load Demo` button that fills the manual fields.
- [x] Keep `Apply Preset` as the only hardware-write action so users can inspect values before applying.
- [x] Verify with `python ad9144_bringup_k325t/tools/awg_uart_panel.py --smoke`.

### Task 3: Measurement And Scoring Docs

**Files:**
- Create: `ad9144_bringup_k325t/docs/competition_measurement_report.md`
- Create: `docs/competition/score_recovery_strategy.md`
- Modify: `ad9144_bringup_k325t/README.md`

- [x] Write a measurement checklist that maps each demo preset to oscilloscope observations.
- [x] Add tables for measured frequency, Vpp, visible distortion, calibration before/after, and final claims.
- [x] Write a score recovery strategy that explicitly separates achieved, partially achieved, and limited-by-hardware items.
- [x] Link both docs from the bring-up README.

### Task 4: Verification And Commit

**Files:**
- All modified files above.

- [x] Run Python compile checks for host tools.
- [x] Run GUI smoke check.
- [x] Run CLI dry-run checks.
- [x] Run `git diff --check`.
- [x] Commit and push branch for review or merge to main if requested.
