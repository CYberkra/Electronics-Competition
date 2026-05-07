#!/usr/bin/env python3
"""Create and summarize oscilloscope measurement sheets for AWG bring-up."""

from __future__ import annotations

import argparse
import csv
import sys
import time
from dataclasses import dataclass
from pathlib import Path

from awg_uart_control import phase_inc_from_frequency


DEFAULT_SAMPLE_RATE = 1_000_000_000.0
_TOOLS_DIR = Path(__file__).resolve().parent
_BRINGUP_ROOT = _TOOLS_DIR.parent
DEFAULT_TEMPLATE_DIR = _BRINGUP_ROOT / "measurements" / "scope_templates"
DEFAULT_REPORT_DIR = _BRINGUP_ROOT / "measurements" / "scope_reports"

FIELDNAMES = [
    "timestamp",
    "source",
    "target_frequency_hz",
    "target_amplitude_hex",
    "target_wave",
    "target_phase_inc_hex",
    "sample_rate_hz",
    "measured_frequency_hz",
    "measured_vpp_v",
    "measured_vrms_v",
    "trigger_stability",
    "visible_distortion",
    "scope_model",
    "termination",
    "probe_or_cable",
    "note",
]


@dataclass(frozen=True)
class MeasurementPoint:
    source: str
    frequency_hz: float
    amplitude: int
    wave: str = "sine"
    phase_inc: int | None = None


def profile_points(profile: str, sample_rate: float) -> list[MeasurementPoint]:
    if profile == "freq_response":
        freqs = [1e6, 5e6, 10e6, 20e6, 50e6, 100e6, 200e6, 300e6, 400e6]
        return [MeasurementPoint(profile, freq, 0x6000) for freq in freqs]
    if profile == "high_freq_detail":
        freqs = [250e6, 300e6, 350e6, 380e6, 400e6]
        return [MeasurementPoint(profile, freq, 0x6000) for freq in freqs]
    if profile == "amplitude_linearity":
        amps = [0x1000, 0x2000, 0x3000, 0x4000, 0x5000, 0x6000, 0x7000]
        return [MeasurementPoint(profile, 50e6, amp) for amp in amps]
    if profile == "wave_modes":
        return [
            MeasurementPoint(profile, 50e6, 0x6000, "sine"),
            MeasurementPoint(profile, 50e6, 0x6000, "square"),
            MeasurementPoint(profile, 50e6, 0x6000, "triangle"),
            MeasurementPoint(profile, 50e6, 0x6000, "saw"),
        ]
    raise ValueError(f"unknown profile: {profile}")


def row_from_point(point: MeasurementPoint, sample_rate: float) -> dict[str, str]:
    phase_inc = point.phase_inc
    if phase_inc is None:
        phase_inc = phase_inc_from_frequency(point.frequency_hz, sample_rate)
    return {
        "timestamp": time.strftime("%Y-%m-%d %H:%M:%S"),
        "source": point.source,
        "target_frequency_hz": f"{point.frequency_hz:.6f}",
        "target_amplitude_hex": f"0x{point.amplitude & 0xFFFF:04X}",
        "target_wave": point.wave,
        "target_phase_inc_hex": f"0x{phase_inc:012X}",
        "sample_rate_hz": f"{sample_rate:.6f}",
        "measured_frequency_hz": "",
        "measured_vpp_v": "",
        "measured_vrms_v": "",
        "trigger_stability": "",
        "visible_distortion": "",
        "scope_model": "",
        "termination": "50ohm",
        "probe_or_cable": "OUT1 direct coax",
        "note": "",
    }


def read_sweep_csv(path: Path, sample_rate: float) -> list[MeasurementPoint]:
    points: list[MeasurementPoint] = []
    with path.open("r", newline="", encoding="utf-8-sig") as handle:
        reader = csv.DictReader(handle)
        for row in reader:
            freq_text = row.get("target_frequency_hz") or row.get("frequency_hz")
            if not freq_text:
                raise ValueError(f"{path} row has no target_frequency_hz/frequency_hz")
            amp_text = row.get("target_amplitude_hex") or row.get("amplitude_hex") or "0x6000"
            wave = row.get("target_wave") or row.get("wave") or "sine"
            phase_text = row.get("target_phase_inc_hex") or row.get("phase_inc") or ""
            try:
                phase_inc = int(phase_text, 16) if phase_text else None
            except ValueError:
                phase_inc = None
            points.append(
                MeasurementPoint(
                    source=path.stem,
                    frequency_hz=float(freq_text),
                    amplitude=int(amp_text, 0),
                    wave=wave,
                    phase_inc=phase_inc,
                )
            )
    if not points:
        raise ValueError(f"{path} contains no sweep rows")
    return points


def write_csv(path: Path, rows: list[dict[str, str]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=FIELDNAMES)
        writer.writeheader()
        writer.writerows(rows)


def command_template(args: argparse.Namespace) -> int:
    if args.from_sweep:
        points = read_sweep_csv(args.from_sweep, args.sample_rate)
        default_name = f"{args.from_sweep.stem}_scope_template.csv"
    else:
        points = profile_points(args.profile, args.sample_rate)
        default_name = f"{args.profile}_scope_template.csv"
    rows = [row_from_point(point, args.sample_rate) for point in points]
    out = args.out or (DEFAULT_TEMPLATE_DIR / default_name)
    write_csv(out, rows)
    print(f"SCOPE_TEMPLATE_CSV={out}")
    return 0


def read_measurement_rows(path: Path) -> list[dict[str, str]]:
    with path.open("r", newline="", encoding="utf-8-sig") as handle:
        rows = list(csv.DictReader(handle))
    if not rows:
        raise ValueError(f"{path} contains no rows")
    return rows


def markdown_table(rows: list[dict[str, str]]) -> str:
    headers = [
        "Target",
        "Wave",
        "Amp",
        "Measured Freq",
        "Vpp",
        "Trigger",
        "Distortion",
        "Note",
    ]
    lines = [
        "| " + " | ".join(headers) + " |",
        "| " + " | ".join(["---"] * len(headers)) + " |",
    ]
    for row in rows:
        values = [
            row.get("target_frequency_hz", ""),
            row.get("target_wave", ""),
            row.get("target_amplitude_hex", ""),
            row.get("measured_frequency_hz", ""),
            row.get("measured_vpp_v", ""),
            row.get("trigger_stability", ""),
            row.get("visible_distortion", ""),
            row.get("note", ""),
        ]
        lines.append("| " + " | ".join(value.replace("|", "/") for value in values) + " |")
    return "\n".join(lines)


def command_report(args: argparse.Namespace) -> int:
    rows = read_measurement_rows(args.input)
    filled = [
        row
        for row in rows
        if row.get("measured_frequency_hz") or row.get("measured_vpp_v") or row.get("note")
    ]
    visible_rows = filled if filled else rows
    out = args.out or (DEFAULT_REPORT_DIR / f"{args.input.stem}.md")
    out.parent.mkdir(parents=True, exist_ok=True)
    text = "\n".join(
        [
            f"# AWG Scope Measurement Report: {args.input.stem}",
            "",
            f"- Source CSV: `{args.input}`",
            f"- Rows: {len(rows)}",
            f"- Filled rows: {len(filled)}",
            "",
            markdown_table(visible_rows),
            "",
            "## Notes",
            "",
            "- Leave blank measured fields means the point has not been observed yet.",
            "- `trigger_stability` examples: stable, counter jumps, trigger unstable.",
            "- `visible_distortion` examples: none, mild, obvious, clipped.",
        ]
    )
    out.write_text(text, encoding="utf-8")
    print(f"SCOPE_REPORT_MD={out}")
    return 0


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Create or summarize AD9144 AWG scope measurement sheets.")
    sub = parser.add_subparsers(dest="command", required=True)

    template = sub.add_parser("template", help="Create a blank scope measurement CSV")
    template.add_argument("--profile", choices=["freq_response", "high_freq_detail", "amplitude_linearity", "wave_modes"], default="freq_response")
    template.add_argument("--from-sweep", type=Path, help="Create a scope template from an existing UART sweep CSV")
    template.add_argument("--sample-rate", type=float, default=DEFAULT_SAMPLE_RATE)
    template.add_argument("--out", type=Path)
    template.set_defaults(func=command_template)

    report = sub.add_parser("report", help="Create a Markdown summary from a measurement CSV")
    report.add_argument("--input", type=Path, required=True)
    report.add_argument("--out", type=Path)
    report.set_defaults(func=command_report)

    return parser


def main(argv: list[str]) -> int:
    args = build_parser().parse_args(argv)
    return args.func(args)


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
