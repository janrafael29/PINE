#!/usr/bin/env python3
"""Moved to labeling_system/tools/tighten_batch.py — this wrapper keeps old commands working."""
from __future__ import annotations

import runpy
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "labeling_system" / "tools"))
runpy.run_path(
    str(ROOT / "labeling_system" / "tools" / "tighten_batch.py"),
    run_name="__main__",
)
