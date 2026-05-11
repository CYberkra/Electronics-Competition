"""Qt upper-computer UI for the AD9144 bring-up workflow."""

from __future__ import annotations

import csv
import os
import sys
import tempfile
import threading
import traceback
from dataclasses import dataclass
from datetime import datetime
from pathlib import Path
from typing import Any, Callable

os.environ.setdefault("PYQTGRAPH_QT_LIB", "PySide6")

import pyqtgraph as pg
from PySide6.QtCore import QObject, QSettings, QTimer, Qt, QUrl, Signal
from PySide6.QtGui import QAction, QDesktopServices, QFont, QIcon
from PySide6.QtWidgets import (
    QAbstractItemView,
    QApplication,
    QCheckBox,
    QComboBox,
    QDoubleSpinBox,
    QFileDialog,
    QFrame,
    QGridLayout,
    QGroupBox,
    QHBoxLayout,
    QHeaderView,
    QLabel,
    QLineEdit,
    QListWidget,
    QListWidgetItem,
    QMainWindow,
    QMessageBox,
    QPushButton,
    QPlainTextEdit,
    QSplitter,
    QSpinBox,
    QStackedWidget,
    QStyle,
    QTableWidget,
    QTableWidgetItem,
    QTextBrowser,
    QToolButton,
    QVBoxLayout,
    QWidget,
)

from . import backend
from .theme import apply_theme
from ad9144_bringup_k325t.tools import awg_uart_control as ctrl


pg.setConfigOptions(antialias=True)


@dataclass(slots=True)
class ControlSettings:
    frequency_hz: float
    sample_rate_hz: float
    amplitude: int
    offset: int
    phase_deg: float
    wave: str
    range_sel: int
    output_enable: bool
    use_reg_control: bool
    cal_enable: bool


class SignalHub(QObject):
    success = Signal(int, object)
    failure = Signal(int, str, str)


def _std_icon(widget: QWidget, icon: QStyle.StandardPixmap) -> QIcon:
    return widget.style().standardIcon(icon)


def _open_path(path: str | Path) -> None:
    target = Path(path)
    if target.is_dir():
        QDesktopServices.openUrl(QUrl.fromLocalFile(str(target)))
    else:
        QDesktopServices.openUrl(QUrl.fromLocalFile(str(target.parent)))


def _parse_optional_float(text: str) -> float | None:
    text = text.strip()
    if not text:
        return None
    return float(text)


def _read_csv_rows(path: Path) -> tuple[list[str], list[dict[str, str]]]:
    with path.open("r", newline="", encoding="utf-8-sig") as handle:
        reader = csv.DictReader(handle)
        rows = list(reader)
        if not rows:
            raise ValueError(f"{path} contains no rows")
        return list(reader.fieldnames or []), rows


def _write_csv_rows(path: Path, rows: list[dict[str, str]], fieldnames: list[str]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)


class MetricCard(QFrame):
    def __init__(self, title: str, value: str = "--", subtitle: str = "", parent: QWidget | None = None) -> None:
        super().__init__(parent)
        self.setObjectName("Card")
        layout = QVBoxLayout(self)
        layout.setContentsMargins(14, 12, 14, 12)
        layout.setSpacing(6)
        self.title_label = QLabel(title)
        self.title_label.setObjectName("MetricLabel")
        self.value_label = QLabel(value)
        self.value_label.setObjectName("MetricValue")
        self.value_label.setWordWrap(True)
        self.subtitle_label = QLabel(subtitle)
        self.subtitle_label.setObjectName("Hint")
        self.subtitle_label.setWordWrap(True)
        layout.addWidget(self.title_label)
        layout.addWidget(self.value_label)
        layout.addWidget(self.subtitle_label)

    def set_value(self, value: str) -> None:
        self.value_label.setText(value)

    def set_subtitle(self, value: str) -> None:
        self.subtitle_label.setText(value)


class StatePill(QLabel):
    def __init__(self, text: str = "--", parent: QWidget | None = None) -> None:
        super().__init__(text, parent)
        self.setObjectName("Pill")
        self.setProperty("on", False)
        self.setProperty("warn", False)
        self.setProperty("bad", False)
        self.setContentsMargins(6, 4, 6, 4)

    def set_state(self, text: str, *, on: bool = False, warn: bool = False, bad: bool = False) -> None:
        self.setText(text)
        self.setProperty("on", on)
        self.setProperty("warn", warn)
        self.setProperty("bad", bad)
        self.style().unpolish(self)
        self.style().polish(self)


class PlotCard(QFrame):
    def __init__(self, title: str, parent: QWidget | None = None) -> None:
        super().__init__(parent)
        self.setObjectName("Card")
        layout = QVBoxLayout(self)
        layout.setContentsMargins(14, 12, 14, 12)
        layout.setSpacing(8)
        header = QLabel(title)
        header.setObjectName("SectionTitle")
        self.plot = pg.PlotWidget()
        self.plot.setBackground(None)
        self.plot.showGrid(x=True, y=True, alpha=0.18)
        self.plot.setMenuEnabled(False)
        self.plot.getPlotItem().getViewBox().setMouseEnabled(x=False, y=False)
        self.curve = self.plot.plot([], [], pen=pg.mkPen("#5bd0ff", width=2))
        self.overlay = QLabel("")
        self.overlay.setObjectName("Hint")
        layout.addWidget(header)
        layout.addWidget(self.plot, 1)
        layout.addWidget(self.overlay)

    def set_curve(self, x: Any, y: Any, *, title: str = "", subtitle: str = "") -> None:
        self.curve.setData(x, y)
        if subtitle:
            self.overlay.setText(subtitle)
        if title:
            self.plot.setTitle(title)


class ListPreviewTable(QTableWidget):
    def __init__(self, parent: QWidget | None = None) -> None:
        super().__init__(parent)
        self.setAlternatingRowColors(True)
        self.setSelectionBehavior(QAbstractItemView.SelectionBehavior.SelectRows)
        self.setEditTriggers(QAbstractItemView.EditTrigger.NoEditTriggers)
        self.horizontalHeader().setStretchLastSection(True)
        self.horizontalHeader().setSectionResizeMode(QHeaderView.ResizeMode.Stretch)

    def load_csv(self, path: Path, limit: int = 200) -> None:
        header, rows = _read_csv_rows(path)
        self.setColumnCount(len(header))
        self.setHorizontalHeaderLabels(header)
        self.setRowCount(min(len(rows), limit))
        for row_idx, row in enumerate(rows[:limit]):
            for col_idx, key in enumerate(header):
                item = QTableWidgetItem(row.get(key, ""))
                self.setItem(row_idx, col_idx, item)


class DashboardPage(QWidget):
    def __init__(self, main: "UpperHostWindow") -> None:
        super().__init__(main)
        self.main = main
        layout = QVBoxLayout(self)
        layout.setContentsMargins(0, 0, 0, 0)
        layout.setSpacing(12)

        top = QFrame()
        top.setObjectName("Card")
        top_layout = QGridLayout(top)
        top_layout.setContentsMargins(14, 12, 14, 12)
        top_layout.setHorizontalSpacing(12)
        top_layout.setVerticalSpacing(10)

        title = QLabel("AD9144 Upper Host")
        title.setObjectName("SectionTitle")
        subtitle = QLabel("K325T + FMCADDA-9250-9144 control and measurement console")
        subtitle.setObjectName("Hint")
        subtitle.setWordWrap(True)
        top_layout.addWidget(title, 0, 0, 1, 2)
        top_layout.addWidget(subtitle, 1, 0, 1, 2)

        self.port_card = MetricCard("Connection", "--", "Select COM port and read status")
        self.freq_card = MetricCard("Frequency", "--", "Derived from phase increment and sample rate")
        self.wave_card = MetricCard("Wave / Range", "--", "Waveform mode and frontend range")
        self.cal_card = MetricCard("Calibration", "--", "Digital calibration gate")
        top_layout.addWidget(self.port_card, 2, 0)
        top_layout.addWidget(self.freq_card, 2, 1)
        top_layout.addWidget(self.wave_card, 3, 0)
        top_layout.addWidget(self.cal_card, 3, 1)

        self.flag_row = QWidget()
        flag_layout = QHBoxLayout(self.flag_row)
        flag_layout.setContentsMargins(0, 0, 0, 0)
        flag_layout.setSpacing(8)
        self.flags: dict[str, StatePill] = {}
        for name in ["Output", "Reg Ctrl", "TX Ready", "TX Sync", "SYSREF", "Sample", "Apply", "Cal"]:
            pill = StatePill(name)
            self.flags[name] = pill
            flag_layout.addWidget(pill)
        flag_layout.addStretch(1)
        top_layout.addWidget(self.flag_row, 4, 0, 1, 2)

        actions = QWidget()
        action_layout = QHBoxLayout(actions)
        action_layout.setContentsMargins(0, 0, 0, 0)
        action_layout.setSpacing(8)
        self.read_button = QPushButton(_std_icon(self, QStyle.SP_BrowserReload), "Read Status")
        self.baseline_button = QPushButton(_std_icon(self, QStyle.SP_MediaPlay), "Apply Baseline")
        self.button_mode_button = QPushButton(_std_icon(self, QStyle.SP_DialogResetButton), "Button Control")
        self.output_off_button = QPushButton(_std_icon(self, QStyle.SP_MediaStop), "Output Off")
        for btn in [self.read_button, self.baseline_button, self.button_mode_button, self.output_off_button]:
            action_layout.addWidget(btn)
        action_layout.addStretch(1)
        top_layout.addWidget(actions, 5, 0, 1, 2)

        self.preview = PlotCard("Waveform Preview")

        layout.addWidget(top)
        layout.addWidget(self.preview, 1)

        self.read_button.clicked.connect(self.main.read_status)
        self.baseline_button.clicked.connect(self.main.apply_baseline)
        self.button_mode_button.clicked.connect(self.main.set_button_control)
        self.output_off_button.clicked.connect(self.main.set_output_off)

    def update_snapshot(self, snapshot: backend.StatusSnapshot | None) -> None:
        if snapshot is None:
            self.port_card.set_value("--")
            self.port_card.set_subtitle("No hardware status yet")
            self.freq_card.set_value("--")
            self.freq_card.set_subtitle("")
            self.wave_card.set_value("--")
            self.wave_card.set_subtitle("")
            self.cal_card.set_value("--")
            self.cal_card.set_subtitle("")
            for pill in self.flags.values():
                pill.set_state(pill.text())
            return

        self.port_card.set_value(f"{snapshot.port} @ {snapshot.baud}")
        self.port_card.set_subtitle(f"ID 0x{snapshot.reg_id:08X} / version 0x{snapshot.version:08X}")
        self.freq_card.set_value(f"{snapshot.frequency_hz/1e6:.3f} MHz")
        self.freq_card.set_subtitle(f"Phase inc 0x{snapshot.phase_inc:012X}")
        self.wave_card.set_value(f"{snapshot.wave_name} / {snapshot.range_name}")
        self.wave_card.set_subtitle(f"Amplitude 0x{snapshot.amplitude:04X}  Offset 0x{snapshot.offset:04X}")
        self.cal_card.set_value("Enabled" if snapshot.cal_enable else "Disabled")
        self.cal_card.set_subtitle(f"Control 0x{snapshot.control:08X}  Status 0x{snapshot.status:08X}")
        for name, state in snapshot.status_flags():
            pill = self.flags.get(name)
            if pill is not None:
                pill.set_state(name, on=state, warn=(name == "TX Sync" and not state), bad=(name in {"TX Ready", "Sample"} and not state))

    def update_preview(self, x: Any, y: Any, *, stats: dict[str, float], settings: ControlSettings) -> None:
        title = f"{settings.wave}  {settings.frequency_hz/1e6:.3f} MHz  amp 0x{settings.amplitude:04X}"
        subtitle = (
            f"min {stats['min']:.1f}  max {stats['max']:.1f}  "
            f"rms {stats['rms']:.1f}  vpp {stats['vpp']:.1f}"
        )
        self.preview.set_curve(x, y, title=title, subtitle=subtitle)


class ControlPage(QWidget):
    def __init__(self, main: "UpperHostWindow") -> None:
        super().__init__(main)
        self.main = main
        layout = QVBoxLayout(self)
        layout.setContentsMargins(0, 0, 0, 0)
        layout.setSpacing(12)

        card = QFrame()
        card.setObjectName("Card")
        grid = QGridLayout(card)
        grid.setContentsMargins(14, 12, 14, 12)
        grid.setHorizontalSpacing(12)
        grid.setVerticalSpacing(10)
        row = 0

        header = QLabel("Waveform Studio")
        header.setObjectName("SectionTitle")
        hint = QLabel("Manual waveform, amplitude, phase, output and calibration control.")
        hint.setObjectName("Hint")
        hint.setWordWrap(True)
        grid.addWidget(header, row, 0, 1, 4)
        row += 1
        grid.addWidget(hint, row, 0, 1, 4)
        row += 1

        self.demo_combo = QComboBox()
        self.demo_combo.addItems(backend.demo_preset_names())
        self.frequency = QDoubleSpinBox()
        self.frequency.setRange(0.0, 1_200_000_000.0)
        self.frequency.setDecimals(3)
        self.frequency.setSingleStep(1_000_000.0)
        self.sample_rate = QDoubleSpinBox()
        self.sample_rate.setRange(1.0, 5_000_000_000.0)
        self.sample_rate.setDecimals(3)
        self.sample_rate.setSingleStep(10_000_000.0)
        self.sample_rate.setValue(backend.DEFAULT_SAMPLE_RATE)
        self.amplitude = QLineEdit("0x6000")
        self.offset = QLineEdit("0x0000")
        self.phase_deg = QDoubleSpinBox()
        self.phase_deg.setRange(0.0, 360.0)
        self.phase_deg.setDecimals(3)
        self.phase_deg.setSingleStep(5.0)
        self.wave = QComboBox()
        self.wave.addItems(backend.WAVE_CHOICES)
        self.range_sel = QComboBox()
        self.range_sel.addItems([f"{idx}: {name}" for idx, name in backend.RANGE_NAMES.items()])
        self.output_enable = QCheckBox("Output enable")
        self.output_enable.setChecked(True)
        self.use_reg_control = QCheckBox("Register control")
        self.use_reg_control.setChecked(True)
        self.cal_enable = QCheckBox("Calibration")
        self.cal_enable.setChecked(False)
        self.demo_step_delay = QDoubleSpinBox()
        self.demo_step_delay.setRange(0.0, 5.0)
        self.demo_step_delay.setDecimals(2)
        self.demo_step_delay.setSingleStep(0.25)
        self.demo_step_delay.setValue(0.25)

        self._add_field(grid, row, "Demo preset", self.demo_combo)
        row += 1
        self._add_field(grid, row, "Frequency Hz", self.frequency)
        row += 1
        self._add_field(grid, row, "Sample rate Hz", self.sample_rate)
        row += 1
        self._add_field(grid, row, "Amplitude", self.amplitude)
        row += 1
        self._add_field(grid, row, "Offset", self.offset)
        row += 1
        self._add_field(grid, row, "Phase deg", self.phase_deg)
        row += 1
        self._add_field(grid, row, "Wave", self.wave)
        row += 1
        self._add_field(grid, row, "Range", self.range_sel)
        row += 1
        self._add_field(grid, row, "Demo step delay", self.demo_step_delay)
        row += 1

        flags = QWidget()
        flag_layout = QHBoxLayout(flags)
        flag_layout.setContentsMargins(0, 0, 0, 0)
        flag_layout.setSpacing(14)
        flag_layout.addWidget(self.output_enable)
        flag_layout.addWidget(self.use_reg_control)
        flag_layout.addWidget(self.cal_enable)
        flag_layout.addStretch(1)
        grid.addWidget(flags, row, 0, 1, 4)
        row += 1

        btn_row = QWidget()
        btn_layout = QHBoxLayout(btn_row)
        btn_layout.setContentsMargins(0, 0, 0, 0)
        btn_layout.setSpacing(8)
        self.load_demo_button = QPushButton(_std_icon(self, QStyle.SP_DialogOpenButton), "Load Demo")
        self.apply_demo_button = QPushButton(_std_icon(self, QStyle.SP_MediaPlay), "Apply Demo")
        self.apply_preset_button = QPushButton(_std_icon(self, QStyle.SP_DialogApplyButton), "Apply Preset")
        self.set_range_button = QPushButton(_std_icon(self, QStyle.SP_ArrowRight), "Set Range")
        self.read_button = QPushButton(_std_icon(self, QStyle.SP_BrowserReload), "Read Status")
        self.button_control_button = QPushButton(_std_icon(self, QStyle.SP_DialogResetButton), "Button Control")
        self.output_off_button = QPushButton(_std_icon(self, QStyle.SP_MediaStop), "Output Off")
        self.cal_on_button = QPushButton(_std_icon(self, QStyle.SP_DialogYesButton), "Cal On")
        self.cal_off_button = QPushButton(_std_icon(self, QStyle.SP_DialogNoButton), "Cal Off")
        for btn in [
            self.load_demo_button,
            self.apply_demo_button,
            self.apply_preset_button,
            self.set_range_button,
            self.read_button,
            self.button_control_button,
            self.output_off_button,
            self.cal_on_button,
            self.cal_off_button,
        ]:
            btn_layout.addWidget(btn)
        btn_layout.addStretch(1)
        grid.addWidget(btn_row, row, 0, 1, 4)

        summary = QFrame()
        summary.setObjectName("SubCard")
        summary_layout = QHBoxLayout(summary)
        summary_layout.setContentsMargins(12, 10, 12, 10)
        summary_layout.setSpacing(10)
        self.summary_label = QLabel("Ready.")
        self.summary_label.setWordWrap(True)
        summary_layout.addWidget(self.summary_label, 1)
        grid.addWidget(summary, row + 1, 0, 1, 4)

        layout.addWidget(card)

        self.load_demo_button.clicked.connect(self.load_selected_demo)
        self.apply_demo_button.clicked.connect(self.main.apply_selected_demo)
        self.apply_preset_button.clicked.connect(self.main.apply_current_settings)
        self.set_range_button.clicked.connect(self.main.set_range_from_page)
        self.read_button.clicked.connect(self.main.read_status)
        self.button_control_button.clicked.connect(self.main.set_button_control)
        self.output_off_button.clicked.connect(self.main.set_output_off)
        self.cal_on_button.clicked.connect(lambda: self.main.set_cal_enable(True))
        self.cal_off_button.clicked.connect(lambda: self.main.set_cal_enable(False))

        for widget in [self.frequency, self.sample_rate, self.amplitude, self.offset, self.phase_deg, self.wave, self.range_sel, self.output_enable, self.use_reg_control, self.cal_enable]:
            if isinstance(widget, QComboBox):
                widget.currentIndexChanged.connect(self.main.schedule_preview_refresh)
            elif isinstance(widget, QLineEdit):
                widget.textChanged.connect(self.main.schedule_preview_refresh)
            elif isinstance(widget, QCheckBox):
                widget.toggled.connect(self.main.schedule_preview_refresh)
            else:
                widget.valueChanged.connect(self.main.schedule_preview_refresh)  # type: ignore[arg-type]

    def _add_field(self, grid: QGridLayout, row: int, label: str, widget: QWidget) -> None:
        lbl = QLabel(label)
        lbl.setObjectName("MetricLabel")
        grid.addWidget(lbl, row, 0)
        grid.addWidget(widget, row, 1, 1, 3)

    def settings(self) -> ControlSettings:
        range_sel = self.range_sel.currentIndex()
        return ControlSettings(
            frequency_hz=self.frequency.value(),
            sample_rate_hz=self.sample_rate.value(),
            amplitude=ctrl.parse_int(self.amplitude.text()) & 0xFFFF,
            offset=ctrl.parse_int(self.offset.text()) & 0xFFFF,
            phase_deg=self.phase_deg.value(),
            wave=self.wave.currentText(),
            range_sel=range_sel,
            output_enable=self.output_enable.isChecked(),
            use_reg_control=self.use_reg_control.isChecked(),
            cal_enable=self.cal_enable.isChecked(),
        )

    def load_demo(self, name: str) -> None:
        preset = backend.demo_preset_dict(name)
        self.demo_combo.setCurrentText(name)
        self.frequency.setValue(float(preset["frequency"]))
        self.amplitude.setText(f"0x{int(preset['amplitude']) & 0xFFFF:04X}")
        self.offset.setText(f"0x{int(preset['offset']) & 0xFFFF:04X}")
        self.phase_deg.setValue(float(preset["phase_deg"]))
        self.wave.setCurrentText(str(preset["wave"]))
        self.range_sel.setCurrentIndex(0)
        self.output_enable.setChecked(True)
        self.use_reg_control.setChecked(True)
        self.cal_enable.setChecked(False)
        self.summary_label.setText(f"Loaded demo preset: {name} — {preset['note']}")
        self.main.schedule_preview_refresh()

    def load_snapshot(self, snapshot: backend.StatusSnapshot) -> None:
        self.frequency.setValue(snapshot.frequency_hz)
        self.amplitude.setText(f"0x{snapshot.amplitude:04X}")
        self.offset.setText(f"0x{snapshot.offset:04X}")
        self.phase_deg.setValue((snapshot.phase_offset / float(1 << 48)) * 360.0)
        self.wave.setCurrentText(snapshot.wave_name)
        self.range_sel.setCurrentIndex(snapshot.range_sel)
        self.output_enable.setChecked(snapshot.output_enable)
        self.use_reg_control.setChecked(snapshot.use_reg_control)
        self.cal_enable.setChecked(snapshot.cal_enable)
        self.summary_label.setText(
            f"Snapshot loaded from {snapshot.port}: CONTROL=0x{snapshot.control:08X}, STATUS=0x{snapshot.status:08X}"
        )

    def load_selected_demo(self) -> None:
        self.load_demo(self.demo_combo.currentText())


class MeasurementPage(QWidget):
    def __init__(self, main: "UpperHostWindow") -> None:
        super().__init__(main)
        self.main = main
        layout = QVBoxLayout(self)
        layout.setContentsMargins(0, 0, 0, 0)
        layout.setSpacing(12)

        card = QFrame()
        card.setObjectName("Card")
        grid = QGridLayout(card)
        grid.setContentsMargins(14, 12, 14, 12)
        grid.setHorizontalSpacing(10)
        grid.setVerticalSpacing(10)

        header = QLabel("Measurements and Reports")
        header.setObjectName("SectionTitle")
        hint = QLabel("Generate scope templates, Markdown reports, calibration tables, and digital waveform QA outputs.")
        hint.setObjectName("Hint")
        hint.setWordWrap(True)
        grid.addWidget(header, 0, 0, 1, 4)
        grid.addWidget(hint, 1, 0, 1, 4)

        self.scope_input = QLineEdit()
        self.scope_output = QLineEdit()
        self.sweep_source = QLineEdit()
        self.template_profile = QComboBox()
        self.template_profile.addItems(["freq_response", "high_freq_detail", "amplitude_linearity", "wave_modes"])
        self.quality_profile = QComboBox()
        self.quality_profile.addItems(["quick", "wave", "amplitude", "full"])
        self.sample_rate = QDoubleSpinBox()
        self.sample_rate.setRange(1.0, 5_000_000_000.0)
        self.sample_rate.setDecimals(3)
        self.sample_rate.setValue(1_000_000_000.0)
        self.reference_frequency = QDoubleSpinBox()
        self.reference_frequency.setRange(1.0, 1_200_000_000.0)
        self.reference_frequency.setDecimals(3)
        self.reference_frequency.setValue(50_000_000.0)
        self.reference_vpp = QLineEdit()
        self.reference_vpp.setPlaceholderText("auto")
        self.report_preview = QTextBrowser()
        self.report_preview.setMinimumHeight(220)
        self.table_preview = ListPreviewTable()

        self._add_field(grid, 2, "Scope CSV", self.scope_input)
        self._add_field(grid, 3, "Template profile", self.template_profile)
        self._add_field(grid, 4, "Quality profile", self.quality_profile)
        self._add_field(grid, 5, "Sweep source CSV", self.sweep_source)
        self._add_field(grid, 6, "Output path", self.scope_output)
        self._add_field(grid, 7, "Sample rate", self.sample_rate)
        self._add_field(grid, 8, "Reference frequency", self.reference_frequency)
        self._add_field(grid, 9, "Reference Vpp", self.reference_vpp)

        btn_row = QWidget()
        btn_layout = QHBoxLayout(btn_row)
        btn_layout.setContentsMargins(0, 0, 0, 0)
        btn_layout.setSpacing(8)
        self.browse_input = QPushButton(_std_icon(self, QStyle.SP_DialogOpenButton), "Open CSV")
        self.preview_input = QPushButton(_std_icon(self, QStyle.SP_FileDialogDetailedView), "Preview CSV")
        self.template_button = QPushButton(_std_icon(self, QStyle.SP_FileIcon), "Generate Template")
        self.report_button = QPushButton(_std_icon(self, QStyle.SP_FileDialogContentsView), "Generate Report")
        self.calibration_button = QPushButton(_std_icon(self, QStyle.SP_DialogApplyButton), "Generate Calibration")
        self.quality_button = QPushButton(_std_icon(self, QStyle.SP_BrowserReload), "Digital QA")
        self.open_output_button = QPushButton(_std_icon(self, QStyle.SP_DirOpenIcon), "Open Folder")
        for btn in [
            self.browse_input,
            self.preview_input,
            self.template_button,
            self.report_button,
            self.calibration_button,
            self.quality_button,
            self.open_output_button,
        ]:
            btn_layout.addWidget(btn)
        btn_layout.addStretch(1)
        grid.addWidget(btn_row, 10, 0, 1, 4)

        self.status_label = QLabel("No measurement file loaded.")
        self.status_label.setObjectName("Hint")
        self.status_label.setWordWrap(True)
        grid.addWidget(self.status_label, 11, 0, 1, 4)

        layout.addWidget(card)

        preview_split = QSplitter(Qt.Horizontal)
        preview_split.addWidget(self.table_preview)
        preview_split.addWidget(self.report_preview)
        preview_split.setStretchFactor(0, 2)
        preview_split.setStretchFactor(1, 1)
        layout.addWidget(preview_split, 1)

        self.browse_input.clicked.connect(self.choose_scope_csv)
        self.preview_input.clicked.connect(self.preview_scope_csv)
        self.template_button.clicked.connect(self.generate_template)
        self.report_button.clicked.connect(self.generate_report)
        self.calibration_button.clicked.connect(self.generate_calibration)
        self.quality_button.clicked.connect(self.generate_wave_quality)
        self.open_output_button.clicked.connect(self.open_output_folder)

    def _add_field(self, grid: QGridLayout, row: int, label: str, widget: QWidget) -> None:
        lbl = QLabel(label)
        lbl.setObjectName("MetricLabel")
        grid.addWidget(lbl, row, 0)
        grid.addWidget(widget, row, 1, 1, 3)

    def set_scope_csv(self, path: str | Path) -> None:
        self.scope_input.setText(str(path))

    def set_status(self, text: str) -> None:
        self.status_label.setText(text)

    def show_markdown(self, text: str, path: str | Path | None = None) -> None:
        self.report_preview.setMarkdown(text)
        if path is not None:
            self.set_status(f"Markdown updated: {path}")

    def load_preview_file(self, path: Path) -> None:
        self.table_preview.load_csv(path)
        self.set_status(f"Previewing: {path}")

    def choose_scope_csv(self) -> None:
        path, _ = QFileDialog.getOpenFileName(self, "Open scope CSV", str(backend.BRINGUP_ROOT), "CSV Files (*.csv)")
        if path:
            self.set_scope_csv(path)

    def preview_scope_csv(self) -> None:
        path = Path(self.scope_input.text().strip())
        if not path.exists():
            QMessageBox.warning(self, "AD9144 Upper Host", "Scope CSV not found.")
            return
        self.main.run_task(
            "Preview scope CSV",
            lambda: path,
            on_success=lambda result: self.load_preview_file(Path(result)),
        )

    def generate_template(self) -> None:
        scope_source = Path(self.sweep_source.text().strip()) if self.sweep_source.text().strip() else None
        out_text = self.scope_output.text().strip()
        out_path = Path(out_text) if out_text else None
        profile = self.template_profile.currentText()
        sample_rate = self.sample_rate.value()

        def task() -> backend.FileArtifact:
            return backend.build_scope_template(
                profile=profile,
                sample_rate_hz=sample_rate,
                out=out_path,
                from_sweep=scope_source if scope_source and scope_source.exists() else None,
            )

        def done(artifact: backend.FileArtifact) -> None:
            self.set_scope_csv(artifact.path)
            self.load_preview_file(artifact.path)
            self.set_status(f"Template generated: {artifact.path} ({artifact.row_count} rows)")

        self.main.run_task("Generate scope template", task, on_success=done)

    def generate_report(self) -> None:
        input_path = Path(self.scope_input.text().strip())
        if not input_path.exists():
            QMessageBox.warning(self, "AD9144 Upper Host", "Load a scope CSV first.")
            return
        out_text = self.scope_output.text().strip()
        out_path = Path(out_text) if out_text else None

        def task() -> backend.ReportArtifact:
            return backend.build_scope_report(input_path=input_path, out=out_path)

        def done(artifact: backend.ReportArtifact) -> None:
            self.show_markdown(artifact.markdown, artifact.path)
            self.set_status(f"Report generated: {artifact.path} ({artifact.row_count} rows, {artifact.filled_count} filled)")

        self.main.run_task("Generate scope report", task, on_success=done)

    def generate_calibration(self) -> None:
        input_path = Path(self.scope_input.text().strip())
        if not input_path.exists():
            QMessageBox.warning(self, "AD9144 Upper Host", "Load a scope CSV first.")
            return
        out_text = self.scope_output.text().strip()
        out_path = Path(out_text) if out_text else None
        reference_vpp = None
        try:
            reference_vpp = _parse_optional_float(self.reference_vpp.text())
        except ValueError:
            QMessageBox.warning(self, "AD9144 Upper Host", "Reference Vpp must be a number or blank.")
            return

        def task() -> backend.CalibrationArtifact:
            return backend.build_calibration_table(
                input_path=input_path,
                sample_rate_hz=self.sample_rate.value(),
                reference_frequency_hz=self.reference_frequency.value(),
                reference_vpp_v=reference_vpp,
                out=out_path,
            )

        def done(artifact: backend.CalibrationArtifact) -> None:
            self.set_scope_csv(artifact.path)
            self.set_status(
                f"Calibration table generated: {artifact.path} (reference bin {artifact.reference_bin}, Vpp {artifact.reference_vpp:.6f})"
            )
            self.main.calibration_page.load_rows(artifact.rows)

        self.main.run_task("Generate calibration", task, on_success=done)

    def generate_wave_quality(self) -> None:
        out_text = self.scope_output.text().strip()
        out_path = Path(out_text) if out_text else None

        def task() -> Path:
            return backend.generate_wave_quality(
                profile=self.quality_profile.currentText(),
                sample_rate_hz=self.sample_rate.value(),
                sample_count=4096,
                out=out_path,
            )

        self.main.run_task("Digital waveform QA", task, on_success=lambda path: self.set_status(f"Wave quality report: {path}"))

    def open_output_folder(self) -> None:
        path_text = self.scope_output.text().strip()
        if not path_text:
            path_text = str(backend.DEFAULT_SCOPE_TEMPLATE_DIR)
        _open_path(path_text)


class CalibrationPage(QWidget):
    def __init__(self, main: "UpperHostWindow") -> None:
        super().__init__(main)
        self.main = main
        layout = QVBoxLayout(self)
        layout.setContentsMargins(0, 0, 0, 0)
        layout.setSpacing(12)

        card = QFrame()
        card.setObjectName("Card")
        grid = QGridLayout(card)
        grid.setContentsMargins(14, 12, 14, 12)
        grid.setHorizontalSpacing(10)
        grid.setVerticalSpacing(10)

        header = QLabel("Calibration Studio")
        header.setObjectName("SectionTitle")
        hint = QLabel("Edit the 16-bin calibration table, dump the current hardware table, or load a CSV back to the board.")
        hint.setObjectName("Hint")
        hint.setWordWrap(True)
        grid.addWidget(header, 0, 0, 1, 4)
        grid.addWidget(hint, 1, 0, 1, 4)

        btn_row = QWidget()
        btn_layout = QHBoxLayout(btn_row)
        btn_layout.setContentsMargins(0, 0, 0, 0)
        btn_layout.setSpacing(8)
        self.load_button = QPushButton(_std_icon(self, QStyle.SP_DialogOpenButton), "Load CSV")
        self.save_button = QPushButton(_std_icon(self, QStyle.SP_DialogSaveButton), "Save CSV")
        self.dump_button = QPushButton(_std_icon(self, QStyle.SP_ArrowDown), "Dump Hardware")
        self.write_button = QPushButton(_std_icon(self, QStyle.SP_ArrowUp), "Load To Hardware")
        self.enable_button = QPushButton(_std_icon(self, QStyle.SP_DialogYesButton), "Enable")
        self.disable_button = QPushButton(_std_icon(self, QStyle.SP_DialogNoButton), "Disable")
        self.unity_button = QPushButton(_std_icon(self, QStyle.SP_FileDialogDetailedView), "Fill Unity")
        for btn in [
            self.load_button,
            self.save_button,
            self.dump_button,
            self.write_button,
            self.enable_button,
            self.disable_button,
            self.unity_button,
        ]:
            btn_layout.addWidget(btn)
        btn_layout.addStretch(1)
        grid.addWidget(btn_row, 2, 0, 1, 4)

        self.path_edit = QLineEdit()
        self.path_edit.setPlaceholderText("calibration CSV path")
        self.sample_rate = QDoubleSpinBox()
        self.sample_rate.setRange(1.0, 5_000_000_000.0)
        self.sample_rate.setDecimals(3)
        self.sample_rate.setValue(1_000_000_000.0)
        self.status_label = QLabel("No calibration table loaded.")
        self.status_label.setObjectName("Hint")
        self.status_label.setWordWrap(True)
        self._add_field(grid, 3, "Calibration file", self.path_edit)
        self._add_field(grid, 4, "Sample rate", self.sample_rate)
        grid.addWidget(self.status_label, 5, 0, 1, 4)

        layout.addWidget(card)

        body = QSplitter(Qt.Horizontal)
        self.table = QTableWidget()
        self.table.setAlternatingRowColors(True)
        self.table.setSelectionBehavior(QAbstractItemView.SelectionBehavior.SelectRows)
        self.table.setRowCount(16)
        self.table.setColumnCount(len(ctrl.CAL_CSV_FIELDS))
        self.table.setHorizontalHeaderLabels(ctrl.CAL_CSV_FIELDS)
        self.table.horizontalHeader().setStretchLastSection(True)
        self.table.horizontalHeader().setSectionResizeMode(QHeaderView.ResizeMode.Stretch)
        self.table.cellChanged.connect(self._on_cell_changed)
        self.chart = PlotCard("Gain per Bin")
        body.addWidget(self.table)
        body.addWidget(self.chart)
        body.setStretchFactor(0, 3)
        body.setStretchFactor(1, 2)
        layout.addWidget(body, 1)

        self.load_button.clicked.connect(self.load_from_path)
        self.save_button.clicked.connect(self.save_to_path)
        self.dump_button.clicked.connect(self.dump_from_hardware)
        self.write_button.clicked.connect(self.write_to_hardware)
        self.enable_button.clicked.connect(lambda: self.main.set_cal_enable(True))
        self.disable_button.clicked.connect(lambda: self.main.set_cal_enable(False))
        self.unity_button.clicked.connect(self.fill_unity)

        self.fill_unity()

    def _add_field(self, grid: QGridLayout, row: int, label: str, widget: QWidget) -> None:
        lbl = QLabel(label)
        lbl.setObjectName("MetricLabel")
        grid.addWidget(lbl, row, 0)
        grid.addWidget(widget, row, 1, 1, 3)

    def set_status(self, text: str) -> None:
        self.status_label.setText(text)

    def fill_unity(self) -> None:
        self.table.blockSignals(True)
        try:
            for row in range(16):
                values = {
                    "bin_index": str(row),
                    "bin_center_frequency_hz": f"{((row + 0.5) * self.sample_rate.value()) / 16.0:.6f}",
                    "sample_rate_hz": f"{self.sample_rate.value():.6f}",
                    "target_frequency_hz": f"{((row + 0.5) * self.sample_rate.value()) / 16.0:.6f}",
                    "target_phase_inc_hex": f"0x{ctrl.phase_inc_from_frequency(((row + 0.5) * self.sample_rate.value()) / 16.0, self.sample_rate.value()):012X}",
                    "measured_vpp_v": "",
                    "reference_vpp_v": "",
                    "gain_q15_hex": "0x8000",
                    "offset_hex": "0x0000",
                    "cal_word_hex": "0x00008000",
                    "source_rows": "0",
                    "note": "unity",
                }
                for col, key in enumerate(ctrl.CAL_CSV_FIELDS):
                    self.table.setItem(row, col, QTableWidgetItem(values[key]))
        finally:
            self.table.blockSignals(False)
        self._refresh_chart()
        self.set_status("Unity table loaded.")

    def load_rows(self, rows: list[dict[str, str]]) -> None:
        self.table.blockSignals(True)
        try:
            self.table.setRowCount(16)
            for row_idx, row in enumerate(rows[:16]):
                for col_idx, key in enumerate(ctrl.CAL_CSV_FIELDS):
                    item = QTableWidgetItem(row.get(key, ""))
                    self.table.setItem(row_idx, col_idx, item)
        finally:
            self.table.blockSignals(False)
        self._refresh_chart()
        self.set_status("Calibration table loaded.")

    def rows(self) -> list[dict[str, str]]:
        rows: list[dict[str, str]] = []
        for row in range(self.table.rowCount()):
            row_data: dict[str, str] = {}
            for col, key in enumerate(ctrl.CAL_CSV_FIELDS):
                item = self.table.item(row, col)
                row_data[key] = item.text().strip() if item is not None else ""
            rows.append(row_data)
        return rows

    def _on_cell_changed(self, *_args: Any) -> None:
        self._refresh_chart()

    def _refresh_chart(self) -> None:
        gains: list[float] = []
        bins: list[int] = []
        for row in self.rows():
            try:
                bins.append(int(row["bin_index"], 0))
                gains.append(int(row["gain_q15_hex"], 0))
            except Exception:
                continue
        if bins:
            self.chart.set_curve(
                bins,
                gains,
                title="Calibration gain per bin",
                subtitle=f"min {min(gains):#06x}  max {max(gains):#06x}",
            )

    def load_from_path(self) -> None:
        path, _ = QFileDialog.getOpenFileName(self, "Open calibration CSV", str(backend.BRINGUP_ROOT), "CSV Files (*.csv)")
        if not path:
            return
        self.path_edit.setText(path)
        self.load_rows_from_csv(Path(path))

    def load_rows_from_csv(self, path: Path) -> None:
        rows = ctrl.read_csv_rows(path)
        self.load_rows(rows)
        self.set_status(f"Loaded calibration CSV: {path}")

    def save_to_path(self) -> None:
        path_text = self.path_edit.text().strip()
        if not path_text:
            path, _ = QFileDialog.getSaveFileName(self, "Save calibration CSV", str(backend.DEFAULT_CALIBRATION_DIR), "CSV Files (*.csv)")
            if not path:
                return
            path_text = path
            self.path_edit.setText(path_text)
        path = Path(path_text)
        _write_csv_rows(path, self.rows(), ctrl.CAL_CSV_FIELDS)
        self.set_status(f"Saved calibration CSV: {path}")

    def dump_from_hardware(self) -> None:
        def task() -> list[dict[str, str]]:
            port = self.main.selected_port()
            if not port:
                raise ValueError("No COM port selected")
            return backend.dump_calibration_rows(
                port,
                baud=self.main.baud_value(),
                timeout=self.main.timeout_value(),
                sample_rate_hz=self.sample_rate.value(),
            )

        def done(rows: list[dict[str, str]]) -> None:
            self.load_rows(rows)
            self.set_status("Hardware calibration table dumped.")

        self.main.run_task("Dump calibration", task, on_success=done)

    def write_to_hardware(self) -> None:
        def task() -> backend.StatusSnapshot:
            port = self.main.selected_port()
            if not port:
                raise ValueError("No COM port selected")
            with tempfile.NamedTemporaryFile("w", delete=False, suffix=".csv", encoding="utf-8", newline="") as handle:
                temp_path = Path(handle.name)
                writer = csv.DictWriter(handle, fieldnames=ctrl.CAL_CSV_FIELDS)
                writer.writeheader()
                writer.writerows(self.rows())
            try:
                return backend.load_calibration_to_hardware(
                    port,
                    input_path=temp_path,
                    enable=self.main.control_page.cal_enable.isChecked(),
                    baud=self.main.baud_value(),
                    timeout=self.main.timeout_value(),
                    sample_rate_hz=self.sample_rate.value(),
                )
            finally:
                try:
                    temp_path.unlink(missing_ok=True)
                except Exception:
                    pass

        self.main.run_task("Load calibration", task)


class NavigationList(QListWidget):
    def __init__(self, parent: QWidget | None = None) -> None:
        super().__init__(parent)
        self.setFixedWidth(210)
        self.setSpacing(4)

    def add_page(self, text: str, icon: QIcon) -> None:
        item = QListWidgetItem(icon, text)
        size = item.sizeHint()
        size.setHeight(int(size.height() * 1.35))
        item.setSizeHint(size)
        self.addItem(item)


class UpperHostWindow(QMainWindow):
    def __init__(self, *, smoke: bool = False) -> None:
        super().__init__()
        self.smoke = smoke
        self.settings = QSettings("OpenAI", "AD9144UpperHost")
        self._task_seq = 0
        self._pending: dict[int, tuple[str, Callable[[Any], None] | None]] = {}
        self._active_tasks = 0
        self.snapshot: backend.StatusSnapshot | None = None
        self._preferred_port = ""
        self._preview_timer = QTimer(self)
        self._preview_timer.setSingleShot(True)
        self._preview_timer.timeout.connect(self.refresh_preview)
        self.signals = SignalHub()
        self.signals.success.connect(self._on_task_success)
        self.signals.failure.connect(self._on_task_failure)

        self.setWindowTitle("AD9144 Upper Host")
        self.resize(1540, 980)

        root = QWidget()
        root_layout = QVBoxLayout(root)
        root_layout.setContentsMargins(10, 10, 10, 10)
        root_layout.setSpacing(10)

        top_bar = QFrame()
        top_bar.setObjectName("TopBar")
        top_layout = QGridLayout(top_bar)
        top_layout.setContentsMargins(12, 10, 12, 10)
        top_layout.setHorizontalSpacing(10)
        top_layout.setVerticalSpacing(8)

        self.port_combo = QComboBox()
        self.port_combo.setMinimumWidth(220)
        self.refresh_ports_button = QToolButton()
        self.refresh_ports_button.setIcon(_std_icon(self, QStyle.SP_BrowserReload))
        self.refresh_ports_button.setToolTip("Refresh COM ports")
        self.baud_spin = QSpinBox()
        self.baud_spin.setRange(1200, 4_000_000)
        self.baud_spin.setValue(backend.DEFAULT_BAUD)
        self.timeout_spin = QDoubleSpinBox()
        self.timeout_spin.setRange(0.1, 10.0)
        self.timeout_spin.setDecimals(2)
        self.timeout_spin.setValue(backend.DEFAULT_TIMEOUT)
        self.sample_rate_spin = QDoubleSpinBox()
        self.sample_rate_spin.setRange(1.0, 5_000_000_000.0)
        self.sample_rate_spin.setDecimals(3)
        self.sample_rate_spin.setValue(backend.DEFAULT_SAMPLE_RATE)
        self.read_button = QPushButton(_std_icon(self, QStyle.SP_BrowserReload), "Read Status")
        self.quick_baseline_button = QPushButton(_std_icon(self, QStyle.SP_MediaPlay), "Baseline")
        self.connection_pill = StatePill("Disconnected")
        self.connection_pill.set_state("Disconnected", bad=True)

        top_layout.addWidget(QLabel("COM Port"), 0, 0)
        top_layout.addWidget(self.port_combo, 0, 1)
        top_layout.addWidget(self.refresh_ports_button, 0, 2)
        top_layout.addWidget(QLabel("Baud"), 0, 3)
        top_layout.addWidget(self.baud_spin, 0, 4)
        top_layout.addWidget(QLabel("Timeout"), 0, 5)
        top_layout.addWidget(self.timeout_spin, 0, 6)
        top_layout.addWidget(QLabel("Sample rate"), 0, 7)
        top_layout.addWidget(self.sample_rate_spin, 0, 8)
        top_layout.addWidget(self.read_button, 0, 9)
        top_layout.addWidget(self.quick_baseline_button, 0, 10)
        top_layout.addWidget(self.connection_pill, 0, 11)

        body = QSplitter(Qt.Horizontal)
        body.setChildrenCollapsible(False)
        self.nav = NavigationList()
        self.nav.add_page("Dashboard", _std_icon(self, QStyle.SP_ComputerIcon))
        self.nav.add_page("Control", _std_icon(self, QStyle.SP_MediaPlay))
        self.nav.add_page("Measurements", _std_icon(self, QStyle.SP_DirIcon))
        self.nav.add_page("Calibration", _std_icon(self, QStyle.SP_FileDialogDetailedView))
        self.stack = QStackedWidget()
        self.dashboard_page = DashboardPage(self)
        self.control_page = ControlPage(self)
        self.measurement_page = MeasurementPage(self)
        self.calibration_page = CalibrationPage(self)
        self.stack.addWidget(self.dashboard_page)
        self.stack.addWidget(self.control_page)
        self.stack.addWidget(self.measurement_page)
        self.stack.addWidget(self.calibration_page)
        body.addWidget(self.nav)
        body.addWidget(self.stack)
        body.setStretchFactor(1, 1)

        log_card = QFrame()
        log_card.setObjectName("Card")
        log_layout = QVBoxLayout(log_card)
        log_layout.setContentsMargins(12, 10, 12, 10)
        log_layout.setSpacing(8)
        log_header = QLabel("Console")
        log_header.setObjectName("SectionTitle")
        self.log_console = QPlainTextEdit()
        self.log_console.setReadOnly(True)
        self.log_console.setMaximumBlockCount(2_000)
        log_layout.addWidget(log_header)
        log_layout.addWidget(self.log_console, 1)

        vsplit = QSplitter(Qt.Vertical)
        body_wrap = QWidget()
        body_layout = QVBoxLayout(body_wrap)
        body_layout.setContentsMargins(0, 0, 0, 0)
        body_layout.addWidget(body)
        vsplit.addWidget(body_wrap)
        vsplit.addWidget(log_card)
        vsplit.setStretchFactor(0, 5)
        vsplit.setStretchFactor(1, 2)

        root_layout.addWidget(top_bar)
        root_layout.addWidget(vsplit, 1)
        self.setCentralWidget(root)

        self.statusBar().showMessage("Ready")
        self._make_menu()
        self._wire_top_bar()
        self._wire_navigation()
        self._load_settings()
        self.refresh_ports()
        self.schedule_preview_refresh()
        self.dashboard_page.update_snapshot(None)

    def _make_menu(self) -> None:
        file_menu = self.menuBar().addMenu("&File")
        refresh_action = QAction("Refresh Ports", self)
        refresh_action.triggered.connect(self.refresh_ports)
        smoke_action = QAction("Run Smoke Check", self)
        smoke_action.triggered.connect(self.run_smoke_check)
        quit_action = QAction("Quit", self)
        quit_action.triggered.connect(self.close)
        file_menu.addAction(refresh_action)
        file_menu.addAction(smoke_action)
        file_menu.addSeparator()
        file_menu.addAction(quit_action)

        help_menu = self.menuBar().addMenu("&Help")
        help_action = QAction("Open Documentation", self)
        help_action.triggered.connect(lambda: _open_path(backend.BRINGUP_ROOT / "README.md"))
        help_menu.addAction(help_action)

    def _wire_top_bar(self) -> None:
        self.refresh_ports_button.clicked.connect(self.refresh_ports)
        self.read_button.clicked.connect(self.read_status)
        self.quick_baseline_button.clicked.connect(self.apply_baseline)
        self.port_combo.currentIndexChanged.connect(lambda *_: self.schedule_preview_refresh())
        self.sample_rate_spin.valueChanged.connect(self._sync_sample_rate)
        self.baud_spin.valueChanged.connect(lambda *_: self.save_settings())
        self.timeout_spin.valueChanged.connect(lambda *_: self.save_settings())
        self.control_page.sample_rate.valueChanged.connect(self._sync_sample_rate)
        self.measurement_page.sample_rate.valueChanged.connect(self._sync_sample_rate)
        self.calibration_page.sample_rate.valueChanged.connect(self._sync_sample_rate)

    def _wire_navigation(self) -> None:
        self.nav.currentRowChanged.connect(self.stack.setCurrentIndex)
        self.nav.setCurrentRow(0)

    def _load_settings(self) -> None:
        self.baud_spin.setValue(int(self.settings.value("baud", backend.DEFAULT_BAUD)))
        self.timeout_spin.setValue(float(self.settings.value("timeout", backend.DEFAULT_TIMEOUT)))
        self.sample_rate_spin.setValue(float(self.settings.value("sample_rate", backend.DEFAULT_SAMPLE_RATE)))
        self.control_page.frequency.setValue(float(self.settings.value("frequency", 50_000_000.0)))
        self.control_page.sample_rate.setValue(float(self.settings.value("sample_rate", backend.DEFAULT_SAMPLE_RATE)))
        self.control_page.amplitude.setText(str(self.settings.value("amplitude", "0x6000")))
        self.control_page.offset.setText(str(self.settings.value("offset", "0x0000")))
        self.control_page.phase_deg.setValue(float(self.settings.value("phase_deg", 0.0)))
        self.control_page.wave.setCurrentText(str(self.settings.value("wave", "sine")))
        self.control_page.demo_combo.setCurrentText(str(self.settings.value("demo", backend.demo_preset_names()[0])))
        self.measurement_page.scope_input.setText(str(self.settings.value("scope_csv", "")))
        self.measurement_page.scope_output.setText(str(self.settings.value("scope_out", "")))
        self.measurement_page.sweep_source.setText(str(self.settings.value("sweep_source", "")))
        self.measurement_page.template_profile.setCurrentText(str(self.settings.value("template_profile", "freq_response")))
        self.measurement_page.quality_profile.setCurrentText(str(self.settings.value("quality_profile", "quick")))
        self.measurement_page.reference_frequency.setValue(float(self.settings.value("reference_frequency", 50_000_000.0)))
        self.measurement_page.reference_vpp.setText(str(self.settings.value("reference_vpp", "")))
        self.calibration_page.path_edit.setText(str(self.settings.value("calibration_csv", "")))
        self.calibration_page.sample_rate.setValue(float(self.settings.value("sample_rate", backend.DEFAULT_SAMPLE_RATE)))
        saved_port = str(self.settings.value("port", ""))
        self._preferred_port = saved_port

    def save_settings(self) -> None:
        self.settings.setValue("port", self.selected_port() or "")
        self.settings.setValue("baud", self.baud_value())
        self.settings.setValue("timeout", self.timeout_value())
        self.settings.setValue("sample_rate", self.sample_rate_value())
        self.settings.setValue("frequency", self.control_page.frequency.value())
        self.settings.setValue("amplitude", self.control_page.amplitude.text())
        self.settings.setValue("offset", self.control_page.offset.text())
        self.settings.setValue("phase_deg", self.control_page.phase_deg.value())
        self.settings.setValue("wave", self.control_page.wave.currentText())
        self.settings.setValue("demo", self.control_page.demo_combo.currentText())
        self.settings.setValue("scope_csv", self.measurement_page.scope_input.text())
        self.settings.setValue("scope_out", self.measurement_page.scope_output.text())
        self.settings.setValue("sweep_source", self.measurement_page.sweep_source.text())
        self.settings.setValue("template_profile", self.measurement_page.template_profile.currentText())
        self.settings.setValue("quality_profile", self.measurement_page.quality_profile.currentText())
        self.settings.setValue("reference_frequency", self.measurement_page.reference_frequency.value())
        self.settings.setValue("reference_vpp", self.measurement_page.reference_vpp.text())
        self.settings.setValue("calibration_csv", self.calibration_page.path_edit.text())

    def closeEvent(self, event) -> None:  # type: ignore[override]
        self.save_settings()
        super().closeEvent(event)

    def log(self, text: str) -> None:
        stamp = datetime.now().strftime("%H:%M:%S")
        self.log_console.appendPlainText(f"[{stamp}] {text}")

    def selected_port(self) -> str:
        return self.port_combo.currentData() or self.port_combo.currentText().split(" — ")[0].strip()

    def _select_port(self, port: str) -> None:
        for idx in range(self.port_combo.count()):
            if self.port_combo.itemData(idx) == port:
                self.port_combo.setCurrentIndex(idx)
                return
        if self.port_combo.count() > 0:
            self.port_combo.setCurrentIndex(0)

    def baud_value(self) -> int:
        return int(self.baud_spin.value())

    def timeout_value(self) -> float:
        return float(self.timeout_spin.value())

    def sample_rate_value(self) -> float:
        return float(self.sample_rate_spin.value())

    def refresh_ports(self) -> None:
        current = self.selected_port() or self._preferred_port
        self.port_combo.blockSignals(True)
        try:
            self.port_combo.clear()
            ports = backend.list_ports()
            for item in ports:
                self.port_combo.addItem(item.label, item.device)
            if current:
                self._select_port(current)
            elif self.port_combo.count() > 0:
                self.port_combo.setCurrentIndex(0)
        except Exception as exc:
            self.log(f"Port refresh failed: {exc}")
        finally:
            self.port_combo.blockSignals(False)
        self.save_settings()
        self.log(f"Ports refreshed: {self.port_combo.count()} detected")
        self.schedule_preview_refresh()

    def _sync_sample_rate(self, value: float) -> None:
        for spin in [
            self.sample_rate_spin,
            self.control_page.sample_rate,
            self.measurement_page.sample_rate,
            self.calibration_page.sample_rate,
        ]:
            if abs(spin.value() - value) > 1e-6:
                blocked = spin.blockSignals(True)
                spin.setValue(value)
                spin.blockSignals(blocked)
        self.schedule_preview_refresh()
        self.save_settings()

    def _set_busy(self, busy: bool, label: str = "") -> None:
        self._active_tasks = max(0, self._active_tasks + (1 if busy else -1))
        if busy:
            self.statusBar().showMessage(label)
            self.connection_pill.set_state(f"Busy: {label}", warn=True)
        else:
            if self._active_tasks <= 0:
                self.statusBar().showMessage("Ready")
                self.connection_pill.set_state("Ready", on=self.snapshot is not None, bad=self.snapshot is None)

    def run_task(self, label: str, fn: Callable[[], Any], on_success: Callable[[Any], None] | None = None) -> int:
        task_id = self._task_seq
        self._task_seq += 1
        self._pending[task_id] = (label, on_success)
        self._set_busy(True, label)
        self.log(f"{label} started")

        def worker() -> None:
            try:
                result = fn()
            except Exception:
                self.signals.failure.emit(task_id, label, traceback.format_exc())
            else:
                self.signals.success.emit(task_id, result)

        threading.Thread(target=worker, daemon=True).start()
        return task_id

    def _on_task_success(self, task_id: int, result: object) -> None:
        label, callback = self._pending.pop(task_id, ("Task", None))
        self._set_busy(False, label)
        if isinstance(result, backend.StatusSnapshot):
            self.update_snapshot(result)
            self.log(f"{label}: {result.port} -> CONTROL 0x{result.control:08X}, STATUS 0x{result.status:08X}")
        elif isinstance(result, backend.FileArtifact):
            self.log(f"{label}: {result.path} ({result.row_count} rows)")
            self.measurement_page.set_status(f"{label}: {result.path}")
            try:
                self.measurement_page.load_preview_file(result.path)
            except Exception:
                pass
        elif isinstance(result, backend.ReportArtifact):
            self.log(f"{label}: {result.path} ({result.row_count} rows, {result.filled_count} filled)")
            self.measurement_page.show_markdown(result.markdown, result.path)
        elif isinstance(result, backend.CalibrationArtifact):
            self.log(f"{label}: {result.path} (reference bin {result.reference_bin}, Vpp {result.reference_vpp:.6f})")
            self.calibration_page.load_rows(result.rows)
        elif isinstance(result, Path):
            self.log(f"{label}: {result}")
            self.measurement_page.set_status(f"{label}: {result}")
        else:
            self.log(f"{label} complete")
        if callback is not None:
            try:
                callback(result)
            except Exception:
                self.log(traceback.format_exc().rstrip())

    def _on_task_failure(self, task_id: int, label: str, trace: str) -> None:
        self._pending.pop(task_id, None)
        self._set_busy(False, label)
        self.log(trace.rstrip())
        QMessageBox.critical(self, "AD9144 Upper Host", f"{label} failed.\n\n{trace.splitlines()[-1] if trace else 'Unknown error'}")

    def selected_settings(self) -> ControlSettings:
        return self.control_page.settings()

    def update_snapshot(self, snapshot: backend.StatusSnapshot) -> None:
        self.snapshot = snapshot
        self.dashboard_page.update_snapshot(snapshot)
        self.control_page.load_snapshot(snapshot)
        self.connection_pill.set_state(f"{snapshot.port} connected", on=True)
        self.schedule_preview_refresh()
        self.save_settings()

    def schedule_preview_refresh(self) -> None:
        self._preview_timer.start(100)

    def refresh_preview(self) -> None:
        settings = self.selected_settings()
        try:
            x, y, stats = backend.preview_samples(
                frequency_hz=settings.frequency_hz,
                sample_rate_hz=settings.sample_rate_hz,
                amplitude=settings.amplitude,
                offset=settings.offset,
                phase_deg=settings.phase_deg,
                wave=settings.wave,
                sample_count=1024,
            )
            self.dashboard_page.update_preview(x, y, stats=stats, settings=settings)
        except Exception as exc:
            self.log(f"Preview error: {exc}")

    def read_status(self) -> None:
        port = self.selected_port()
        if not port:
            QMessageBox.warning(self, "AD9144 Upper Host", "No COM port selected.")
            return

        def task() -> backend.StatusSnapshot:
            return backend.read_status_snapshot(
                port,
                baud=self.baud_value(),
                timeout=self.timeout_value(),
                sample_rate_hz=self.sample_rate_value(),
            )

        self.run_task("Read status", task)

    def apply_current_settings(self) -> None:
        port = self.selected_port()
        if not port:
            QMessageBox.warning(self, "AD9144 Upper Host", "No COM port selected.")
            return
        settings = self.control_page.settings()

        def task() -> backend.StatusSnapshot:
            return backend.apply_preset(
                port,
                baud=self.baud_value(),
                timeout=self.timeout_value(),
                frequency_hz=settings.frequency_hz,
                sample_rate_hz=settings.sample_rate_hz,
                amplitude=settings.amplitude,
                offset=settings.offset,
                phase_deg=settings.phase_deg,
                wave=settings.wave,
                range_sel=settings.range_sel,
                output_enable=settings.output_enable,
                use_reg_control=settings.use_reg_control,
                cal_enable=settings.cal_enable,
            )

        self.run_task("Apply preset", task)

    def apply_selected_demo(self) -> None:
        port = self.selected_port()
        if not port:
            QMessageBox.warning(self, "AD9144 Upper Host", "No COM port selected.")
            return
        name = self.control_page.demo_combo.currentText()

        def task() -> backend.StatusSnapshot:
            return backend.apply_demo_preset(
                port,
                name,
                baud=self.baud_value(),
                timeout=self.timeout_value(),
                sample_rate_hz=self.sample_rate_value(),
            )

        self.run_task(f"Apply demo {name}", task)

    def apply_baseline(self) -> None:
        self.control_page.load_demo("baseline_50m")
        self.apply_selected_demo()

    def set_button_control(self) -> None:
        port = self.selected_port()
        if not port:
            QMessageBox.warning(self, "AD9144 Upper Host", "No COM port selected.")
            return

        def task() -> backend.StatusSnapshot:
            return backend.set_button_control(
                port,
                baud=self.baud_value(),
                timeout=self.timeout_value(),
                sample_rate_hz=self.sample_rate_value(),
                output_enable=self.control_page.output_enable.isChecked(),
            )

        self.run_task("Button control", task)

    def set_output_off(self) -> None:
        port = self.selected_port()
        if not port:
            QMessageBox.warning(self, "AD9144 Upper Host", "No COM port selected.")
            return

        def task() -> backend.StatusSnapshot:
            return backend.set_output_enable(
                port,
                False,
                baud=self.baud_value(),
                timeout=self.timeout_value(),
                sample_rate_hz=self.sample_rate_value(),
            )

        self.run_task("Output off", task)

    def set_cal_enable(self, enabled: bool) -> None:
        port = self.selected_port()
        if not port:
            QMessageBox.warning(self, "AD9144 Upper Host", "No COM port selected.")
            return

        def task() -> backend.StatusSnapshot:
            return backend.set_calibration_enable(
                port,
                enabled,
                baud=self.baud_value(),
                timeout=self.timeout_value(),
                sample_rate_hz=self.sample_rate_value(),
            )

        self.run_task("Cal enable" if enabled else "Cal disable", task)

    def set_range_from_page(self) -> None:
        port = self.selected_port()
        if not port:
            QMessageBox.warning(self, "AD9144 Upper Host", "No COM port selected.")
            return
        range_sel = self.control_page.range_sel.currentIndex()

        def task() -> backend.StatusSnapshot:
            return backend.set_range_sel(
                port,
                range_sel,
                baud=self.baud_value(),
                timeout=self.timeout_value(),
                sample_rate_hz=self.sample_rate_value(),
            )

        self.run_task("Set range", task)

    def run_smoke_check(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            tmp = Path(tmpdir)
            preview_x, preview_y, stats = backend.preview_samples(
                frequency_hz=50_000_000.0,
                sample_rate_hz=1_000_000_000.0,
                amplitude=0x6000,
                offset=0,
                phase_deg=0.0,
                wave="sine",
                sample_count=1024,
            )
            self.dashboard_page.update_preview(
                preview_x,
                preview_y,
                stats=stats,
                settings=ControlSettings(
                    frequency_hz=50_000_000.0,
                    sample_rate_hz=1_000_000_000.0,
                    amplitude=0x6000,
                    offset=0,
                    phase_deg=0.0,
                    wave="sine",
                    range_sel=0,
                    output_enable=True,
                    use_reg_control=True,
                    cal_enable=False,
                ),
            )
            template = backend.build_scope_template(profile="freq_response", sample_rate_hz=1_000_000_000.0, out=tmp / "template.csv")
            _, rows = _read_csv_rows(template.path)
            for index, row in enumerate(rows):
                row["measured_frequency_hz"] = row.get("target_frequency_hz", "")
                row["measured_vpp_v"] = f"{1.0 - 0.05 * (index % 4):.3f}"
                row["measured_vrms_v"] = f"{0.35 + 0.01 * (index % 4):.3f}"
                row["trigger_stability"] = "stable"
                row["visible_distortion"] = "mild" if index else "none"
                row["note"] = "smoke"
            filled = tmp / "filled.csv"
            _write_csv_rows(filled, rows, list(rows[0].keys()))
            report = backend.build_scope_report(input_path=filled, out=tmp / "report.md")
            cal = backend.build_calibration_table(input_path=filled, out=tmp / "calibration.csv")
            quality_out = backend.generate_wave_quality(profile="quick", sample_rate_hz=1_000_000_000.0, sample_count=20_000, out=tmp / "quality.csv")
            self.measurement_page.show_markdown(report.markdown, report.path)
            self.calibration_page.load_rows(cal.rows)
            self.measurement_page.set_status(f"Smoke check wrote {template.path.name}, {report.path.name}, {cal.path.name}, {quality_out.name}")
            self.log("Smoke check completed successfully.")
            print("UPPER_HOST_SMOKE_OK")


def main(argv: list[str] | None = None) -> int:
    argv = list(sys.argv[1:] if argv is None else argv)
    smoke = "--smoke" in argv
    if smoke:
        argv = [arg for arg in argv if arg != "--smoke"]
    app = QApplication(argv)
    app.setApplicationName("AD9144 Upper Host")
    app.setOrganizationName("OpenAI")
    apply_theme(app)
    window = UpperHostWindow(smoke=smoke)
    if smoke:
        window.run_smoke_check()
        return 0
    window.show()
    return app.exec()
