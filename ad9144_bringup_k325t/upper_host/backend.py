"""Shared runtime helpers for the AD9144 upper-computer Qt app."""

from __future__ import annotations

from dataclasses import dataclass
from functools import lru_cache
from pathlib import Path
from typing import Iterable
import csv
import sys
import time

import numpy as np

from ad9144_bringup_k325t.tools import awg_scope_measurement as scope
from ad9144_bringup_k325t.tools import awg_uart_control as ctrl
from ad9144_bringup_k325t.tools import awg_uart_sweep as sweep
from ad9144_bringup_k325t.tools import awg_wave_quality as quality


BRINGUP_ROOT = Path(__file__).resolve().parents[1]
OUTPUT_ROOT = Path(sys.executable).resolve().parent if getattr(sys, "frozen", False) else BRINGUP_ROOT
DEFAULT_SAMPLE_RATE = 1_000_000_000.0
DEFAULT_TIMEOUT = 1.0
DEFAULT_BAUD = 115200
DEFAULT_SCOPE_TEMPLATE_DIR = OUTPUT_ROOT / "measurements" / "scope_templates"
DEFAULT_SCOPE_REPORT_DIR = OUTPUT_ROOT / "measurements" / "scope_reports"
DEFAULT_CALIBRATION_DIR = OUTPUT_ROOT / "measurements" / "calibration_tables"
DEFAULT_SWEEP_DIR = OUTPUT_ROOT / "measurements" / "uart_sweeps"
DEFAULT_QUALITY_DIR = OUTPUT_ROOT / "reports" / "wave_quality"
DEFAULT_PREVIEW_LUT = BRINGUP_ROOT / "rtl" / "awg" / "ad9144_sine_4096.hex"

RANGE_NAMES = {
    0: "high",
    1: "low",
    2: "ultra-low",
}
WAVE_CHOICES = ["sine", "square", "triangle", "saw"]


@dataclass(frozen=True, slots=True)
class PortItem:
    device: str
    description: str
    hwid: str

    @property
    def label(self) -> str:
        suffix = self.description.strip()
        return f"{self.device} — {suffix}" if suffix else self.device


@dataclass(slots=True)
class StatusSnapshot:
    port: str
    baud: int
    timeout: float
    sample_rate_hz: float
    reg_id: int
    version: int
    control: int
    status: int
    button_state: int
    phase_inc: int
    phase_offset: int
    amplitude: int
    offset: int
    wave_mode: int
    range_sel: int
    cal_enable: bool

    @property
    def frequency_hz(self) -> float:
        return self.phase_inc * self.sample_rate_hz / float(1 << 48)

    @property
    def wave_name(self) -> str:
        for name, mode in ctrl.WAVE_NAMES.items():
            if mode == self.wave_mode and name != "sawtooth":
                return name
        return f"mode{self.wave_mode}"

    @property
    def output_enable(self) -> bool:
        return bool(self.status & 0x1)

    @property
    def use_reg_control(self) -> bool:
        return bool(self.status & 0x2)

    @property
    def tx_ready(self) -> bool:
        return bool(self.status & 0x4)

    @property
    def tx_sync(self) -> bool:
        return bool(self.status & 0x8)

    @property
    def sysref_seen(self) -> bool:
        return bool(self.status & 0x10)

    @property
    def sample_valid(self) -> bool:
        return bool(self.status & 0x20)

    @property
    def update_toggle(self) -> bool:
        return bool(self.status & 0x40)

    @property
    def range_name(self) -> str:
        return RANGE_NAMES.get(self.range_sel, f"range{self.range_sel}")

    def pairs(self) -> list[tuple[str, str]]:
        return [
            ("ID", f"0x{self.reg_id:08X}"),
            ("Version", f"0x{self.version:08X}"),
            ("Control", f"0x{self.control:08X}"),
            ("Status", f"0x{self.status:08X}"),
            ("Button", f"0x{self.button_state:08X}"),
            ("Freq", f"{self.frequency_hz:.6f} Hz"),
            ("Phase Inc", f"0x{self.phase_inc:012X}"),
            ("Phase Off", f"0x{self.phase_offset:012X}"),
            ("Amplitude", f"0x{self.amplitude & 0xFFFF:04X}"),
            ("Offset", f"0x{self.offset & 0xFFFF:04X}"),
            ("Wave", self.wave_name),
            ("Range", self.range_name),
            ("Cal", "on" if self.cal_enable else "off"),
        ]

    def status_flags(self) -> list[tuple[str, bool]]:
        return [
            ("Output", self.output_enable),
            ("Reg Ctrl", self.use_reg_control),
            ("TX Ready", self.tx_ready),
            ("TX Sync", self.tx_sync),
            ("SYSREF", self.sysref_seen),
            ("Sample", self.sample_valid),
            ("Apply", self.update_toggle),
            ("Cal", self.cal_enable),
        ]


@dataclass(slots=True)
class FileArtifact:
    path: Path
    row_count: int


@dataclass(slots=True)
class ReportArtifact:
    path: Path
    row_count: int
    filled_count: int
    markdown: str


@dataclass(slots=True)
class CalibrationArtifact:
    path: Path
    reference_bin: int
    reference_vpp: float
    rows: list[dict[str, str]]


def list_ports() -> list[PortItem]:
    try:
        from serial.tools import list_ports as serial_list_ports
    except ImportError as exc:  # pragma: no cover - environment issue
        raise RuntimeError("pyserial is required for COM-port discovery") from exc

    ports = [
        PortItem(
            device=item.device,
            description=(item.description or "").strip(),
            hwid=(item.hwid or "").strip(),
        )
        for item in serial_list_ports.comports()
    ]
    return sorted(ports, key=lambda item: item.device)


def format_port_label(port: PortItem) -> str:
    if port.description:
        return f"{port.device} — {port.description}"
    return port.device


def demo_preset_names() -> list[str]:
    return list(ctrl.DEMO_SEQUENCE)


def demo_preset_notes(name: str) -> str:
    return str(ctrl.DEMO_PRESETS[name]["note"])


def demo_preset_dict(name: str) -> dict[str, object]:
    if name not in ctrl.DEMO_PRESETS:
        raise KeyError(name)
    return dict(ctrl.DEMO_PRESETS[name])


def _snapshot_from_device(
    dev: ctrl.AwgUart,
    *,
    port: str,
    baud: int,
    timeout: float,
    sample_rate_hz: float,
) -> StatusSnapshot:
    phase_lo = dev.read_reg(ctrl.ADDR_PHASE_INC_LO)
    phase_hi = dev.read_reg(ctrl.ADDR_PHASE_INC_HI)
    offset_lo = dev.read_reg(ctrl.ADDR_PHASE_OFFSET_LO)
    offset_hi = dev.read_reg(ctrl.ADDR_PHASE_OFFSET_HI)
    control = dev.read_reg(ctrl.ADDR_CONTROL)
    status = dev.read_reg(ctrl.ADDR_STATUS)
    button = dev.read_reg(ctrl.ADDR_BUTTON_STATE)
    return StatusSnapshot(
        port=port,
        baud=baud,
        timeout=timeout,
        sample_rate_hz=sample_rate_hz,
        reg_id=dev.read_reg(ctrl.ADDR_ID),
        version=dev.read_reg(ctrl.ADDR_VERSION),
        control=control,
        status=status,
        button_state=button,
        phase_inc=((phase_hi & 0xFFFF) << 32) | phase_lo,
        phase_offset=((offset_hi & 0xFFFF) << 32) | offset_lo,
        amplitude=dev.read_reg(ctrl.ADDR_AMPLITUDE) & 0xFFFF,
        offset=dev.read_reg(ctrl.ADDR_OFFSET) & 0xFFFF,
        wave_mode=dev.read_reg(ctrl.ADDR_WAVE_MODE) & 0x3,
        range_sel=dev.read_reg(ctrl.ADDR_RANGE_SEL) & 0x3,
        cal_enable=bool(dev.read_reg(ctrl.ADDR_CAL_ENABLE) & 0x1),
    )


def read_status_snapshot(
    port: str,
    *,
    baud: int = DEFAULT_BAUD,
    timeout: float = DEFAULT_TIMEOUT,
    sample_rate_hz: float = DEFAULT_SAMPLE_RATE,
) -> StatusSnapshot:
    dev = ctrl.AwgUart(port, baud, timeout)
    try:
        return _snapshot_from_device(
            dev,
            port=port,
            baud=baud,
            timeout=timeout,
            sample_rate_hz=sample_rate_hz,
        )
    finally:
        dev.close()


def _write_active_settings(
    dev: ctrl.AwgUart,
    *,
    frequency_hz: float,
    sample_rate_hz: float,
    amplitude: int,
    offset: int,
    phase_deg: float,
    wave: str,
    range_sel: int,
    output_enable: bool,
    use_reg_control: bool,
    cal_enable: bool,
) -> None:
    phase_inc = ctrl.phase_inc_from_frequency(frequency_hz, sample_rate_hz)
    phase_offset = ctrl.phase_offset_from_degrees(phase_deg)
    dev.set_phase_inc(phase_inc)
    dev.set_phase_offset(phase_offset)
    dev.write_reg(ctrl.ADDR_AMPLITUDE, amplitude & 0xFFFF)
    dev.write_reg(ctrl.ADDR_OFFSET, offset & 0xFFFF)
    dev.write_reg(ctrl.ADDR_WAVE_MODE, ctrl.WAVE_NAMES[wave])
    dev.write_reg(ctrl.ADDR_RANGE_SEL, range_sel & 0x3)
    dev.write_reg(ctrl.ADDR_CAL_ENABLE, 1 if cal_enable else 0)
    control = (1 if output_enable else 0) | (2 if use_reg_control else 0)
    dev.write_reg(ctrl.ADDR_CONTROL, control)
    dev.write_reg(ctrl.ADDR_OUTPUT_EN, 1 if output_enable else 0)
    dev.write_reg(ctrl.ADDR_APPLY, 0x00000001)


def apply_preset(
    port: str,
    *,
    baud: int = DEFAULT_BAUD,
    timeout: float = DEFAULT_TIMEOUT,
    frequency_hz: float,
    sample_rate_hz: float,
    amplitude: int,
    offset: int,
    phase_deg: float,
    wave: str,
    range_sel: int = 0,
    output_enable: bool = True,
    use_reg_control: bool = True,
    cal_enable: bool = False,
) -> StatusSnapshot:
    dev = ctrl.AwgUart(port, baud, timeout)
    try:
        _write_active_settings(
            dev,
            frequency_hz=frequency_hz,
            sample_rate_hz=sample_rate_hz,
            amplitude=amplitude,
            offset=offset,
            phase_deg=phase_deg,
            wave=wave,
            range_sel=range_sel,
            output_enable=output_enable,
            use_reg_control=use_reg_control,
            cal_enable=cal_enable,
        )
        time.sleep(0.05)
        return _snapshot_from_device(
            dev,
            port=port,
            baud=baud,
            timeout=timeout,
            sample_rate_hz=sample_rate_hz,
        )
    finally:
        dev.close()


def apply_demo_preset(
    port: str,
    name: str,
    *,
    baud: int = DEFAULT_BAUD,
    timeout: float = DEFAULT_TIMEOUT,
    sample_rate_hz: float = DEFAULT_SAMPLE_RATE,
) -> StatusSnapshot:
    preset = demo_preset_dict(name)
    return apply_preset(
        port,
        baud=baud,
        timeout=timeout,
        frequency_hz=float(preset["frequency"]),
        sample_rate_hz=sample_rate_hz,
        amplitude=int(preset["amplitude"]),
        offset=int(preset["offset"]),
        phase_deg=float(preset["phase_deg"]),
        wave=str(preset["wave"]),
        range_sel=0,
        output_enable=True,
        use_reg_control=True,
        cal_enable=False,
    )


def set_button_control(
    port: str,
    *,
    baud: int = DEFAULT_BAUD,
    timeout: float = DEFAULT_TIMEOUT,
    sample_rate_hz: float = DEFAULT_SAMPLE_RATE,
    output_enable: bool = True,
) -> StatusSnapshot:
    dev = ctrl.AwgUart(port, baud, timeout)
    try:
        control = 1 if output_enable else 0
        dev.write_reg(ctrl.ADDR_CONTROL, control)
        dev.write_reg(ctrl.ADDR_OUTPUT_EN, 1 if output_enable else 0)
        dev.write_reg(ctrl.ADDR_APPLY, 0x00000001)
        time.sleep(0.05)
        return _snapshot_from_device(
            dev,
            port=port,
            baud=baud,
            timeout=timeout,
            sample_rate_hz=sample_rate_hz,
        )
    finally:
        dev.close()


def set_output_enable(
    port: str,
    enabled: bool,
    *,
    baud: int = DEFAULT_BAUD,
    timeout: float = DEFAULT_TIMEOUT,
    sample_rate_hz: float = DEFAULT_SAMPLE_RATE,
) -> StatusSnapshot:
    dev = ctrl.AwgUart(port, baud, timeout)
    try:
        control = dev.read_reg(ctrl.ADDR_CONTROL)
        if enabled:
            control |= 0x1
        else:
            control &= ~0x1
        dev.write_reg(ctrl.ADDR_CONTROL, control)
        dev.write_reg(ctrl.ADDR_OUTPUT_EN, 1 if enabled else 0)
        dev.write_reg(ctrl.ADDR_APPLY, 0x00000001)
        time.sleep(0.05)
        return _snapshot_from_device(
            dev,
            port=port,
            baud=baud,
            timeout=timeout,
            sample_rate_hz=sample_rate_hz,
        )
    finally:
        dev.close()


def set_calibration_enable(
    port: str,
    enabled: bool,
    *,
    baud: int = DEFAULT_BAUD,
    timeout: float = DEFAULT_TIMEOUT,
    sample_rate_hz: float = DEFAULT_SAMPLE_RATE,
) -> StatusSnapshot:
    dev = ctrl.AwgUart(port, baud, timeout)
    try:
        dev.write_reg(ctrl.ADDR_CAL_ENABLE, 1 if enabled else 0)
        dev.write_reg(ctrl.ADDR_APPLY, 0x00000001)
        time.sleep(0.05)
        return _snapshot_from_device(
            dev,
            port=port,
            baud=baud,
            timeout=timeout,
            sample_rate_hz=sample_rate_hz,
        )
    finally:
        dev.close()


def set_range_sel(
    port: str,
    range_sel: int,
    *,
    baud: int = DEFAULT_BAUD,
    timeout: float = DEFAULT_TIMEOUT,
    sample_rate_hz: float = DEFAULT_SAMPLE_RATE,
) -> StatusSnapshot:
    dev = ctrl.AwgUart(port, baud, timeout)
    try:
        dev.write_reg(ctrl.ADDR_RANGE_SEL, range_sel & 0x3)
        dev.write_reg(ctrl.ADDR_APPLY, 0x00000001)
        time.sleep(0.05)
        return _snapshot_from_device(
            dev,
            port=port,
            baud=baud,
            timeout=timeout,
            sample_rate_hz=sample_rate_hz,
        )
    finally:
        dev.close()


def run_uart_sweep(
    port: str,
    *,
    profile: str,
    out: Path,
    baud: int = DEFAULT_BAUD,
    timeout: float = DEFAULT_TIMEOUT,
    sample_rate_hz: float = DEFAULT_SAMPLE_RATE,
    settle: float = 0.05,
    dry_run: bool = False,
    restore: bool = True,
) -> Path:
    return sweep.run_profile(
        profile=profile,
        out=out,
        port=port,
        baud=baud,
        timeout=timeout,
        sample_rate=sample_rate_hz,
        settle=settle,
        dry_run=dry_run,
        restore=restore,
    )


def build_scope_template(
    *,
    profile: str,
    sample_rate_hz: float = DEFAULT_SAMPLE_RATE,
    out: Path | None = None,
    from_sweep: Path | None = None,
) -> FileArtifact:
    if from_sweep is not None:
        points = scope.read_sweep_csv(from_sweep, sample_rate_hz)
        default_name = f"{from_sweep.stem}_scope_template.csv"
    else:
        points = scope.profile_points(profile, sample_rate_hz)
        default_name = f"{profile}_scope_template.csv"
    rows = [scope.row_from_point(point, sample_rate_hz) for point in points]
    out_path = out or (DEFAULT_SCOPE_TEMPLATE_DIR / default_name)
    scope.write_csv(out_path, rows)
    return FileArtifact(path=out_path, row_count=len(rows))


def build_scope_report(
    *,
    input_path: Path,
    out: Path | None = None,
) -> ReportArtifact:
    rows = scope.read_measurement_rows(input_path)
    filled = [
        row
        for row in rows
        if row.get("measured_frequency_hz") or row.get("measured_vpp_v") or row.get("note")
    ]
    visible_rows = filled if filled else rows
    out_path = out or (DEFAULT_SCOPE_REPORT_DIR / f"{input_path.stem}.md")
    markdown = "\n".join(
        [
            f"# AWG Scope Measurement Report: {input_path.stem}",
            "",
            f"- Source CSV: `{input_path}`",
            f"- Rows: {len(rows)}",
            f"- Filled rows: {len(filled)}",
            "",
            scope.markdown_table(visible_rows),
            "",
            "## Notes",
            "",
            "- Leave blank measured fields means the point has not been observed yet.",
            "- `trigger_stability` examples: stable, counter jumps, trigger unstable.",
            "- `visible_distortion` examples: none, mild, obvious, clipped.",
        ]
    )
    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text(markdown, encoding="utf-8")
    return ReportArtifact(path=out_path, row_count=len(rows), filled_count=len(filled), markdown=markdown)


def build_calibration_table(
    *,
    input_path: Path,
    sample_rate_hz: float = DEFAULT_SAMPLE_RATE,
    reference_frequency_hz: float = 50_000_000.0,
    reference_vpp_v: float | None = None,
    out: Path | None = None,
) -> CalibrationArtifact:
    rows = scope.read_measurement_rows(input_path)
    samples = scope.calibration_samples_from_rows(rows, sample_rate_hz)
    reference_row = min(samples, key=lambda item: abs(item.frequency_hz - reference_frequency_hz))
    reference_vpp = reference_vpp_v if reference_vpp_v is not None else reference_row.measured_vpp_v
    bins = scope.calibration_rows_from_measurements(
        rows,
        sample_rate=sample_rate_hz,
        reference_frequency=reference_frequency_hz,
        reference_vpp=reference_vpp,
    )
    out_path = out or (DEFAULT_CALIBRATION_DIR / f"{input_path.stem}_calibration.csv")
    dict_rows = scope.calibration_rows_to_dicts(bins)
    scope.write_csv(out_path, dict_rows, scope.CAL_CSV_FIELDS)
    return CalibrationArtifact(
        path=out_path,
        reference_bin=reference_row.bin_index,
        reference_vpp=reference_vpp,
        rows=dict_rows,
    )


def load_calibration_rows(path: Path) -> list[tuple[int, int, int, dict[str, str]]]:
    return ctrl.load_calibration_rows(path)


def dump_calibration_rows(
    port: str,
    *,
    baud: int = DEFAULT_BAUD,
    timeout: float = DEFAULT_TIMEOUT,
    sample_rate_hz: float = DEFAULT_SAMPLE_RATE,
) -> list[dict[str, str]]:
    dev = ctrl.AwgUart(port, baud, timeout)
    try:
        rows: list[dict[str, str]] = []
        for index in range(ctrl.CAL_TABLE_ENTRIES):
            word = dev.read_cal_entry(index)
            offset, gain = ctrl.decode_cal_word(word)
            rows.append(
                {
                    "bin_index": str(index),
                    "bin_center_frequency_hz": f"{ctrl.cal_bin_center_frequency_hz(index, sample_rate_hz):.6f}",
                    "sample_rate_hz": f"{sample_rate_hz:.6f}",
                    "gain_q15_hex": f"0x{gain:04X}",
                    "offset_hex": f"0x{offset & 0xFFFF:04X}",
                    "cal_word_hex": ctrl.format_cal_word(word),
                    "note": "readback",
                }
            )
        return rows
    finally:
        dev.close()


def load_calibration_to_hardware(
    port: str,
    *,
    input_path: Path,
    enable: bool = True,
    baud: int = DEFAULT_BAUD,
    timeout: float = DEFAULT_TIMEOUT,
    sample_rate_hz: float = DEFAULT_SAMPLE_RATE,
) -> StatusSnapshot:
    entries = load_calibration_rows(input_path)
    dev = ctrl.AwgUart(port, baud, timeout)
    try:
        for index, offset, gain, _row in entries:
            dev.write_cal_entry(index, ctrl.cal_word_from_fields(offset, gain))
        dev.set_cal_enable(enable)
        dev.write_reg(ctrl.ADDR_APPLY, 0x00000001)
        time.sleep(0.05)
        return _snapshot_from_device(
            dev,
            port=port,
            baud=baud,
            timeout=timeout,
            sample_rate_hz=sample_rate_hz,
        )
    finally:
        dev.close()


def generate_wave_quality(
    *,
    profile: str,
    sample_rate_hz: float = DEFAULT_SAMPLE_RATE,
    sample_count: int = 20_000,
    out: Path | None = None,
    lut_path: Path | None = None,
) -> Path:
    out_path = out or (DEFAULT_QUALITY_DIR / "wave_quality_latest.csv")
    lut = lut_path or DEFAULT_PREVIEW_LUT
    return quality.run_quality(profile, out_path, sample_rate_hz, sample_count, lut)


@lru_cache(maxsize=1)
def _preview_lut() -> tuple[int, ...]:
    return tuple(quality.load_sine_lut(DEFAULT_PREVIEW_LUT))


def preview_samples(
    *,
    frequency_hz: float,
    sample_rate_hz: float,
    amplitude: int,
    offset: int,
    phase_deg: float,
    wave: str,
    sample_count: int = 1024,
) -> tuple[np.ndarray, np.ndarray, dict[str, float]]:
    point = sweep.SweepPoint(
        "preview",
        frequency_hz,
        amplitude & 0xFFFF,
        wave,
        phase_deg=phase_deg,
        offset=offset,
    )
    samples = quality.generate_samples(point, sample_rate_hz, sample_count, list(_preview_lut()))
    x = np.arange(sample_count, dtype=np.float64) / sample_rate_hz * 1e9
    y = np.asarray(samples, dtype=np.float64)
    stats = {
        "min": float(np.min(y)),
        "max": float(np.max(y)),
        "mean": float(np.mean(y)),
        "rms": float(np.sqrt(np.mean(np.square(y)))),
        "vpp": float(np.max(y) - np.min(y)),
    }
    return x, y, stats


def table_rows_from_csv(path: Path, limit: int | None = None) -> tuple[list[str], list[list[str]]]:
    with path.open("r", newline="", encoding="utf-8-sig") as handle:
        reader = csv.reader(handle)
        rows = list(reader)
    if not rows:
        raise ValueError(f"{path} contains no rows")
    header = rows[0]
    body = rows[1:]
    if limit is not None:
        body = body[:limit]
    return header, body
