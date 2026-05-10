#!/usr/bin/env python3
"""Minimal PC-side controller for the AD9144 AWG UART variant."""

from __future__ import annotations

import argparse
import sys
import time


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

    return parser


def main(argv: list[str]) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    args.func(args)
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
