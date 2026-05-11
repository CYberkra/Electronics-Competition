#!/usr/bin/env python3
"""Launcher for the Qt-based AD9144 upper-computer UI."""

from __future__ import annotations

import sys
from pathlib import Path


if __package__ in (None, ""):
    root = Path(__file__).resolve().parent.parent
    if str(root) not in sys.path:
        sys.path.insert(0, str(root))

from ad9144_bringup_k325t.upper_host.main import main


if __name__ == "__main__":
    raise SystemExit(main())

