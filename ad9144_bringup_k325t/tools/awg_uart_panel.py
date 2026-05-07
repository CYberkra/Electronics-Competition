#!/usr/bin/env python3
"""Tkinter control panel for the AD9144 AWG UART variant."""

from __future__ import annotations

import queue
import sys
import threading
import time
import tkinter as tk
from datetime import datetime
from pathlib import Path
from tkinter import messagebox, ttk
from typing import Any, Callable

from awg_uart_sweep import run_profile
from awg_uart_control import (
    ADDR_AMPLITUDE,
    ADDR_APPLY,
    ADDR_BUTTON_STATE,
    ADDR_CONTROL,
    ADDR_ID,
    ADDR_OFFSET,
    ADDR_PHASE_INC_HI,
    ADDR_PHASE_INC_LO,
    ADDR_PHASE_OFFSET_HI,
    ADDR_PHASE_OFFSET_LO,
    ADDR_STATUS,
    ADDR_VERSION,
    ADDR_WAVE_MODE,
    WAVE_NAMES,
    AwgUart,
    parse_int,
    phase_inc_from_frequency,
    phase_offset_from_degrees,
)


DEFAULT_BAUD = 115200
DEFAULT_TIMEOUT = 1.0
DEFAULT_SAMPLE_RATE = 1_000_000_000.0
_TOOLS_DIR = Path(__file__).resolve().parent
_BRINGUP_ROOT = _TOOLS_DIR.parent
DEFAULT_SWEEP_DIR = _BRINGUP_ROOT / "measurements" / "uart_sweeps"


def list_ports() -> list[str]:
    serial = __import__("serial")
    list_ports_mod = __import__("serial.tools.list_ports", fromlist=["comports"])
    ports = [port.device for port in list_ports_mod.comports()]
    return sorted(ports)


def read_status(dev: AwgUart) -> dict[str, int]:
    phase_lo = dev.read_reg(ADDR_PHASE_INC_LO)
    phase_hi = dev.read_reg(ADDR_PHASE_INC_HI)
    phase_offset_lo = dev.read_reg(ADDR_PHASE_OFFSET_LO)
    phase_offset_hi = dev.read_reg(ADDR_PHASE_OFFSET_HI)
    return {
        "id": dev.read_reg(ADDR_ID),
        "version": dev.read_reg(ADDR_VERSION),
        "control": dev.read_reg(ADDR_CONTROL),
        "status": dev.read_reg(ADDR_STATUS),
        "button_state": dev.read_reg(ADDR_BUTTON_STATE),
        "phase_inc": ((phase_hi & 0xFFFF) << 32) | phase_lo,
        "phase_offset": ((phase_offset_hi & 0xFFFF) << 32) | phase_offset_lo,
        "amplitude": dev.read_reg(ADDR_AMPLITUDE) & 0xFFFF,
        "offset": dev.read_reg(ADDR_OFFSET) & 0xFFFF,
        "wave_mode": dev.read_reg(ADDR_WAVE_MODE) & 0x3,
    }


def wave_name_from_value(value: int) -> str:
    for name, mode in WAVE_NAMES.items():
        if mode == value and name != "sawtooth":
            return name
    return f"mode{value}"


def frequency_from_phase_inc(phase_inc: int, sample_rate: float) -> float:
    return phase_inc * sample_rate / float(1 << 48)


class AwgPanel(tk.Tk):
    def __init__(self) -> None:
        super().__init__()
        self.title("AD9144 AWG Control")
        self.geometry("760x520")
        self.minsize(680, 460)

        self.port_var = tk.StringVar()
        self.baud_var = tk.StringVar(value=str(DEFAULT_BAUD))
        self.sample_rate_var = tk.StringVar(value=str(int(DEFAULT_SAMPLE_RATE)))
        self.frequency_var = tk.StringVar(value="50000000")
        self.amplitude_var = tk.StringVar(value="0x6000")
        self.offset_var = tk.StringVar(value="0")
        self.phase_var = tk.StringVar(value="0")
        self.wave_var = tk.StringVar(value="sine")
        self.sweep_profile_var = tk.StringVar(value="quick")
        self.sweep_out_var = tk.StringVar(value=str(DEFAULT_SWEEP_DIR / "gui_latest.csv"))
        self.state_var = tk.StringVar(value="Idle")

        self.status_vars: dict[str, tk.StringVar] = {
            "id": tk.StringVar(value="-"),
            "version": tk.StringVar(value="-"),
            "control": tk.StringVar(value="-"),
            "status": tk.StringVar(value="-"),
            "phase_inc": tk.StringVar(value="-"),
            "frequency": tk.StringVar(value="-"),
            "amplitude": tk.StringVar(value="-"),
            "wave": tk.StringVar(value="-"),
            "button": tk.StringVar(value="-"),
        }
        self.events: queue.Queue[tuple[str, Any]] = queue.Queue()

        self._build_ui()
        self.refresh_ports()
        self.after(100, self._drain_events)

    def _build_ui(self) -> None:
        root = ttk.Frame(self, padding=10)
        root.pack(fill=tk.BOTH, expand=True)

        top = ttk.Frame(root)
        top.pack(fill=tk.X)
        ttk.Label(top, text="Port").pack(side=tk.LEFT)
        self.port_combo = ttk.Combobox(top, textvariable=self.port_var, width=14, state="readonly")
        self.port_combo.pack(side=tk.LEFT, padx=(6, 8))
        ttk.Button(top, text="Refresh", command=self.refresh_ports).pack(side=tk.LEFT)
        ttk.Label(top, text="Baud").pack(side=tk.LEFT, padx=(18, 0))
        ttk.Entry(top, textvariable=self.baud_var, width=10).pack(side=tk.LEFT, padx=(6, 8))
        ttk.Button(top, text="Read Status", command=self.read_status_async).pack(side=tk.LEFT, padx=(8, 0))
        ttk.Button(top, text="Button Control", command=self.button_control_async).pack(side=tk.LEFT, padx=(8, 0))

        main = ttk.Panedwindow(root, orient=tk.HORIZONTAL)
        main.pack(fill=tk.BOTH, expand=True, pady=(12, 8))

        controls = ttk.LabelFrame(main, text="Preset", padding=10)
        main.add(controls, weight=1)

        self._add_entry(controls, 0, "Frequency Hz", self.frequency_var)
        self._add_entry(controls, 1, "Sample Rate", self.sample_rate_var)
        self._add_entry(controls, 2, "Amplitude", self.amplitude_var)
        self._add_entry(controls, 3, "Offset", self.offset_var)
        self._add_entry(controls, 4, "Phase deg", self.phase_var)
        ttk.Label(controls, text="Wave").grid(row=5, column=0, sticky=tk.W, pady=6)
        ttk.Combobox(
            controls,
            textvariable=self.wave_var,
            values=["sine", "square", "triangle", "saw"],
            state="readonly",
            width=18,
        ).grid(row=5, column=1, sticky=tk.EW, pady=6)
        controls.columnconfigure(1, weight=1)

        apply_row = ttk.Frame(controls)
        apply_row.grid(row=6, column=0, columnspan=2, sticky=tk.EW, pady=(14, 0))
        ttk.Button(apply_row, text="Apply Preset", command=self.apply_preset_async).pack(side=tk.LEFT)
        ttk.Button(apply_row, text="Output Off", command=self.output_off_async).pack(side=tk.LEFT, padx=(8, 0))

        ttk.Separator(controls).grid(row=7, column=0, columnspan=2, sticky=tk.EW, pady=(14, 8))
        ttk.Label(controls, text="Sweep Profile").grid(row=8, column=0, sticky=tk.W, pady=6)
        ttk.Combobox(
            controls,
            textvariable=self.sweep_profile_var,
            values=["quick", "wave", "amplitude", "full"],
            state="readonly",
            width=18,
        ).grid(row=8, column=1, sticky=tk.EW, pady=6)
        self._add_entry(controls, 9, "Sweep CSV", self.sweep_out_var)
        ttk.Button(controls, text="Run Sweep", command=self.run_sweep_async).grid(
            row=10, column=0, columnspan=2, sticky=tk.W, pady=(8, 0)
        )

        status = ttk.LabelFrame(main, text="Status", padding=10)
        main.add(status, weight=2)
        labels = [
            ("ID", "id"),
            ("Version", "version"),
            ("Control", "control"),
            ("Status", "status"),
            ("Phase Inc", "phase_inc"),
            ("Frequency", "frequency"),
            ("Amplitude", "amplitude"),
            ("Wave", "wave"),
            ("Button", "button"),
        ]
        for row, (label, key) in enumerate(labels):
            ttk.Label(status, text=label).grid(row=row, column=0, sticky=tk.W, pady=3)
            ttk.Label(status, textvariable=self.status_vars[key]).grid(row=row, column=1, sticky=tk.W, pady=3, padx=(16, 0))
        status.columnconfigure(1, weight=1)

        log_frame = ttk.LabelFrame(root, text="Log", padding=8)
        log_frame.pack(fill=tk.BOTH, expand=False)
        self.log_text = tk.Text(log_frame, height=7, wrap=tk.WORD)
        self.log_text.pack(fill=tk.BOTH, expand=True)

        bottom = ttk.Frame(root)
        bottom.pack(fill=tk.X, pady=(8, 0))
        ttk.Label(bottom, textvariable=self.state_var).pack(side=tk.LEFT)

    def _add_entry(self, parent: ttk.Frame, row: int, label: str, var: tk.StringVar) -> None:
        ttk.Label(parent, text=label).grid(row=row, column=0, sticky=tk.W, pady=6)
        ttk.Entry(parent, textvariable=var, width=22).grid(row=row, column=1, sticky=tk.EW, pady=6)

    def log(self, text: str) -> None:
        stamp = time.strftime("%H:%M:%S")
        self.log_text.insert(tk.END, f"[{stamp}] {text}\n")
        self.log_text.see(tk.END)

    def refresh_ports(self) -> None:
        try:
            ports = list_ports()
        except Exception as exc:
            ports = []
            self.log(f"Port refresh failed: {exc}")
        self.port_combo["values"] = ports
        if ports and (self.port_var.get() not in ports):
            self.port_var.set(ports[-1])
        elif not ports:
            self.port_var.set("")

    def _connection_args(self) -> tuple[str, int]:
        port = self.port_var.get().strip()
        if not port:
            raise ValueError("No COM port selected")
        return port, int(self.baud_var.get(), 0)

    def _with_device(self, fn: Callable[[AwgUart], Any]) -> Any:
        port, baud = self._connection_args()
        dev = AwgUart(port, baud, DEFAULT_TIMEOUT)
        try:
            return fn(dev)
        finally:
            dev.close()

    def run_async(self, label: str, fn: Callable[[], Any]) -> None:
        self.state_var.set(f"{label}...")

        def worker() -> None:
            try:
                result = fn()
            except Exception as exc:
                self.events.put(("error", (label, exc)))
            else:
                self.events.put(("done", (label, result)))

        threading.Thread(target=worker, daemon=True).start()

    def _drain_events(self) -> None:
        while True:
            try:
                kind, payload = self.events.get_nowait()
            except queue.Empty:
                break
            if kind == "error":
                label, exc = payload
                self.state_var.set("Error")
                self.log(f"{label} failed: {exc}")
                messagebox.showerror("AD9144 AWG", str(exc))
            elif kind == "done":
                label, result = payload
                self.state_var.set("Idle")
                self.log(f"{label} complete")
                if isinstance(result, dict) and "__status__" in result:
                    self.update_status(result["__status__"])
                    if result.get("__message__"):
                        self.log(str(result["__message__"]))
                elif isinstance(result, dict):
                    self.update_status(result)
                elif result is not None:
                    self.log(str(result))
        self.after(100, self._drain_events)

    def update_status(self, data: dict[str, int]) -> None:
        sample_rate = float(self.sample_rate_var.get())
        self.status_vars["id"].set(f"0x{data['id']:08X}")
        self.status_vars["version"].set(f"0x{data['version']:08X}")
        self.status_vars["control"].set(f"0x{data['control']:08X}")
        self.status_vars["status"].set(f"0x{data['status']:08X}")
        self.status_vars["phase_inc"].set(f"0x{data['phase_inc']:012X}")
        freq = frequency_from_phase_inc(data["phase_inc"], sample_rate)
        self.status_vars["frequency"].set(f"{freq:.6f} Hz")
        self.status_vars["amplitude"].set(f"0x{data['amplitude']:04X}")
        self.status_vars["wave"].set(wave_name_from_value(data["wave_mode"]))
        self.status_vars["button"].set(f"0x{data['button_state']:08X}")

    def read_status_async(self) -> None:
        self.run_async("Read status", lambda: self._with_device(read_status))

    def apply_preset_async(self) -> None:
        def task() -> dict[str, int]:
            freq = float(self.frequency_var.get())
            sample_rate = float(self.sample_rate_var.get())
            phase_inc = phase_inc_from_frequency(freq, sample_rate)
            phase_offset = phase_offset_from_degrees(float(self.phase_var.get()))
            amplitude = parse_int(self.amplitude_var.get()) & 0xFFFF
            offset = parse_int(self.offset_var.get()) & 0xFFFF
            wave = WAVE_NAMES[self.wave_var.get()]

            def apply(dev: AwgUart) -> dict[str, int]:
                dev.set_phase_inc(phase_inc)
                dev.set_phase_offset(phase_offset)
                dev.write_reg(ADDR_AMPLITUDE, amplitude)
                dev.write_reg(ADDR_OFFSET, offset)
                dev.write_reg(ADDR_WAVE_MODE, wave)
                dev.write_reg(ADDR_CONTROL, 0x00000003)
                dev.write_reg(ADDR_APPLY, 0x00000001)
                time.sleep(0.05)
                return read_status(dev)

            return self._with_device(apply)

        self.run_async("Apply preset", task)

    def button_control_async(self) -> None:
        def task() -> dict[str, int]:
            def apply(dev: AwgUart) -> dict[str, int]:
                dev.write_reg(ADDR_CONTROL, 0x00000001)
                dev.write_reg(ADDR_APPLY, 0x00000001)
                time.sleep(0.05)
                return read_status(dev)

            return self._with_device(apply)

        self.run_async("Button control", task)

    def output_off_async(self) -> None:
        def task() -> dict[str, int]:
            def apply(dev: AwgUart) -> dict[str, int]:
                current = dev.read_reg(ADDR_CONTROL)
                dev.write_reg(ADDR_CONTROL, current & ~0x1)
                dev.write_reg(ADDR_APPLY, 0x00000001)
                time.sleep(0.05)
                return read_status(dev)

            return self._with_device(apply)

        self.run_async("Output off", task)

    def _sweep_output_path(self) -> str:
        path = self.sweep_out_var.get().strip()
        if path:
            return path
        stamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        profile = self.sweep_profile_var.get()
        return str(DEFAULT_SWEEP_DIR / f"gui_{profile}_{stamp}.csv")

    def run_sweep_async(self) -> None:
        def task() -> dict[str, Any]:
            port, baud = self._connection_args()
            profile = self.sweep_profile_var.get()
            sample_rate = float(self.sample_rate_var.get())
            out_path = run_profile(
                profile=profile,
                out=self._sweep_output_path(),
                port=port,
                baud=baud,
                timeout=DEFAULT_TIMEOUT,
                sample_rate=sample_rate,
                settle=0.05,
                dry_run=False,
                restore=True,
            )
            status = self._with_device(read_status)
            return {
                "__status__": status,
                "__message__": f"Sweep CSV: {out_path}",
            }

        self.run_async("Run sweep", task)


def main() -> int:
    if "--smoke" in sys.argv:
        print("AWG_UART_PANEL_IMPORT_OK")
        return 0
    app = AwgPanel()
    app.mainloop()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
