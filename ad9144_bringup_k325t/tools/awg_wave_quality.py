#!/usr/bin/env python3
"""Digital waveform quality check for the AD9144 AWG DDS path."""

from __future__ import annotations

import argparse
import csv
import math
import sys
from pathlib import Path

import numpy as np

try:
    from .awg_uart_control import WAVE_NAMES, phase_inc_from_frequency, phase_offset_from_degrees
    from .awg_uart_sweep import SweepPoint, profile_points
except ImportError:  # pragma: no cover - direct script execution fallback
    from awg_uart_control import WAVE_NAMES, phase_inc_from_frequency, phase_offset_from_degrees
    from awg_uart_sweep import SweepPoint, profile_points


PHASE_BITS = 48
PHASE_MASK = (1 << PHASE_BITS) - 1
LUT_BITS = 12
DEFAULT_SAMPLE_RATE = 1_000_000_000.0
DEFAULT_SAMPLE_COUNT = 20_000
_TOOLS_DIR = Path(__file__).resolve().parent
_BRINGUP_ROOT = _TOOLS_DIR.parent
DEFAULT_LUT = _BRINGUP_ROOT / "rtl" / "awg" / "ad9144_sine_4096.hex"
DEFAULT_OUT = _BRINGUP_ROOT / "reports" / "wave_quality" / "wave_quality_latest.csv"


def signed16(value: int) -> int:
    value &= 0xFFFF
    return value - 0x10000 if value & 0x8000 else value


def load_sine_lut(path: Path) -> list[int]:
    values: list[int] = []
    with path.open("r", encoding="ascii") as handle:
        for line in handle:
            text = line.strip()
            if text:
                values.append(signed16(int(text, 16)))
    if len(values) != (1 << LUT_BITS):
        raise ValueError(f"{path} has {len(values)} entries, expected {1 << LUT_BITS}")
    return values


def shape_from_addr(mode: int, addr: int) -> int:
    half_addr = addr & 0x7FF
    if mode == 1:
        return -32768 if addr & 0x800 else 32767
    if mode == 2:
        tri_unsigned = (2047 - half_addr) if addr & 0x800 else half_addr
        return (tri_unsigned - 1024) << 5
    if mode == 3:
        return (addr - 2048) << 4
    return 0


def scale_and_saturate(raw_sample: int, amplitude_q15: int, offset: int) -> int:
    shifted = (raw_sample * (amplitude_q15 & 0xFFFF)) >> 15
    summed = shifted + signed16(offset)
    if summed > 32767:
        return 32767
    if summed < -32768:
        return -32768
    return int(summed)


def raw_sample(mode: int, addr: int, sine_lut: list[int]) -> int:
    if mode == 0:
        return sine_lut[addr]
    return shape_from_addr(mode, addr)


def generate_samples(point: SweepPoint, sample_rate: float, sample_count: int, sine_lut: list[int]) -> np.ndarray:
    mode = WAVE_NAMES[point.wave]
    phase_inc = phase_inc_from_frequency(point.frequency_hz, sample_rate)
    phase_offset = phase_offset_from_degrees(point.phase_deg)
    phase_acc = 0
    samples: list[int] = []
    while len(samples) < sample_count:
        phase_base = (phase_acc + phase_offset) & PHASE_MASK
        for lane in range(4):
            phase = (phase_base + phase_inc * lane) & PHASE_MASK
            addr = phase >> (PHASE_BITS - LUT_BITS)
            raw = raw_sample(mode, addr, sine_lut)
            samples.append(scale_and_saturate(raw, point.amplitude, point.offset))
        phase_acc = (phase_acc + phase_inc * 4) & PHASE_MASK
    return np.asarray(samples[:sample_count], dtype=np.float64)


def db_ratio(numerator: float, denominator: float) -> float:
    if numerator <= 0.0:
        return float("-inf")
    if denominator <= 0.0:
        return float("inf")
    return 10.0 * math.log10(numerator / denominator)


def aliased_bin(bin_index: int, sample_count: int) -> int:
    folded = bin_index % sample_count
    if folded > sample_count // 2:
        folded = sample_count - folded
    return folded


def add_guard_bins(excluded: set[int], center: int, max_bin: int, guard: int = 1) -> None:
    for idx in range(max(0, center - guard), min(max_bin, center + guard) + 1):
        excluded.add(idx)


def analyze_samples(point: SweepPoint, samples: np.ndarray, sample_rate: float) -> dict[str, str]:
    sample_count = len(samples)
    centered = samples - float(np.mean(samples))
    spectrum = np.fft.rfft(centered)
    power = np.abs(spectrum) ** 2
    max_bin = len(power) - 1

    target_bin_exact = point.frequency_hz * sample_count / sample_rate
    target_bin = int(round(target_bin_exact))
    target_bin = max(1, min(max_bin, target_bin))
    search_lo = max(1, target_bin - 2)
    search_hi = min(max_bin, target_bin + 2)
    fund_bin = search_lo + int(np.argmax(power[search_lo : search_hi + 1]))
    fund_power = float(power[fund_bin])

    harmonic_bins: list[int] = []
    harmonic_power = 0.0
    for harmonic in range(2, 6):
        bin_idx = aliased_bin(fund_bin * harmonic, sample_count)
        if 0 < bin_idx <= max_bin:
            harmonic_bins.append(bin_idx)
            harmonic_power += float(power[bin_idx])

    excluded = {0}
    add_guard_bins(excluded, fund_bin, max_bin)
    for bin_idx in harmonic_bins:
        add_guard_bins(excluded, bin_idx, max_bin)
    spur_candidates = [idx for idx in range(1, max_bin + 1) if idx not in excluded]
    spur_bin = max(spur_candidates, key=lambda idx: power[idx]) if spur_candidates else 0
    spur_power = float(power[spur_bin]) if spur_bin else 0.0

    return {
        "label": point.label,
        "wave": point.wave,
        "target_frequency_hz": f"{point.frequency_hz:.6f}",
        "fundamental_bin": str(fund_bin),
        "fundamental_frequency_hz": f"{fund_bin * sample_rate / sample_count:.6f}",
        "coherent_bin_error": f"{target_bin_exact - round(target_bin_exact):.6f}",
        "peak_code": str(int(np.max(samples))),
        "min_code": str(int(np.min(samples))),
        "mean_code": f"{float(np.mean(samples)):.3f}",
        "rms_code": f"{float(np.sqrt(np.mean(centered * centered))):.3f}",
        "thd_2_to_5_dbc": f"{db_ratio(harmonic_power, fund_power):.2f}",
        "max_nonharmonic_spur_dbc": f"{db_ratio(spur_power, fund_power):.2f}",
        "max_nonharmonic_spur_bin": str(spur_bin),
        "sample_count": str(sample_count),
        "sample_rate_hz": f"{sample_rate:.6f}",
        "amplitude_hex": f"0x{point.amplitude & 0xFFFF:04X}",
        "offset_hex": f"0x{point.offset & 0xFFFF:04X}",
    }


def write_csv(path: Path, rows: list[dict[str, str]]) -> None:
    if not rows:
        raise ValueError("no rows to write")
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=list(rows[0].keys()))
        writer.writeheader()
        writer.writerows(rows)


def run_quality(profile: str, out: Path, sample_rate: float, sample_count: int, lut_path: Path) -> Path:
    sine_lut = load_sine_lut(lut_path)
    rows = [
        analyze_samples(point, generate_samples(point, sample_rate, sample_count, sine_lut), sample_rate)
        for point in profile_points(profile)
    ]
    write_csv(out, rows)
    for row in rows:
        print(
            "{label}: fund={fundamental_frequency_hz} Hz, THD={thd_2_to_5_dbc} dBc, "
            "spur={max_nonharmonic_spur_dbc} dBc".format(**row)
        )
    return out


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Model the AD9144 AWG DDS path and report FFT metrics.")
    parser.add_argument("--profile", choices=["quick", "wave", "amplitude", "full"], default="quick")
    parser.add_argument("--sample-rate", type=float, default=DEFAULT_SAMPLE_RATE)
    parser.add_argument("--samples", type=int, default=DEFAULT_SAMPLE_COUNT)
    parser.add_argument("--lut", type=Path, default=DEFAULT_LUT)
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
    return parser


def main(argv: list[str]) -> int:
    args = build_parser().parse_args(argv)
    if args.samples < 1024:
        raise SystemExit("--samples must be at least 1024")
    path = run_quality(args.profile, args.out, args.sample_rate, args.samples, args.lut)
    print(f"WAVE_QUALITY_CSV={path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
