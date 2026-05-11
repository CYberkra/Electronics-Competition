#!/usr/bin/env python3
"""Program repeatable AWG UART sweep points and save CSV readbacks."""

from __future__ import annotations

import argparse
import csv
import sys
import time
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable

try:
    from .awg_uart_control import (
        ADDR_AMPLITUDE,
        ADDR_APPLY,
        ADDR_CONTROL,
        ADDR_OFFSET,
        ADDR_PHASE_INC_HI,
        ADDR_PHASE_INC_LO,
        ADDR_PHASE_OFFSET_HI,
        ADDR_PHASE_OFFSET_LO,
        ADDR_STATUS,
        ADDR_WAVE_MODE,
        WAVE_NAMES,
        AwgUart,
        phase_inc_from_frequency,
        phase_offset_from_degrees,
    )
except ImportError:  # pragma: no cover - direct script execution fallback
    from awg_uart_control import (
        ADDR_AMPLITUDE,
        ADDR_APPLY,
        ADDR_CONTROL,
        ADDR_OFFSET,
        ADDR_PHASE_INC_HI,
        ADDR_PHASE_INC_LO,
        ADDR_PHASE_OFFSET_HI,
        ADDR_PHASE_OFFSET_LO,
        ADDR_STATUS,
        ADDR_WAVE_MODE,
        WAVE_NAMES,
        AwgUart,
        phase_inc_from_frequency,
        phase_offset_from_degrees,
    )


DEFAULT_SAMPLE_RATE = 1_000_000_000.0
RESTORE_FREQUENCY = 50_000_000.0
RESTORE_AMPLITUDE = 0x6000
RESTORE_WAVE = "sine"


@dataclass(frozen=True)
class SweepPoint:
    label: str
    frequency_hz: float
    amplitude: int
    wave: str
    phase_deg: float = 0.0
    offset: int = 0
    scope_note: str = ""


def profile_points(profile: str) -> list[SweepPoint]:
    if profile == "quick":
        return [
            SweepPoint("quick_sine_10m", 10_000_000.0, 0x6000, "sine"),
            SweepPoint("quick_sine_50m", 50_000_000.0, 0x6000, "sine"),
            SweepPoint("quick_sine_100m", 100_000_000.0, 0x6000, "sine"),
        ]
    if profile == "wave":
        return [
            SweepPoint("wave_sine_50m", 50_000_000.0, 0x6000, "sine"),
            SweepPoint("wave_square_50m", 50_000_000.0, 0x6000, "square"),
            SweepPoint("wave_triangle_50m", 50_000_000.0, 0x6000, "triangle"),
            SweepPoint("wave_saw_50m", 50_000_000.0, 0x6000, "saw"),
        ]
    if profile == "amplitude":
        return [
            SweepPoint("amp_2000_50m", 50_000_000.0, 0x2000, "sine"),
            SweepPoint("amp_4000_50m", 50_000_000.0, 0x4000, "sine"),
            SweepPoint("amp_6000_50m", 50_000_000.0, 0x6000, "sine"),
            SweepPoint("amp_7000_50m", 50_000_000.0, 0x7000, "sine"),
        ]
    if profile == "full":
        return [
            SweepPoint("sine_1m", 1_000_000.0, 0x6000, "sine"),
            SweepPoint("sine_5m", 5_000_000.0, 0x6000, "sine"),
            SweepPoint("sine_10m", 10_000_000.0, 0x6000, "sine"),
            SweepPoint("sine_20m", 20_000_000.0, 0x6000, "sine"),
            SweepPoint("sine_50m", 50_000_000.0, 0x6000, "sine"),
            SweepPoint("sine_100m", 100_000_000.0, 0x6000, "sine"),
            SweepPoint("amp_2000_50m", 50_000_000.0, 0x2000, "sine"),
            SweepPoint("amp_4000_50m", 50_000_000.0, 0x4000, "sine"),
            SweepPoint("amp_7000_50m", 50_000_000.0, 0x7000, "sine"),
            SweepPoint("wave_square_50m", 50_000_000.0, 0x6000, "square"),
            SweepPoint("wave_triangle_50m", 50_000_000.0, 0x6000, "triangle"),
            SweepPoint("wave_saw_50m", 50_000_000.0, 0x6000, "saw"),
        ]
    raise ValueError(f"unknown profile: {profile}")


def wave_value(name: str) -> int:
    if name not in WAVE_NAMES:
        raise ValueError(f"unknown wave: {name}")
    return WAVE_NAMES[name]


def write_point(dev: AwgUart, point: SweepPoint, sample_rate: float) -> int:
    phase_inc = phase_inc_from_frequency(point.frequency_hz, sample_rate)
    phase_offset = phase_offset_from_degrees(point.phase_deg)
    dev.set_phase_inc(phase_inc)
    dev.set_phase_offset(phase_offset)
    dev.write_reg(ADDR_AMPLITUDE, point.amplitude & 0xFFFF)
    dev.write_reg(ADDR_OFFSET, point.offset & 0xFFFF)
    dev.write_reg(ADDR_WAVE_MODE, wave_value(point.wave))
    dev.write_reg(ADDR_CONTROL, 0x00000003)
    dev.write_reg(ADDR_APPLY, 0x00000001)
    return phase_inc


def readback(dev: AwgUart, sample_rate: float) -> dict[str, int | float]:
    phase_lo = dev.read_reg(ADDR_PHASE_INC_LO)
    phase_hi = dev.read_reg(ADDR_PHASE_INC_HI)
    phase_inc = ((phase_hi & 0xFFFF) << 32) | phase_lo
    phase_offset_lo = dev.read_reg(ADDR_PHASE_OFFSET_LO)
    phase_offset_hi = dev.read_reg(ADDR_PHASE_OFFSET_HI)
    phase_offset = ((phase_offset_hi & 0xFFFF) << 32) | phase_offset_lo
    amplitude = dev.read_reg(ADDR_AMPLITUDE) & 0xFFFF
    wave = dev.read_reg(ADDR_WAVE_MODE) & 0x3
    control = dev.read_reg(ADDR_CONTROL)
    status = dev.read_reg(ADDR_STATUS)
    return {
        "read_control": control,
        "read_status": status,
        "read_phase_inc": phase_inc,
        "read_frequency_hz": phase_inc * sample_rate / float(1 << 48),
        "read_phase_offset": phase_offset,
        "read_amplitude": amplitude,
        "read_wave_mode": wave,
    }


def row_for_point(
    point: SweepPoint,
    phase_inc: int,
    sample_rate: float,
    port: str,
    dry_run: bool,
    read_data: dict[str, int | float] | None,
) -> dict[str, str]:
    base: dict[str, str] = {
        "timestamp": time.strftime("%Y-%m-%d %H:%M:%S"),
        "mode": "dry_run" if dry_run else "live",
        "port": port,
        "label": point.label,
        "target_frequency_hz": f"{point.frequency_hz:.6f}",
        "target_amplitude_hex": f"0x{point.amplitude & 0xFFFF:04X}",
        "target_wave": point.wave,
        "target_phase_deg": f"{point.phase_deg:.6f}",
        "target_offset_hex": f"0x{point.offset & 0xFFFF:04X}",
        "target_phase_inc_hex": f"0x{phase_inc:012X}",
        "sample_rate_hz": f"{sample_rate:.6f}",
        "scope_note": point.scope_note,
    }
    if read_data is None:
        base.update(
            {
                "read_control_hex": "",
                "read_status_hex": "",
                "read_phase_inc_hex": "",
                "read_frequency_hz": "",
                "read_amplitude_hex": "",
                "read_wave_mode": "",
            }
        )
    else:
        base.update(
            {
                "read_control_hex": f"0x{int(read_data['read_control']):08X}",
                "read_status_hex": f"0x{int(read_data['read_status']):08X}",
                "read_phase_inc_hex": f"0x{int(read_data['read_phase_inc']):012X}",
                "read_frequency_hz": f"{float(read_data['read_frequency_hz']):.6f}",
                "read_amplitude_hex": f"0x{int(read_data['read_amplitude']):04X}",
                "read_wave_mode": str(int(read_data["read_wave_mode"])),
            }
        )
    return base


def write_csv(path: Path, rows: Iterable[dict[str, str]]) -> None:
    rows = list(rows)
    if not rows:
        raise ValueError("no rows to write")
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=list(rows[0].keys()))
        writer.writeheader()
        writer.writerows(rows)


def run_profile(
    *,
    profile: str,
    out: str | Path,
    port: str | None = None,
    baud: int = 115200,
    timeout: float = 1.0,
    sample_rate: float = DEFAULT_SAMPLE_RATE,
    settle: float = 0.10,
    dry_run: bool = False,
    restore: bool = True,
) -> Path:
    points = profile_points(profile)
    rows: list[dict[str, str]] = []
    if dry_run:
        for point in points:
            phase_inc = phase_inc_from_frequency(point.frequency_hz, sample_rate)
            rows.append(row_for_point(point, phase_inc, sample_rate, port or "", True, None))
    else:
        if not port:
            raise ValueError("--port is required unless --dry-run is used")
        dev = AwgUart(port, baud, timeout)
        try:
            for point in points:
                phase_inc = write_point(dev, point, sample_rate)
                time.sleep(settle)
                rows.append(
                    row_for_point(
                        point,
                        phase_inc,
                        sample_rate,
                        port,
                        False,
                        readback(dev, sample_rate),
                    )
                )
            if restore:
                restore = SweepPoint("restore_50m_sine", RESTORE_FREQUENCY, RESTORE_AMPLITUDE, RESTORE_WAVE)
                write_point(dev, restore, sample_rate)
        finally:
            dev.close()

    out_path = Path(out)
    write_csv(out_path, rows)
    return out_path


def run_sweep(args: argparse.Namespace) -> Path:
    return run_profile(
        profile=args.profile,
        out=args.out,
        port=args.port,
        baud=args.baud,
        timeout=args.timeout,
        sample_rate=args.sample_rate,
        settle=args.settle,
        dry_run=args.dry_run,
        restore=args.restore,
    )


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Run repeatable AWG UART sweep points and save CSV readbacks.")
    parser.add_argument("--port", help="Windows COM port, for example COM7")
    parser.add_argument("--baud", type=int, default=115200)
    parser.add_argument("--timeout", type=float, default=1.0)
    parser.add_argument("--sample-rate", type=float, default=DEFAULT_SAMPLE_RATE)
    parser.add_argument("--settle", type=float, default=0.10)
    parser.add_argument("--profile", choices=["quick", "wave", "amplitude", "full"], default="quick")
    _TOOLS_DIR = Path(__file__).resolve().parent
    _BRINGUP_ROOT = _TOOLS_DIR.parent
    _DEFAULT_OUT = _BRINGUP_ROOT / "measurements" / "uart_sweeps" / "sweep_latest.csv"
    parser.add_argument("--out", default=str(_DEFAULT_OUT))
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--no-restore", dest="restore", action="store_false")
    parser.set_defaults(restore=True)
    return parser


def main(argv: list[str]) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    path = run_sweep(args)
    print(f"SWEEP_CSV={path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
