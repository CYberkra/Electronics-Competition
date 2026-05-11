#!/usr/bin/env python3
"""Minimal PC-side controller for the AD9144 AWG UART variant."""

from __future__ import annotations

import argparse
import csv
import sys
import time
from pathlib import Path


ADDR_ID = 0x00
ADDR_VERSION = 0x04
ADDR_CONTROL = 0x08
ADDR_STATUS = 0x0C
ADDR_PHASE_INC_LO = 0x10
ADDR_PHASE_INC_HI = 0x14
ADDR_PHASE_OFFSET_LO = 0x18
ADDR_PHASE_OFFSET_HI = 0x1C
ADDR_AMPLITUDE = 0x20
ADDR_OFFSET = 0x24
ADDR_WAVE_MODE = 0x28
ADDR_APPLY = 0x2C
ADDR_BUTTON_STATE = 0x30
ADDR_RANGE_SEL = 0x34
ADDR_OUTPUT_EN = 0x38
ADDR_CAL_ENABLE = 0x3C
ADDR_CAL_TABLE_BASE = 0x40

CAL_TABLE_ENTRIES = 16
CAL_ENTRY_STRIDE = 4
CAL_GAIN_UNITY = 0x8000

WAVE_NAMES = {
    "sine": 0,
    "square": 1,
    "triangle": 2,
    "saw": 3,
    "sawtooth": 3,
}

DEMO_PRESETS = {
    "baseline_50m": {
        "frequency": 50_000_000.0,
        "amplitude": 0x6000,
        "offset": 0,
        "phase_deg": 0.0,
        "wave": "sine",
        "note": "Known-good OUT1 baseline for every board session.",
    },
    "low_1m": {
        "frequency": 1_000_000.0,
        "amplitude": 0x6000,
        "offset": 0,
        "phase_deg": 0.0,
        "wave": "sine",
        "note": "Low-frequency clean sine check.",
    },
    "mid_100m": {
        "frequency": 100_000_000.0,
        "amplitude": 0x6000,
        "offset": 0,
        "phase_deg": 0.0,
        "wave": "sine",
        "note": "Mid-band sine point for frequency-response logging.",
    },
    "high_300m": {
        "frequency": 300_000_000.0,
        "amplitude": 0x6000,
        "offset": 0,
        "phase_deg": 0.0,
        "wave": "sine",
        "note": "High-frequency point that stayed broadly usable in prior scope tests.",
    },
    "amp_low_50m": {
        "frequency": 50_000_000.0,
        "amplitude": 0x3000,
        "offset": 0,
        "phase_deg": 0.0,
        "wave": "sine",
        "note": "Amplitude-control low point.",
    },
    "amp_high_50m": {
        "frequency": 50_000_000.0,
        "amplitude": 0x7000,
        "offset": 0,
        "phase_deg": 0.0,
        "wave": "sine",
        "note": "Amplitude-control high point.",
    },
    "square_50m": {
        "frequency": 50_000_000.0,
        "amplitude": 0x6000,
        "offset": 0,
        "phase_deg": 0.0,
        "wave": "square",
        "note": "Waveform-mode demonstration: square.",
    },
    "triangle_50m": {
        "frequency": 50_000_000.0,
        "amplitude": 0x6000,
        "offset": 0,
        "phase_deg": 0.0,
        "wave": "triangle",
        "note": "Waveform-mode demonstration: triangle.",
    },
    "saw_50m": {
        "frequency": 50_000_000.0,
        "amplitude": 0x6000,
        "offset": 0,
        "phase_deg": 0.0,
        "wave": "saw",
        "note": "Waveform-mode demonstration: sawtooth.",
    },
}

DEMO_SEQUENCE = [
    "baseline_50m",
    "low_1m",
    "mid_100m",
    "high_300m",
    "amp_low_50m",
    "amp_high_50m",
    "square_50m",
    "triangle_50m",
    "saw_50m",
]

CAL_CSV_FIELDS = [
    "bin_index",
    "bin_center_frequency_hz",
    "sample_rate_hz",
    "target_frequency_hz",
    "target_phase_inc_hex",
    "measured_vpp_v",
    "reference_vpp_v",
    "gain_q15_hex",
    "offset_hex",
    "cal_word_hex",
    "source_rows",
    "note",
]


def parse_int(text: str) -> int:
    return int(text, 0)


def import_serial():
    try:
        import serial  # type: ignore
    except ImportError as exc:
        raise SystemExit(
            "pyserial is required. Install it with: python -m pip install pyserial"
        ) from exc
    return serial


def require_port(args: argparse.Namespace) -> str:
    port = getattr(args, "port", None)
    if not port:
        raise SystemExit("--port is required for hardware UART commands")
    return port


def cal_table_addr(index: int) -> int:
    if not 0 <= index < CAL_TABLE_ENTRIES:
        raise ValueError(f"calibration table index out of range: {index}")
    return ADDR_CAL_TABLE_BASE + CAL_ENTRY_STRIDE * index


def cal_bin_from_phase_inc(phase_inc: int) -> int:
    return (phase_inc >> 44) & 0xF


def cal_bin_center_frequency_hz(bin_index: int, sample_rate: float) -> float:
    return ((bin_index + 0.5) * sample_rate) / float(CAL_TABLE_ENTRIES)


def cal_word_from_fields(offset: int, gain: int) -> int:
    return ((offset & 0xFFFF) << 16) | (gain & 0xFFFF)


def decode_cal_word(word: int) -> tuple[int, int]:
    offset = (word >> 16) & 0xFFFF
    if offset & 0x8000:
        offset -= 0x10000
    gain = word & 0xFFFF
    return offset, gain


def format_cal_word(word: int) -> str:
    return f"0x{word & 0xFFFFFFFF:08X}"


def format_signed_hex(value: int) -> str:
    return f"0x{value & 0xFFFF:04X}"


def parse_csv_int(row: dict[str, str], *keys: str, default: int | None = None) -> int | None:
    for key in keys:
        text = (row.get(key) or "").strip()
        if text:
            return int(text, 0)
    return default


def parse_csv_float(row: dict[str, str], *keys: str, default: float | None = None) -> float | None:
    for key in keys:
        text = (row.get(key) or "").strip()
        if text:
            return float(text)
    return default


def read_csv_rows(path: Path) -> list[dict[str, str]]:
    with path.open("r", newline="", encoding="utf-8-sig") as handle:
        rows = list(csv.DictReader(handle))
    if not rows:
        raise ValueError(f"{path} contains no rows")
    return rows


def write_csv_rows(path: Path, rows: list[dict[str, str]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=CAL_CSV_FIELDS, extrasaction="ignore")
        writer.writeheader()
        writer.writerows(rows)


class AwgUart:
    def __init__(self, port: str, baud: int, timeout: float) -> None:
        serial = import_serial()
        self.ser = serial.Serial(port=port, baudrate=baud, timeout=timeout)
        self.ser.reset_input_buffer()

    def close(self) -> None:
        self.ser.close()

    def _line(self, text: str) -> str:
        self.ser.write((text + "\n").encode("ascii"))
        self.ser.flush()
        response = self.ser.readline().decode("ascii", errors="replace").strip()
        if not response:
            raise RuntimeError(f"timeout waiting for response to {text!r}")
        if response == "ERR":
            raise RuntimeError(f"FPGA returned ERR for {text!r}")
        return response

    def write_reg(self, addr: int, data: int) -> None:
        response = self._line(f"W {addr & 0xFF:02X} {data & 0xFFFFFFFF:08X}")
        if response != "OK":
            raise RuntimeError(f"unexpected write response: {response!r}")

    def read_reg(self, addr: int) -> int:
        response = self._line(f"R {addr & 0xFF:02X}")
        if not response.startswith("D "):
            raise RuntimeError(f"unexpected read response: {response!r}")
        return int(response[2:].strip(), 16)

    def set_phase_inc(self, value: int) -> None:
        value &= (1 << 48) - 1
        self.write_reg(ADDR_PHASE_INC_LO, value & 0xFFFFFFFF)
        self.write_reg(ADDR_PHASE_INC_HI, (value >> 32) & 0xFFFF)

    def set_phase_offset(self, value: int) -> None:
        value &= (1 << 48) - 1
        self.write_reg(ADDR_PHASE_OFFSET_LO, value & 0xFFFFFFFF)
        self.write_reg(ADDR_PHASE_OFFSET_HI, (value >> 32) & 0xFFFF)

    def set_cal_enable(self, enabled: bool) -> None:
        self.write_reg(ADDR_CAL_ENABLE, 1 if enabled else 0)

    def write_cal_entry(self, index: int, word: int) -> None:
        self.write_reg(cal_table_addr(index), word & 0xFFFFFFFF)

    def read_cal_entry(self, index: int) -> int:
        return self.read_reg(cal_table_addr(index))


def phase_inc_from_frequency(freq_hz: float, sample_rate: float) -> int:
    if freq_hz < 0:
        raise ValueError("frequency must be non-negative")
    return int(round(freq_hz * (1 << 48) / sample_rate)) & ((1 << 48) - 1)


def phase_offset_from_degrees(degrees: float) -> int:
    return int(round((degrees % 360.0) * (1 << 48) / 360.0)) & ((1 << 48) - 1)


def format_preset_line(name: str, preset: dict[str, object], sample_rate: float) -> str:
    phase_inc = phase_inc_from_frequency(float(preset["frequency"]), sample_rate)
    phase_offset = phase_offset_from_degrees(float(preset["phase_deg"]))
    return (
        f"{name}: freq={float(preset['frequency']):.6f}Hz "
        f"phase_inc=0x{phase_inc:012X} "
        f"amp=0x{int(preset['amplitude']):04X} "
        f"offset=0x{int(preset['offset']) & 0xFFFF:04X} "
        f"phase=0x{phase_offset:012X} "
        f"wave={preset['wave']} - {preset['note']}"
    )


def apply_waveform_preset(
    dev: AwgUart,
    *,
    frequency: float,
    sample_rate: float,
    amplitude: int,
    offset: int,
    phase_deg: float,
    wave: str,
) -> tuple[int, int]:
    phase_inc = phase_inc_from_frequency(frequency, sample_rate)
    phase_offset = phase_offset_from_degrees(phase_deg)
    dev.set_phase_inc(phase_inc)
    dev.set_phase_offset(phase_offset)
    dev.write_reg(ADDR_AMPLITUDE, amplitude & 0xFFFF)
    dev.write_reg(ADDR_OFFSET, offset & 0xFFFF)
    dev.write_reg(ADDR_WAVE_MODE, WAVE_NAMES[wave])
    dev.write_reg(ADDR_CONTROL, 0x00000003)
    dev.write_reg(ADDR_APPLY, 0x00000001)
    return phase_inc, phase_offset


def print_status(dev: AwgUart) -> None:
    reg_id = dev.read_reg(ADDR_ID)
    version = dev.read_reg(ADDR_VERSION)
    control = dev.read_reg(ADDR_CONTROL)
    status = dev.read_reg(ADDR_STATUS)
    button = dev.read_reg(ADDR_BUTTON_STATE)
    range_sel = dev.read_reg(ADDR_RANGE_SEL)
    cal_enable = dev.read_reg(ADDR_CAL_ENABLE)
    phase_lo = dev.read_reg(ADDR_PHASE_INC_LO)
    phase_hi = dev.read_reg(ADDR_PHASE_INC_HI)
    amplitude = dev.read_reg(ADDR_AMPLITUDE)
    wave = dev.read_reg(ADDR_WAVE_MODE)
    phase_inc = ((phase_hi & 0xFFFF) << 32) | phase_lo

    print(f"ID=0x{reg_id:08X}")
    print(f"VERSION=0x{version:08X}")
    print(f"CONTROL=0x{control:08X}")
    print(f"STATUS=0x{status:08X}")
    print(f"BUTTON_STATE=0x{button:08X}")
    print(f"RANGE_SEL=0x{range_sel:08X}")
    print(f"CAL_ENABLE=0x{cal_enable:08X}")
    print(f"PHASE_INC=0x{phase_inc:012X}")
    print(f"AMPLITUDE=0x{amplitude & 0xFFFF:04X}")
    print(f"WAVE_MODE={wave & 0x3}")


def cmd_read(args: argparse.Namespace) -> None:
    dev = AwgUart(require_port(args), args.baud, args.timeout)
    try:
        print(f"0x{dev.read_reg(args.addr):08X}")
    finally:
        dev.close()


def cmd_write(args: argparse.Namespace) -> None:
    dev = AwgUart(require_port(args), args.baud, args.timeout)
    try:
        dev.write_reg(args.addr, args.data)
        print("OK")
    finally:
        dev.close()


def cmd_status(args: argparse.Namespace) -> None:
    dev = AwgUart(require_port(args), args.baud, args.timeout)
    try:
        print_status(dev)
    finally:
        dev.close()


def cmd_button(args: argparse.Namespace) -> None:
    dev = AwgUart(require_port(args), args.baud, args.timeout)
    try:
        dev.write_reg(ADDR_CONTROL, 0x00000001)
        dev.write_reg(ADDR_APPLY, 0x00000001)
        print("button control enabled")
    finally:
        dev.close()


def cmd_preset(args: argparse.Namespace) -> None:
    phase_inc = phase_inc_from_frequency(args.frequency, args.sample_rate)
    phase_offset = phase_offset_from_degrees(args.phase_deg)
    amplitude = parse_int(args.amplitude) & 0xFFFF
    offset = parse_int(args.offset) & 0xFFFF

    dev = AwgUart(require_port(args), args.baud, args.timeout)
    try:
        apply_waveform_preset(
            dev,
            frequency=args.frequency,
            sample_rate=args.sample_rate,
            amplitude=amplitude,
            offset=offset,
            phase_deg=args.phase_deg,
            wave=args.wave,
        )
        time.sleep(0.05)
        print(f"phase_inc=0x{phase_inc:012X}")
        print(f"phase_offset=0x{phase_offset:012X}")
        print("register control enabled")
        print_status(dev)
    finally:
        dev.close()


def cmd_demo(args: argparse.Namespace) -> None:
    if args.list:
        for name in DEMO_SEQUENCE:
            print(format_preset_line(name, DEMO_PRESETS[name], args.sample_rate))
        return

    if not args.name:
        raise SystemExit("demo requires a preset name, 'all', or --list")

    names = DEMO_SEQUENCE if args.name == "all" else [args.name]
    for name in names:
        if name not in DEMO_PRESETS:
            raise SystemExit(f"unknown demo preset: {name}")

    if args.dry_run:
        for name in names:
            print(format_preset_line(name, DEMO_PRESETS[name], args.sample_rate))
        return

    dev = AwgUart(require_port(args), args.baud, args.timeout)
    try:
        for name in names:
            preset = DEMO_PRESETS[name]
            phase_inc, phase_offset = apply_waveform_preset(
                dev,
                frequency=float(preset["frequency"]),
                sample_rate=args.sample_rate,
                amplitude=int(preset["amplitude"]),
                offset=int(preset["offset"]),
                phase_deg=float(preset["phase_deg"]),
                wave=str(preset["wave"]),
            )
            print(f"{name}: phase_inc=0x{phase_inc:012X} phase_offset=0x{phase_offset:012X}")
            if args.step_delay > 0:
                time.sleep(args.step_delay)
        print_status(dev)
    finally:
        dev.close()


def load_calibration_rows(path: Path) -> list[tuple[int, int, int, dict[str, str]]]:
    rows = read_csv_rows(path)
    entries: list[tuple[int, int, int, dict[str, str]]] = []
    for row in rows:
        index = parse_csv_int(row, "bin_index", "index", "cal_bin")
        if index is None:
            raise ValueError(f"{path} row is missing bin_index")
        if not 0 <= index < CAL_TABLE_ENTRIES:
            raise ValueError(f"{path} row has invalid bin_index: {index}")

        word = parse_csv_int(row, "cal_word_hex", "cal_word")
        if word is None:
            gain = parse_csv_int(row, "gain_q15_hex", "gain_q15", "gain", default=CAL_GAIN_UNITY)
            offset = parse_csv_int(row, "offset_hex", "offset", default=0)
            if gain is None:
                gain = CAL_GAIN_UNITY
            if offset is None:
                offset = 0
            word = cal_word_from_fields(offset, gain)

        offset, gain = decode_cal_word(word)
        entries.append((index, offset, gain, row))
    return entries


def format_calibration_line(
    index: int,
    word: int,
    sample_rate: float,
    note: str = "",
) -> str:
    offset, gain = decode_cal_word(word)
    center = cal_bin_center_frequency_hz(index, sample_rate)
    suffix = f" - {note}" if note else ""
    return (
        f"bin {index:02d} center={center:.3f} Hz "
        f"word=0x{word & 0xFFFFFFFF:08X} "
        f"offset=0x{offset & 0xFFFF:04X} "
        f"gain=0x{gain:04X}{suffix}"
    )


def cmd_cal_dump(args: argparse.Namespace) -> None:
    dev = AwgUart(require_port(args), args.baud, args.timeout)
    try:
        rows: list[dict[str, str]] = []
        for index in range(CAL_TABLE_ENTRIES):
            word = dev.read_cal_entry(index)
            offset, gain = decode_cal_word(word)
            rows.append(
                {
                    "bin_index": str(index),
                    "bin_center_frequency_hz": f"{cal_bin_center_frequency_hz(index, args.sample_rate):.6f}",
                    "sample_rate_hz": f"{args.sample_rate:.6f}",
                    "gain_q15_hex": f"0x{gain:04X}",
                    "offset_hex": format_signed_hex(offset),
                    "cal_word_hex": format_cal_word(word),
                    "note": "readback",
                }
            )
        if args.out:
            write_csv_rows(args.out, rows)
            print(f"CAL_CSV={args.out}")
            return
        for row in rows:
            print(
                format_calibration_line(
                    int(row["bin_index"]),
                    int(row["cal_word_hex"], 16),
                    args.sample_rate,
                    row["note"],
                )
            )
    finally:
        dev.close()


def cmd_cal_load(args: argparse.Namespace) -> None:
    entries = load_calibration_rows(args.input)
    if args.dry_run:
        for index, offset, gain, row in entries:
            word = cal_word_from_fields(offset, gain)
            note = row.get("note", "")
            print(format_calibration_line(index, word, args.sample_rate, note))
        return

    dev = AwgUart(require_port(args), args.baud, args.timeout)
    try:
        for index, offset, gain, row in entries:
            word = cal_word_from_fields(offset, gain)
            dev.write_cal_entry(index, word)
            note = row.get("note", "")
            print(format_calibration_line(index, word, args.sample_rate, note))
        if args.enable:
            dev.set_cal_enable(True)
        elif args.disable:
            dev.set_cal_enable(False)
        time.sleep(0.05)
        print_status(dev)
    finally:
        dev.close()


def cmd_cal_enable(args: argparse.Namespace) -> None:
    dev = AwgUart(require_port(args), args.baud, args.timeout)
    try:
        dev.set_cal_enable(True)
        time.sleep(0.05)
        print("calibration enabled")
        print_status(dev)
    finally:
        dev.close()


def cmd_cal_disable(args: argparse.Namespace) -> None:
    dev = AwgUart(require_port(args), args.baud, args.timeout)
    try:
        dev.set_cal_enable(False)
        time.sleep(0.05)
        print("calibration disabled")
        print_status(dev)
    finally:
        dev.close()


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Control the AD9144 AWG UART variant.")
    parser.add_argument("--port", help="Windows COM port, for example COM3")
    parser.add_argument("--baud", type=int, default=115200)
    parser.add_argument("--timeout", type=float, default=1.0)

    sub = parser.add_subparsers(dest="command", required=True)

    read = sub.add_parser("read", help="Read one register")
    read.add_argument("addr", type=parse_int)
    read.set_defaults(func=cmd_read)

    write = sub.add_parser("write", help="Write one register")
    write.add_argument("addr", type=parse_int)
    write.add_argument("data", type=parse_int)
    write.set_defaults(func=cmd_write)

    status = sub.add_parser("status", help="Read key status registers")
    status.set_defaults(func=cmd_status)

    button = sub.add_parser("button", help="Return to physical button control")
    button.set_defaults(func=cmd_button)

    preset = sub.add_parser("preset", help="Program a waveform preset and enable register control")
    preset.add_argument("--frequency", type=float, default=50_000_000.0)
    preset.add_argument("--sample-rate", type=float, default=1_000_000_000.0)
    preset.add_argument("--amplitude", default="0x6000")
    preset.add_argument("--offset", default="0")
    preset.add_argument("--phase-deg", type=float, default=0.0)
    preset.add_argument("--wave", choices=sorted(WAVE_NAMES), default="sine")
    preset.set_defaults(func=cmd_preset)

    demo = sub.add_parser("demo", help="Run or print named competition demo presets")
    demo.add_argument("name", nargs="?", help="Preset name, or 'all'")
    demo.add_argument("--list", action="store_true", help="List available demo presets")
    demo.add_argument("--dry-run", action="store_true", help="Print register-equivalent settings without opening UART")
    demo.add_argument("--sample-rate", type=float, default=1_000_000_000.0)
    demo.add_argument("--step-delay", type=float, default=0.25, help="Delay between presets when running 'all'")
    demo.set_defaults(func=cmd_demo)

    cal = sub.add_parser("cal", help="Read, write, or toggle the calibration table")
    cal_sub = cal.add_subparsers(dest="cal_command", required=True)

    cal_dump = cal_sub.add_parser("dump", help="Read calibration table entries from hardware")
    cal_dump.add_argument("--out", type=Path, help="Write the calibration table to CSV")
    cal_dump.add_argument("--sample-rate", type=float, default=1_000_000_000.0)
    cal_dump.set_defaults(func=cmd_cal_dump)

    cal_load = cal_sub.add_parser("load", help="Load calibration table entries from CSV")
    cal_load.add_argument("--input", type=Path, required=True)
    load_mode = cal_load.add_mutually_exclusive_group()
    load_mode.add_argument("--enable", action="store_true", help="Enable calibration after loading")
    load_mode.add_argument("--disable", action="store_true", help="Disable calibration after loading")
    cal_load.add_argument("--dry-run", action="store_true", help="Print parsed entries without opening UART")
    cal_load.add_argument("--sample-rate", type=float, default=1_000_000_000.0)
    cal_load.set_defaults(func=cmd_cal_load)

    cal_enable = cal_sub.add_parser("enable", help="Enable digital calibration")
    cal_enable.set_defaults(func=cmd_cal_enable)

    cal_disable = cal_sub.add_parser("disable", help="Disable digital calibration")
    cal_disable.set_defaults(func=cmd_cal_disable)

    return parser


def main(argv: list[str]) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    args.func(args)
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
