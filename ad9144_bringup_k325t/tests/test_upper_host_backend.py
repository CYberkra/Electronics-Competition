from __future__ import annotations

import csv
import contextlib
import io
import tempfile
import unittest
from pathlib import Path

from ad9144_bringup_k325t.tools import awg_uart_control as ctrl
from ad9144_bringup_k325t.upper_host import backend


class UpperHostBackendTest(unittest.TestCase):
    def test_demo_preset_contract_matches_uart_math(self) -> None:
        names = backend.demo_preset_names()

        self.assertEqual(names[0], "baseline_50m")
        self.assertIn("high_300m", names)
        self.assertEqual(len(names), len(set(names)))

        preset = backend.demo_preset_dict("baseline_50m")
        self.assertEqual(preset["wave"], "sine")
        self.assertEqual(int(preset["amplitude"]), 0x6000)
        self.assertEqual(
            ctrl.phase_inc_from_frequency(float(preset["frequency"]), backend.DEFAULT_SAMPLE_RATE),
            0x0CCCCCCCCCCD,
        )

        with self.assertRaises(KeyError):
            backend.demo_preset_dict("not_a_preset")

    def test_preview_samples_are_bounded_and_report_stats(self) -> None:
        x, y, stats = backend.preview_samples(
            frequency_hz=50_000_000.0,
            sample_rate_hz=1_000_000_000.0,
            amplitude=0x6000,
            offset=0,
            phase_deg=0.0,
            wave="sine",
            sample_count=256,
        )

        self.assertEqual(len(x), 256)
        self.assertEqual(len(y), 256)
        self.assertLessEqual(int(y.max()), 32767)
        self.assertGreaterEqual(int(y.min()), -32768)
        self.assertGreater(stats["vpp"], 10_000.0)
        self.assertGreater(stats["rms"], 1_000.0)

    def test_measurement_report_and_calibration_round_trip(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            tmp = Path(tmpdir)
            template = backend.build_scope_template(
                profile="freq_response",
                sample_rate_hz=backend.DEFAULT_SAMPLE_RATE,
                out=tmp / "freq_response.csv",
            )
            rows = _read_rows(template.path)
            self.assertEqual(template.row_count, 9)

            for index, row in enumerate(rows):
                row["measured_frequency_hz"] = row["target_frequency_hz"]
                row["measured_vpp_v"] = f"{1.000 - 0.020 * (index % 3):.3f}"
                row["measured_vrms_v"] = "0.353"
                row["trigger_stability"] = "stable"
                row["visible_distortion"] = "none"
                row["note"] = "unit-test"

            filled = tmp / "filled_scope.csv"
            _write_rows(filled, rows)

            report = backend.build_scope_report(input_path=filled, out=tmp / "report.md")
            self.assertEqual(report.row_count, len(rows))
            self.assertEqual(report.filled_count, len(rows))
            self.assertIn("AWG Scope Measurement Report", report.markdown)

            calibration = backend.build_calibration_table(input_path=filled, out=tmp / "calibration.csv")
            self.assertEqual(len(calibration.rows), ctrl.CAL_TABLE_ENTRIES)
            self.assertGreater(calibration.reference_vpp, 0.0)

            entries = backend.load_calibration_rows(calibration.path)
            self.assertEqual(len(entries), ctrl.CAL_TABLE_ENTRIES)
            for expected_index, (index, offset, gain, _row) in enumerate(entries):
                self.assertEqual(index, expected_index)
                self.assertEqual(offset, 0)
                self.assertGreater(gain, 0)

    def test_wave_quality_generation_writes_expected_columns(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            out = Path(tmpdir) / "quality.csv"
            with contextlib.redirect_stdout(io.StringIO()):
                result = backend.generate_wave_quality(
                    profile="quick",
                    sample_rate_hz=backend.DEFAULT_SAMPLE_RATE,
                    sample_count=4096,
                    out=out,
                )

            rows = _read_rows(result)
            self.assertEqual(len(rows), 3)
            self.assertIn("thd_2_to_5_dbc", rows[0])
            self.assertIn("max_nonharmonic_spur_dbc", rows[0])
            self.assertEqual(rows[0]["wave"], "sine")


def _read_rows(path: Path) -> list[dict[str, str]]:
    with path.open("r", newline="", encoding="utf-8-sig") as handle:
        return list(csv.DictReader(handle))


def _write_rows(path: Path, rows: list[dict[str, str]]) -> None:
    if not rows:
        raise ValueError("rows must not be empty")
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=list(rows[0].keys()))
        writer.writeheader()
        writer.writerows(rows)


if __name__ == "__main__":
    unittest.main()
