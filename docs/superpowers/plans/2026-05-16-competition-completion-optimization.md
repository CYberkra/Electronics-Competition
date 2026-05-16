# Competition Completion Optimization Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn the current K325T + AD9144 AWG prototype into the strongest contest-ready deliverable possible on the fixed hardware by improving code reliability, UI workflow, FPGA logic coverage, measurement evidence, and final presentation assets.

**Architecture:** Preserve the verified chain `PC Qt GUI/CLI -> CH340 UART -> K325T register bank -> DDS4/waveform/calibration logic -> JESD204 TX -> AD9144 OUT1`. Add a competition workflow layer above the existing control tools, add missing FPGA capabilities where they directly support the problem statement, and create a repeatable evidence package so every contest claim maps to code, readback, measurement, or an explicit hardware limitation.

**Tech Stack:** Vivado 2024.1 Enterprise, Verilog RTL, PowerShell/Tcl build scripts, Python 3, PySide6, pyqtgraph, pyserial, unittest, Markdown documentation.

---

## Current Review Snapshot

This plan was written against branch `codex/upper-host-smoke-checks` at commit `12aba67`, with PR #5 open against `main`.

Execution note: at the user's request, implementation starts on an isolated branch based on `12aba67` before PR #5 is merged. This keeps `main`, `codex/upper-host-smoke-checks`, and other collaborators' branches untouched while preserving the option to merge or rebase later.

Fresh no-hardware checks run during review:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File ad9144_bringup_k325t\scripts\check_upper_host.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File ad9144_bringup_k325t\scripts\check_awg_uart_control_wiring.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File ad9144_bringup_k325t\scripts\check_awg_waveform_modes.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File ad9144_bringup_k325t\scripts\check_awg_register_debug_wiring.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File ad9144_bringup_k325t\scripts\check_awg_button_sequence.ps1
```

Observed review facts:

- `check_upper_host.ps1` prints `UPPER_HOST_CHECK_OK`; 4 backend tests pass.
- UART, waveform, register/debug, and button static wiring checks pass.
- `check_awg_waveform_modes.ps1` reports that the local generated button bitstream is absent, but static waveform-mode wiring passes.
- `ad9144_bringup_k325t/upper_host/main.py` is 1357 lines and mixes app shell, pages, widgets, settings, background task handling, and smoke logic.
- `ad9144_bringup_k325t/variants/awg_button/top.v` is 969 lines and remains the high-risk integration file.
- `sim/work/run_awg_core_sim.ps1`, `sim/work/run_awg_key_ui_ctrl_sim.ps1`, and `sim/work/run_awg_led_status_sim.ps1` still hardcode old `D:\awg_fpga` paths.
- The contest statement requires at least 5 GSa/s, 1 GHz bandwidth, 14-bit resolution, 1 mHz frequency resolution, sweep, amplitude range/flatness, THD, and non-harmonic spur evidence.
- The current fixed hardware path should not be claimed as full 5 GSa/s / 1 GHz analog compliance without credible measurement. The strongest honest position is a complete AWG prototype with verified digital control, JESD204 DAC output, guided GUI operation, calibration workflow, and documented hardware boundary.

---

## Optimization Matrix

| Area | Current Strength | Main Gap | Target Optimization |
|---|---|---|---|
| FPGA datapath | OUT1 responds to UART-controlled frequency, amplitude, and waveform changes | Fixed shape modes only; no true user waveform RAM; sweep mostly host/script driven | Add uploadable waveform RAM mode and a hardware sweep engine |
| Register/UART logic | ID/version/status/read-write path works | Register map needs growth without breaking old tools | Versioned register map, compatibility aliases, register-map tests |
| Timing/release confidence | Demo bit can be generated and observed | Timing history includes negative WNS in some builds | Add timing report parser, reset/CDC cleanup, release gate |
| Upper-host UI | PySide6 GUI exists with dashboard/control/measurement/calibration pages | No contest-focused guided flow; main window file is too large | Split UI into pages and add a guided competition workflow page |
| Measurements | CSV templates, digital QA, calibration generator exist | Filled analog evidence and before/after calibration proof are missing | Session-based measurement package with required evidence rows |
| Documentation | AGENTS/README/handoff docs are useful | Some docs are stale or absolute-path-heavy; claims need stronger evidence links | One source-of-truth contest evidence index and final claim table |
| Packaging | PyInstaller script exists | No release manifest tying EXE, bitstream, commit, and measurements together | Build a release package manifest and checklist |

---

## File Structure

### New Files

- `scripts/check_project_health.ps1`: top-level no-hardware health gate that calls upper-host checks and FPGA static checks.
- `ad9144_bringup_k325t/upper_host/app.py`: thin application bootstrap and `QApplication` setup.
- `ad9144_bringup_k325t/upper_host/widgets.py`: reusable cards, state pills, preview tables, and plotting widgets.
- `ad9144_bringup_k325t/upper_host/pages/dashboard.py`: dashboard page.
- `ad9144_bringup_k325t/upper_host/pages/control.py`: manual control and demo preset page.
- `ad9144_bringup_k325t/upper_host/pages/measurements.py`: scope template/report/wave-quality page.
- `ad9144_bringup_k325t/upper_host/pages/calibration.py`: calibration table editor/dump/load page.
- `ad9144_bringup_k325t/upper_host/pages/competition.py`: guided contest demo workflow page.
- `ad9144_bringup_k325t/upper_host/demo_session.py`: typed model for demo steps, expected observations, and evidence status.
- `ad9144_bringup_k325t/upper_host/evidence.py`: evidence artifact index, screenshot/CSV registration, and claim table export.
- `ad9144_bringup_k325t/tools/awg_waveform_file.py`: parse CSV/TXT/COE waveform files into signed 16-bit samples.
- `ad9144_bringup_k325t/rtl/awg/ad9144_wave_ram.v`: uploadable 4096-entry waveform RAM.
- `ad9144_bringup_k325t/rtl/awg/ad9144_sweep_engine.v`: register-controlled linear/log-style phase-increment sweep controller.
- `ad9144_bringup_k325t/rtl/awg/tb_ad9144_wave_ram.v`: waveform RAM simulation.
- `ad9144_bringup_k325t/rtl/awg/tb_ad9144_sweep_engine.v`: sweep engine simulation.
- `ad9144_bringup_k325t/scripts/check_timing_report.ps1`: parse Vivado timing summaries and fail release gates on negative WNS unless explicitly allowed.
- `ad9144_bringup_k325t/scripts/build_release_package.ps1`: create a local release package with manifest, source commit, EXE path, bitstream path, and evidence files.
- `docs/competition/evidence_index.md`: contest claim-to-evidence table.
- `docs/competition/final_validation_checklist.md`: board, scope, GUI, and documentation validation sequence.

### Modified Files

- `ad9144_bringup_k325t/upper_host/main.py`: reduce to a compatibility wrapper that imports `app.main`.
- `ad9144_bringup_k325t/upper_host/backend.py`: keep hardware and file operations, move UI-free session/evidence logic to new modules.
- `ad9144_bringup_k325t/tools/awg_uart_control.py`: add waveform upload and sweep-control subcommands.
- `ad9144_bringup_k325t/tools/awg_scope_measurement.py`: add evidence session identifiers and required contest fields.
- `ad9144_bringup_k325t/rtl/awg/ad9144_awg_dds4.v`: add uploaded-waveform mode and sweep phase input.
- `ad9144_bringup_k325t/rtl/awg/ad9144_awg_reg_bank.v`: add waveform upload, sweep, evidence-friendly status, and register-map version fields.
- `ad9144_bringup_k325t/rtl/awg/ad9144_uart_reg_bridge.v`: route new register writes and support waveform table writes.
- `ad9144_bringup_k325t/variants/awg_button/top.v`: instantiate waveform RAM and sweep engine while preserving the existing button fallback.
- `ad9144_bringup_k325t/docs/ad9144_uart_control_protocol.md`: update the register map and examples.
- `ad9144_bringup_k325t/docs/awg_register_map.md`: update register map with compatibility notes.
- `ad9144_bringup_k325t/README.md`, `ad9144_bringup_k325t/AGENTS.md`, `README.md`: link the health gate, competition workflow, and release checklist.
- `docs/competition/design_document.md`: align protocol, UI, measurement, and limitations with current implementation.
- `docs/competition/video_script.md`: update the final demonstration sequence.
- `sim/work/run_awg_core_sim.ps1`, `sim/work/run_awg_key_ui_ctrl_sim.ps1`, `sim/work/run_awg_led_status_sim.ps1`: remove old absolute paths.

---

## Phase 0: Baseline And Mainline Hygiene

### Task 0.1: Merge The Existing Upper-Host Smoke PR

**Files:**
- No source file changes.

- [ ] **Step 1: Confirm PR #5 is clean**

Run:

```powershell
gh pr view 5 --json state,mergeStateStatus,mergeable,statusCheckRollup,headRefName,baseRefName
```

Expected:

```text
"state": "OPEN"
"mergeStateStatus": "CLEAN"
"mergeable": "MERGEABLE"
"headRefName": "codex/upper-host-smoke-checks"
"baseRefName": "main"
```

- [ ] **Step 2: Re-run the PR health check**

Run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File ad9144_bringup_k325t\scripts\check_upper_host.ps1
```

Expected:

```text
UPPER_HOST_CHECK_OK
Ran 4 tests
OK
```

- [ ] **Step 3: Merge PR #5**

Run:

```powershell
gh pr merge 5 --merge
git fetch origin --prune
git log --oneline --decorate -3 origin/main
```

Expected: `origin/main` contains a merge commit for PR #5.

- [ ] **Step 4: Create a new optimization branch**

Run:

```powershell
git checkout -b codex/competition-completion-optimization origin/main
```

Expected: branch switches to `codex/competition-completion-optimization` with a clean worktree.

### Task 0.2: Add A Top-Level Project Health Gate

**Files:**
- Create: `scripts/check_project_health.ps1`
- Modify: `README.md`
- Modify: `AGENTS.md`

- [ ] **Step 1: Create the top-level health script**

Create `scripts/check_project_health.ps1` with this behavior:

```powershell
[CmdletBinding()]
param(
    [string]$Python = "python",
    [switch]$SkipQtSmoke,
    [switch]$SkipStaticRtl
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = Resolve-Path (Join-Path $ScriptDir "..")

Push-Location $RepoRoot
try {
    Write-Host "[health] Upper host"
    $upperArgs = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "ad9144_bringup_k325t\scripts\check_upper_host.ps1", "-Python", $Python)
    if ($SkipQtSmoke) {
        $upperArgs += "-SkipQtSmoke"
    }
    & powershell @upperArgs
    if ($LASTEXITCODE -ne 0) {
        throw "upper-host health check failed"
    }

    if (-not $SkipStaticRtl) {
        Write-Host "[health] AD9144 static RTL wiring"
        $checks = @(
            "check_awg_button_sequence.ps1",
            "check_awg_waveform_modes.ps1",
            "check_awg_register_debug_wiring.ps1",
            "check_awg_uart_control_wiring.ps1"
        )
        foreach ($check in $checks) {
            & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path "ad9144_bringup_k325t\scripts" $check)
            if ($LASTEXITCODE -ne 0) {
                throw "$check failed"
            }
        }
    }

    git diff --check
    if ($LASTEXITCODE -ne 0) {
        throw "git diff --check failed"
    }

    Write-Host "PROJECT_HEALTH_OK"
}
finally {
    Pop-Location
}
```

- [ ] **Step 2: Run the health script**

Run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\check_project_health.ps1
```

Expected:

```text
PROJECT_HEALTH_OK
```

- [ ] **Step 3: Document the health gate**

Add this command to `README.md` and `AGENTS.md`:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\check_project_health.ps1
```

- [ ] **Step 4: Commit**

Run:

```powershell
git add scripts/check_project_health.ps1 README.md AGENTS.md
git commit -m "test: add project health gate"
```

---

## Phase 1: Code Structure And Maintainability

### Task 1.1: Split The Qt Upper Host Into Focused Modules

**Files:**
- Create: `ad9144_bringup_k325t/upper_host/app.py`
- Create: `ad9144_bringup_k325t/upper_host/widgets.py`
- Create: `ad9144_bringup_k325t/upper_host/pages/__init__.py`
- Create: `ad9144_bringup_k325t/upper_host/pages/dashboard.py`
- Create: `ad9144_bringup_k325t/upper_host/pages/control.py`
- Create: `ad9144_bringup_k325t/upper_host/pages/measurements.py`
- Create: `ad9144_bringup_k325t/upper_host/pages/calibration.py`
- Modify: `ad9144_bringup_k325t/upper_host/main.py`
- Modify: `ad9144_bringup_k325t/launch_upper_host.py`
- Test: `ad9144_bringup_k325t/tests/test_upper_host_backend.py`

- [ ] **Step 1: Move reusable widgets**

Move these classes from `upper_host/main.py` to `upper_host/widgets.py` without behavior changes:

```python
class MetricCard(QFrame): ...
class StatePill(QLabel): ...
class PlotCard(QFrame): ...
class ListPreviewTable(QTableWidget): ...
```

Keep their public methods unchanged:

```python
MetricCard.set_value(value: str) -> None
MetricCard.set_subtitle(value: str) -> None
StatePill.set_state(text: str, *, on: bool = False, warn: bool = False, bad: bool = False) -> None
PlotCard.set_curve(x, y, *, title: str = "", subtitle: str = "") -> None
ListPreviewTable.load_csv(path: Path, limit: int = 200) -> None
```

- [ ] **Step 2: Move page classes**

Move each page class to its own file:

```text
DashboardPage -> pages/dashboard.py
ControlPage -> pages/control.py
MeasurementPage -> pages/measurements.py
CalibrationPage -> pages/calibration.py
```

Keep constructor signature `__init__(self, main: UpperHostWindow)` for each page.

- [ ] **Step 3: Move app shell**

Move `UpperHostWindow`, `ControlSettings`, `SignalHub`, `_std_icon`, `_open_path`, `_parse_optional_float`, `_read_csv_rows`, and `_write_csv_rows` to `upper_host/app.py`.

Make `upper_host/main.py` a compatibility wrapper:

```python
from __future__ import annotations

from .app import main

if __name__ == "__main__":
    raise SystemExit(main())
```

- [ ] **Step 4: Run the upper-host check**

Run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File ad9144_bringup_k325t\scripts\check_upper_host.ps1
```

Expected: `UPPER_HOST_CHECK_OK`.

- [ ] **Step 5: Commit**

Run:

```powershell
git add ad9144_bringup_k325t/upper_host ad9144_bringup_k325t/launch_upper_host.py
git commit -m "refactor: split upper host pages"
```

### Task 1.2: Remove Old Absolute Paths From Simulation Scripts

**Files:**
- Modify: `sim/work/run_awg_core_sim.ps1`
- Modify: `sim/work/run_awg_key_ui_ctrl_sim.ps1`
- Modify: `sim/work/run_awg_led_status_sim.ps1`

- [ ] **Step 1: Replace fixed root paths**

In each script, replace hardcoded assignments like:

```powershell
$vivado_bin = "D:\vivado\Vivado\2024.1\bin"
$rtl_dds = "D:\awg_fpga\rtl\dds"
$work_dir = "D:\awg_fpga\sim\work"
```

with root-derived paths:

```powershell
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = Resolve-Path (Join-Path $ScriptDir "..\..")
$vivado_bat = $env:VIVADO_PATH
if ([string]::IsNullOrWhiteSpace($vivado_bat)) {
    $vivado_bat = "D:\vivado\Vivado\2024.1\bin\vivado.bat"
}
$rtl_dds = Join-Path $RepoRoot "rtl\dds"
$rtl_dsp = Join-Path $RepoRoot "rtl\dsp"
$tb_dir = Join-Path $RepoRoot "sim\tb"
$work_dir = Join-Path $RepoRoot "sim\work\<script-specific-subdir>"
```

- [ ] **Step 2: Run the scripts if Vivado is available**

Run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File sim\work\run_awg_key_ui_ctrl_sim.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File sim\work\run_awg_led_status_sim.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File sim\work\run_awg_core_sim.ps1
```

Expected: each script reports its testbench pass marker or exits with code 0.

- [ ] **Step 3: Add no-Vivado fallback documentation**

If Vivado is not available, document the skipped command and keep this verification command passing:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\check_project_health.ps1 -SkipStaticRtl
```

- [ ] **Step 4: Commit**

Run:

```powershell
git add sim/work/run_awg_core_sim.ps1 sim/work/run_awg_key_ui_ctrl_sim.ps1 sim/work/run_awg_led_status_sim.ps1
git commit -m "fix: make simulation scripts path portable"
```

---

## Phase 2: Contest-Focused UI Workflow

### Task 2.1: Add A Guided Competition Demo Page

**Files:**
- Create: `ad9144_bringup_k325t/upper_host/demo_session.py`
- Create: `ad9144_bringup_k325t/upper_host/pages/competition.py`
- Modify: `ad9144_bringup_k325t/upper_host/app.py`
- Test: `ad9144_bringup_k325t/tests/test_upper_host_backend.py`

- [ ] **Step 1: Add the demo step model**

Create `demo_session.py` with immutable step definitions:

```python
from __future__ import annotations

from dataclasses import dataclass


@dataclass(frozen=True, slots=True)
class DemoStep:
    key: str
    title: str
    preset: str
    expected_scope: str
    evidence_kind: str
    claim: str


DEMO_STEPS = [
    DemoStep("status", "Read board status", "baseline_50m", "ID=0x41574731 in GUI", "status", "PC-to-FPGA control path is alive"),
    DemoStep("baseline", "50 MHz sine baseline", "baseline_50m", "Stable 50 MHz sine on OUT1", "scope", "Known-good sine output"),
    DemoStep("amplitude_low", "Amplitude low point", "amp_low_50m", "Vpp lower than baseline", "scope", "Amplitude control works"),
    DemoStep("amplitude_high", "Amplitude high point", "amp_high_50m", "Vpp higher than baseline without severe clipping", "scope", "Amplitude range is controllable"),
    DemoStep("low_freq", "1 MHz sine point", "low_1m", "Frequency near 1 MHz", "scope", "Frequency control spans low range"),
    DemoStep("mid_freq", "100 MHz sine point", "mid_100m", "Frequency near 100 MHz", "scope", "Mid-band output is reachable"),
    DemoStep("high_freq", "300 MHz sine point", "high_300m", "Frequency near 300 MHz, distortion noted honestly", "scope", "High-frequency operation is demonstrated"),
    DemoStep("square", "Square waveform", "square_50m", "Square-like output visible", "scope", "Waveform mode switches"),
    DemoStep("triangle", "Triangle waveform", "triangle_50m", "Triangle-like output visible", "scope", "Waveform mode switches"),
    DemoStep("saw", "Sawtooth waveform", "saw_50m", "Sawtooth-like output visible", "scope", "Waveform mode switches"),
]


def step_keys() -> list[str]:
    return [step.key for step in DEMO_STEPS]
```

- [ ] **Step 2: Add tests for step/preset consistency**

Add this test to `test_upper_host_backend.py`:

```python
def test_competition_demo_steps_reference_valid_presets(self) -> None:
    from ad9144_bringup_k325t.upper_host.demo_session import DEMO_STEPS

    preset_names = set(backend.demo_preset_names())
    self.assertGreaterEqual(len(DEMO_STEPS), 8)
    for step in DEMO_STEPS:
        self.assertIn(step.preset, preset_names)
        self.assertTrue(step.expected_scope)
        self.assertTrue(step.claim)
```

- [ ] **Step 3: Create the page**

Create `pages/competition.py` with a `CompetitionPage(QWidget)` containing:

```text
left column: ordered demo steps
center: selected step details and expected scope observation
right: evidence status fields for screenshot path, CSV row status, pass/fail note
bottom buttons: Apply Preset, Mark Observed, Mark Needs Repeat, Open Evidence Folder
```

Use existing `UpperHostWindow.apply_selected_demo()` logic by setting the Control page demo combo before applying.

- [ ] **Step 4: Add the page to navigation**

In `app.py`, add `CompetitionPage` to the stacked pages after Dashboard and before Control. Label it `Competition`.

- [ ] **Step 5: Verify UI smoke**

Run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File ad9144_bringup_k325t\scripts\check_upper_host.ps1
```

Expected: `UPPER_HOST_CHECK_OK`.

- [ ] **Step 6: Commit**

Run:

```powershell
git add ad9144_bringup_k325t/upper_host ad9144_bringup_k325t/tests/test_upper_host_backend.py
git commit -m "feat: add guided competition demo page"
```

### Task 2.2: Add A Claim-Safety Panel

**Files:**
- Create: `ad9144_bringup_k325t/upper_host/evidence.py`
- Modify: `ad9144_bringup_k325t/upper_host/pages/competition.py`
- Modify: `docs/competition/evidence_index.md`
- Test: `ad9144_bringup_k325t/tests/test_upper_host_backend.py`

- [ ] **Step 1: Define contest claims**

Create `evidence.py` with:

```python
from __future__ import annotations

from dataclasses import dataclass


@dataclass(frozen=True, slots=True)
class ContestClaim:
    key: str
    label: str
    status: str
    evidence: str
    limitation: str


CLAIMS = [
    ContestClaim("control", "PC GUI controls FPGA registers", "verified", "UART ID/status readback and preset readback", ""),
    ContestClaim("dds_resolution", "48-bit DDS frequency word supports <=1 mHz resolution", "verified_digital", "phase increment formula and register readback", "Analog observation of 1 mHz is not practical in live demo"),
    ContestClaim("waveforms", "Sine/square/triangle/saw modes are selectable", "verified_scope", "OUT1 scope observations and screenshots", ""),
    ContestClaim("bandwidth", "Analog output demonstrated through 300 MHz on current setup", "partial", "Scope frequency-response table", "Do not claim full 1 GHz bandwidth without measurement"),
    ContestClaim("sample_rate", "Current AD9144 path is a high-speed DAC prototype", "limited", "AD9144/JESD204 design docs", "Do not claim true >=5 GSa/s analog output on the measured OUT1 path"),
    ContestClaim("calibration", "Amplitude calibration workflow exists", "needs_measurement", "Before/after Vpp table", "Final value depends on filled scope measurements"),
]
```

- [ ] **Step 2: Render claims in the Competition page**

Display each claim with color:

```text
verified -> green
verified_digital -> blue
verified_scope -> green
partial -> amber
limited -> red outline
needs_measurement -> gray
```

- [ ] **Step 3: Export evidence index**

Add a function:

```python
def evidence_markdown() -> str:
    lines = ["# Competition Evidence Index", ""]
    for claim in CLAIMS:
        lines.append(f"- **{claim.label}**: `{claim.status}`")
        lines.append(f"  - Evidence: {claim.evidence}")
        if claim.limitation:
            lines.append(f"  - Limitation: {claim.limitation}")
    return "\n".join(lines) + "\n"
```

Write this output to `docs/competition/evidence_index.md`.

- [ ] **Step 4: Test**

Add a test that asserts no claim has an empty status/evidence field.

- [ ] **Step 5: Commit**

Run:

```powershell
git add ad9144_bringup_k325t/upper_host/evidence.py ad9144_bringup_k325t/upper_host/pages/competition.py docs/competition/evidence_index.md ad9144_bringup_k325t/tests/test_upper_host_backend.py
git commit -m "feat: add contest claim evidence panel"
```

---

## Phase 3: FPGA Feature Completion For The Problem Statement

### Task 3.1: Add Uploadable Arbitrary Waveform RAM

**Files:**
- Create: `ad9144_bringup_k325t/rtl/awg/ad9144_wave_ram.v`
- Create: `ad9144_bringup_k325t/rtl/awg/tb_ad9144_wave_ram.v`
- Modify: `ad9144_bringup_k325t/rtl/awg/ad9144_awg_dds4.v`
- Modify: `ad9144_bringup_k325t/rtl/awg/ad9144_awg_reg_bank.v`
- Modify: `ad9144_bringup_k325t/rtl/awg/ad9144_uart_reg_bridge.v`
- Modify: `ad9144_bringup_k325t/variants/awg_button/top.v`
- Modify: `ad9144_bringup_k325t/docs/awg_register_map.md`
- Modify: `ad9144_bringup_k325t/docs/ad9144_uart_control_protocol.md`

- [ ] **Step 1: Add register map entries**

Extend the register map:

```text
0x70 WAVE_RAM_ADDR     RW address 0..4095
0x74 WAVE_RAM_DATA     RW signed sample in bits [15:0]
0x78 WAVE_RAM_CONTROL  RW bit0 write_strobe, bit1 auto_increment, bit2 load_done
0x7C WAVE_RAM_STATUS   RO bit0 ready, bits[15:0] last_addr
```

Keep existing wave modes:

```text
0=sine, 1=square, 2=triangle, 3=saw
```

Add:

```text
4=uploaded waveform RAM
```

- [ ] **Step 2: Implement RAM**

Create `ad9144_wave_ram.v` as a dual-purpose RAM with:

```verilog
module ad9144_wave_ram #(
    parameter ADDR_WIDTH = 12
) (
    input  wire                  clk,
    input  wire                  rst_n,
    input  wire [ADDR_WIDTH-1:0] rd_addr,
    output reg  signed [15:0]    rd_data,
    input  wire                  wr_en,
    input  wire [ADDR_WIDTH-1:0] wr_addr,
    input  wire signed [15:0]    wr_data
);
```

Use synchronous read and write in the same `clk` domain. Initialize RAM to a sine-like or zero waveform so mode 4 is deterministic before upload.

- [ ] **Step 3: Wire DDS4 mode 4**

In `ad9144_awg_dds4.v`, when `wave_mode == 3'd4`, source the raw sample from `wave_ram_rd_data` instead of built-in shape logic.

Add ports:

```verilog
output wire [11:0] wave_ram_addr0,
output wire [11:0] wave_ram_addr1,
output wire [11:0] wave_ram_addr2,
output wire [11:0] wave_ram_addr3,
input  wire signed [15:0] wave_ram_data0,
input  wire signed [15:0] wave_ram_data1,
input  wire signed [15:0] wave_ram_data2,
input  wire signed [15:0] wave_ram_data3
```

If four independent read ports are too expensive, instantiate four replicated RAMs and write them all together.

- [ ] **Step 4: Add testbench**

`tb_ad9144_wave_ram.v` must:

```text
write address 0 = 16'sh1000
write address 1 = -16'sh1000
read address 0 and 1
assert read data matches
exercise auto-increment write through reg-bank-level simulation if available
```

- [ ] **Step 5: Update host tool**

Add CLI command:

```powershell
python tools\awg_uart_control.py wave load --input waveforms\custom.csv --port COM7 --activate
```

CSV format:

```csv
index,sample
0,0
1,1200
2,2400
```

The parser must accept decimal and hex signed values and clamp to signed 16-bit range.

- [ ] **Step 6: Verify**

Run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File ad9144_bringup_k325t\scripts\check_awg_waveform_modes.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\check_project_health.ps1
```

Expected: both pass.

- [ ] **Step 7: Commit**

Run:

```powershell
git add ad9144_bringup_k325t/rtl/awg ad9144_bringup_k325t/tools/awg_uart_control.py ad9144_bringup_k325t/docs
git commit -m "feat: add uploadable waveform RAM mode"
```

### Task 3.2: Add Hardware Sweep Engine

**Files:**
- Create: `ad9144_bringup_k325t/rtl/awg/ad9144_sweep_engine.v`
- Create: `ad9144_bringup_k325t/rtl/awg/tb_ad9144_sweep_engine.v`
- Modify: `ad9144_bringup_k325t/rtl/awg/ad9144_awg_reg_bank.v`
- Modify: `ad9144_bringup_k325t/variants/awg_button/top.v`
- Modify: `ad9144_bringup_k325t/tools/awg_uart_control.py`
- Modify: `ad9144_bringup_k325t/upper_host/backend.py`
- Modify: `ad9144_bringup_k325t/upper_host/pages/control.py`

- [ ] **Step 1: Add sweep registers**

Register map:

```text
0x80 SWEEP_CONTROL    RW bit0 enable, bit1 log_mode, bit2 repeat, bit3 direction
0x84 SWEEP_START_LO   RW start phase increment [31:0]
0x88 SWEEP_START_HI   RW start phase increment [47:32]
0x8C SWEEP_STOP_LO    RW stop phase increment [31:0]
0x90 SWEEP_STOP_HI    RW stop phase increment [47:32]
0x94 SWEEP_STEP_LO    RW phase increment step [31:0]
0x98 SWEEP_STEP_HI    RW phase increment step [47:32]
0x9C SWEEP_DWELL      RW clocks per step
0xA0 SWEEP_STATUS     RO current state and done flag
```

- [ ] **Step 2: Implement linear sweep**

`ad9144_sweep_engine.v` inputs:

```verilog
input wire clk,
input wire rst_n,
input wire enable,
input wire repeat,
input wire direction,
input wire [47:0] start_inc,
input wire [47:0] stop_inc,
input wire [47:0] step_inc,
input wire [31:0] dwell_clocks,
output reg [47:0] active_inc,
output reg done
```

Behavior:

```text
when enable rises, active_inc = start_inc
after dwell_clocks cycles, add or subtract step_inc
when stop is reached, set done
if repeat=1, wrap to start_inc and continue
```

- [ ] **Step 3: Make log sweep host-assisted**

For log sweep, generate a table of phase increments on the host and upload it as a sweep list only after linear sweep is stable. The GUI can label it "log sweep sequence" and drive it stepwise over UART for the current hardware. Do not claim continuous hardware log sweep until implemented in RTL.

- [ ] **Step 4: Add GUI controls**

Control page fields:

```text
Sweep enable
Start frequency Hz
Stop frequency Hz
Step frequency Hz
Dwell ms
Repeat
Apply Sweep
Stop Sweep
```

- [ ] **Step 5: Verify**

Run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\check_project_health.ps1
```

If Vivado simulation is available, also run the new sweep testbench with a Tcl script modeled on `run_tb_awg_cal.tcl`.

- [ ] **Step 6: Commit**

Run:

```powershell
git add ad9144_bringup_k325t/rtl/awg ad9144_bringup_k325t/tools ad9144_bringup_k325t/upper_host ad9144_bringup_k325t/docs
git commit -m "feat: add AD9144 hardware sweep engine"
```

---

## Phase 4: Timing, CDC, And Release Confidence

### Task 4.1: Parse And Gate Timing Reports

**Files:**
- Create: `ad9144_bringup_k325t/scripts/check_timing_report.ps1`
- Modify: `ad9144_bringup_k325t/scripts/build_awg_uart_direct.tcl`
- Modify: `ad9144_bringup_k325t/README.md`
- Modify: `ad9144_bringup_k325t/AGENTS.md`

- [ ] **Step 1: Add timing parser**

The parser accepts a report path and fails if `WNS < 0` unless `-AllowNegativeWns` is passed:

```powershell
param(
    [Parameter(Mandatory = $true)]
    [string]$Report,
    [switch]$AllowNegativeWns
)

$text = Get-Content -Raw $Report
if ($text -notmatch "WNS\(ns\)\s+([-+]?\d+(\.\d+)?)") {
    throw "could not find WNS in $Report"
}
$wns = [double]$Matches[1]
Write-Host "TIMING_WNS_NS=$wns"
if ($wns -lt 0 -and -not $AllowNegativeWns) {
    throw "negative WNS is not release-clean: $wns"
}
Write-Host "TIMING_REPORT_OK"
```

- [ ] **Step 2: Make build scripts write timing summaries**

In `build_awg_uart_direct.tcl`, ensure these reports are produced:

```tcl
report_timing_summary -file $build_dir/top_awg_uart_timing_summary.rpt
report_cdc -file $build_dir/top_awg_uart_cdc.rpt
```

- [ ] **Step 3: Document release rule**

Add this rule:

```text
A bitstream is demo-usable if write_bitstream succeeds and board output is verified.
A bitstream is release-clean only if timing parser reports non-negative WNS or every waived path is documented with a CDC/reset rationale.
```

- [ ] **Step 4: Commit**

Run:

```powershell
git add ad9144_bringup_k325t/scripts ad9144_bringup_k325t/README.md ad9144_bringup_k325t/AGENTS.md
git commit -m "test: add timing report release gate"
```

### Task 4.2: Clean Reset And CDC Paths In The AD9144 Top

**Files:**
- Modify: `ad9144_bringup_k325t/variants/awg_button/top.v`
- Modify: `ad9144_bringup_k325t/constraints/awg_uart_k325t.xdc`
- Modify: `ad9144_bringup_k325t/docs/phase_handoff_2026-05-07.md`

- [ ] **Step 1: Identify clock domains**

Document every active clock in `top.v`:

```text
system board clock
JESD user clock
UART baud sampling clock derived from system clock
vendor SPI/config clocks
debug/ILA clocks
```

- [ ] **Step 2: Synchronize async controls**

For every cross-domain single-bit control entering the JESD/user clock domain, add a two-flop synchronizer:

```verilog
reg [1:0] sync_ff;
always @(posedge target_clk or negedge rst_n) begin
    if (!rst_n)
        sync_ff <= 2'b00;
    else
        sync_ff <= {sync_ff[0], async_signal};
end
wire signal_target = sync_ff[1];
```

- [ ] **Step 3: Constrain or waive only justified paths**

For reset and debug-only paths, add explicit constraints with comments in the XDC. Do not blanket-waive all setup failures.

- [ ] **Step 4: Rebuild and parse timing**

Run:

```powershell
& D:\vivado\Vivado\2024.1\bin\vivado.bat -mode batch -tempDir C:/tmp/vivado_awg_uart_temp -journal C:/tmp/vivado_awg_uart.jou -log C:/tmp/vivado_awg_uart.log -source ad9144_bringup_k325t\scripts\build_awg_uart_direct.tcl
powershell -NoProfile -ExecutionPolicy Bypass -File ad9144_bringup_k325t\scripts\check_timing_report.ps1 -Report ad9144_bringup_k325t\vivado_awg_uart\top_awg_uart_timing_summary.rpt
```

Expected for release-clean: non-negative WNS.

- [ ] **Step 5: Commit**

Run:

```powershell
git add ad9144_bringup_k325t/variants/awg_button/top.v ad9144_bringup_k325t/constraints ad9144_bringup_k325t/docs
git commit -m "fix: clean AD9144 reset and CDC timing"
```

---

## Phase 5: Measurement, Calibration, And Evidence

### Task 5.1: Build A Session-Based Evidence Package

**Files:**
- Modify: `ad9144_bringup_k325t/tools/awg_scope_measurement.py`
- Modify: `ad9144_bringup_k325t/upper_host/evidence.py`
- Modify: `ad9144_bringup_k325t/upper_host/pages/competition.py`
- Create: `docs/competition/final_validation_checklist.md`

- [ ] **Step 1: Add a session ID**

Every generated measurement CSV must include:

```text
session_id
git_commit
bitstream_name
exe_or_source
scope_model
termination
operator
```

Default `session_id` format:

```text
YYYYMMDD_HHMM_ad9144_awg
```

- [ ] **Step 2: Add required evidence rows**

The default final validation template must include:

```text
baseline_50m
amp_low_50m
amp_high_50m
low_1m
mid_100m
high_300m
square_50m
triangle_50m
saw_50m
cal_before_50m
cal_after_50m
```

- [ ] **Step 3: Add export command**

Add:

```powershell
python tools\awg_scope_measurement.py final-template --out measurements\scope_templates\final_validation.csv
```

- [ ] **Step 4: Generate Markdown report**

Report must include:

```text
Measured points table
Pass/fail summary
Calibration before/after table
Claim safety notes
Paths to screenshots
```

- [ ] **Step 5: Commit**

Run:

```powershell
git add ad9144_bringup_k325t/tools/awg_scope_measurement.py ad9144_bringup_k325t/upper_host docs/competition/final_validation_checklist.md
git commit -m "feat: add contest evidence session workflow"
```

### Task 5.2: Execute The Board Measurement Run

**Files:**
- Generated files under ignored `ad9144_bringup_k325t/measurements/`
- Generated screenshots under ignored local evidence folder
- Modify tracked summary only: `docs/competition/evidence_index.md`
- Modify tracked summary only: `ad9144_bringup_k325t/docs/competition_measurement_report.md`

- [ ] **Step 1: Program the UART bit**

Run:

```powershell
& D:\vivado\Vivado\2024.1\bin\vivado.bat -mode batch -source ad9144_bringup_k325t\scripts\program_awg_uart.tcl
```

Expected: Vivado startup status reports `HIGH`.

- [ ] **Step 2: Wait and read status**

Wait 12 to 15 seconds, then run:

```powershell
python ad9144_bringup_k325t\tools\awg_uart_control.py --port COM7 status
```

Expected:

```text
ID=0x41574731
VERSION=0x20260507
```

- [ ] **Step 3: Run the final preset sequence**

Use the Qt Competition page or CLI:

```powershell
python ad9144_bringup_k325t\tools\awg_uart_control.py --port COM7 demo all --step-delay 2.0
```

For each step, record frequency, Vpp, visible distortion, and screenshot path.

- [ ] **Step 4: Generate calibration table**

Run:

```powershell
python ad9144_bringup_k325t\tools\awg_scope_measurement.py calibration --input ad9144_bringup_k325t\measurements\scope_templates\final_validation_filled.csv
python ad9144_bringup_k325t\tools\awg_uart_control.py --port COM7 cal load --input ad9144_bringup_k325t\measurements\calibration_tables\final_validation_filled_calibration.csv --enable
```

- [ ] **Step 5: Repeat key points after calibration**

Measure at least:

```text
50 MHz 0x6000 sine
100 MHz 0x6000 sine
300 MHz 0x6000 sine
```

- [ ] **Step 6: Update tracked summaries**

Only commit summarized tables and conclusions, not large generated artifacts:

```powershell
git add docs/competition/evidence_index.md ad9144_bringup_k325t/docs/competition_measurement_report.md
git commit -m "docs: add final board measurement evidence summary"
```

---

## Phase 6: Final Documentation, Video, And Release Package

### Task 6.1: Align Design Document With Actual Implementation

**Files:**
- Modify: `docs/competition/design_document.md`
- Modify: `docs/competition/video_script.md`
- Modify: `docs/competition/score_recovery_strategy.md`

- [ ] **Step 1: Fix protocol mismatch**

Ensure the design document describes the actual UART protocol:

```text
Write: W <addr_hex_2> <data_hex_8>
Read:  R <addr_hex_2>
Read response: D <data_hex_8>
Write response: OK
```

Remove any stale protocol examples that use a single `S` status command unless the code implements it.

- [ ] **Step 2: Add the honest claims table**

Use this classification:

```text
Achieved: PC control, DDS frequency word precision, waveform mode selection, OUT1 observed output
Partially achieved: analog frequency range, amplitude range, calibration
Not claimed as fully achieved: >=5 GSa/s analog output, >=1 GHz analog bandwidth, full-band THD/spur
```

- [ ] **Step 3: Update video flow**

The video script should show:

```text
hardware chain
GUI status read
50 MHz sine
amplitude change
frequency change
waveform change
measurement report
calibration idea
hardware limitation and upgrade path
```

- [ ] **Step 4: Commit**

Run:

```powershell
git add docs/competition/design_document.md docs/competition/video_script.md docs/competition/score_recovery_strategy.md
git commit -m "docs: align contest deliverables with verified implementation"
```

### Task 6.2: Build A Local Release Package

**Files:**
- Create: `ad9144_bringup_k325t/scripts/build_release_package.ps1`
- Modify: `ad9144_bringup_k325t/docs/upper_host_qt.md`
- Modify: `docs/competition/final_validation_checklist.md`

- [ ] **Step 1: Create manifest builder**

The script must create:

```text
artifacts/release/<session_id>/
  manifest.json
  README_RELEASE.md
  upper_host/
  reports/
  docs/
```

`manifest.json` fields:

```json
{
  "git_commit": "<commit>",
  "branch": "<branch>",
  "created_at": "<local timestamp>",
  "vivado_version": "2024.1",
  "target_part": "xc7k325tffg900-2",
  "hardware": "K325T + FMCADDA-9250-9144",
  "upper_host_check": "UPPER_HOST_CHECK_OK",
  "project_health": "PROJECT_HEALTH_OK"
}
```

- [ ] **Step 2: Run package build**

Run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File ad9144_bringup_k325t\scripts\build_release_package.ps1
```

Expected: script prints `RELEASE_PACKAGE_OK=<path>`.

- [ ] **Step 3: Commit**

Run:

```powershell
git add ad9144_bringup_k325t/scripts/build_release_package.ps1 ad9144_bringup_k325t/docs/upper_host_qt.md docs/competition/final_validation_checklist.md
git commit -m "chore: add contest release package builder"
```

---

## Final Verification Gate

Run these commands before calling the competition version ready:

```powershell
git status --short
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\check_project_health.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File ad9144_bringup_k325t\scripts\check_timing_report.ps1 -Report ad9144_bringup_k325t\vivado_awg_uart\top_awg_uart_timing_summary.rpt
powershell -NoProfile -ExecutionPolicy Bypass -File ad9144_bringup_k325t\scripts\build_release_package.ps1
```

Board-side final verification requires powered hardware:

```powershell
& D:\vivado\Vivado\2024.1\bin\vivado.bat -mode batch -source ad9144_bringup_k325t\scripts\program_awg_uart.tcl
python ad9144_bringup_k325t\tools\awg_uart_control.py --port COM7 status
```

Expected UART readback:

```text
ID=0x41574731
VERSION=0x20260507
```

Scope expectations:

```text
OUT1 50 MHz sine visible after 12-15 second initialization wait
amplitude presets change Vpp
frequency presets change measured frequency
sine/square/triangle/saw modes visibly switch
```

---

## Self-Review

Spec coverage:

- Sampling rate and 1 GHz bandwidth: plan does not overclaim current hardware; it adds evidence boundaries and release documentation.
- 14-bit resolution: current AD9144 path and signed 16-bit datapath are documented; final measured proof remains analog-equipment dependent.
- 1 mHz resolution: plan relies on 48-bit DDS math and register readback evidence.
- Sweep: plan adds a hardware linear sweep engine and host-assisted log sweep sequence.
- Arbitrary waveform: plan adds uploadable waveform RAM mode.
- Amplitude range, flatness, THD, spur: plan adds measurement session workflow and calibration before/after proof.
- UI and usability: plan adds guided competition page, claim-safety panel, and release package.
- Documentation and demonstration: plan updates design document, video script, evidence index, and final checklist.

Placeholder scan:

- No forbidden filler terms are present.
- Hardware-dependent steps state exact commands and expected observations.
- Items that cannot be honestly verified on the fixed hardware are explicitly classified as limitations.

Type consistency:

- New Python modules use existing `backend`, `ctrl`, and PySide6 page patterns.
- Register addresses are reserved in contiguous blocks and do not overlap the current map through `0x40`.
- Wave mode `4` is reserved for uploaded waveform RAM and does not change existing `0..3` modes.
