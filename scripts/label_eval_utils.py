"""Helpers for v16 corrected-test evaluation without mutating label junctions."""

from __future__ import annotations

import os
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DATASET = ROOT / "datasets/mealybug_v13afix"
STAGING = ROOT / "runs/calibration/mealybug_v16_corrected_eval"
STAGING_YAML = ROOT / "runs/calibration/data_v16_corrected_test.yaml"


def _is_reparse_point(path: Path) -> bool:
    if path.is_symlink():
        return True
    if not path.exists():
        return False
    if os.name != "nt":
        return path.is_symlink()
    try:
        import stat

        return bool(stat.S_ISLNK(path.lstat().st_mode) or (path.lstat().st_file_attributes or 0) & 0x400)
    except OSError:
        return False


def _remove_path(path: Path) -> None:
    if not path.exists() and not path.is_symlink():
        return
    if _is_reparse_point(path) or path.is_symlink():
        path.unlink()
    elif path.is_dir():
        shutil.rmtree(path)
    else:
        path.unlink()


def _junction(link: Path, target: Path) -> None:
    """Create directory junction (Windows) or symlink (Unix)."""
    target = target.resolve()
    link.parent.mkdir(parents=True, exist_ok=True)
    if link.exists() or link.is_symlink():
        _remove_path(link)
    if os.name == "nt":
        subprocess.run(
            ["cmd", "/c", "mklink", "/J", str(link), str(target)],
            check=True,
            capture_output=True,
        )
    else:
        link.symlink_to(target, target_is_directory=True)


def ensure_corrected_eval_staging(
    *,
    images: Path | None = None,
    labels_corrected: Path | None = None,
) -> Path:
    """Staging tree: test/images + test/labels -> corrected GT."""
    images = images or (DATASET / "test/images")
    labels_corrected = labels_corrected or (DATASET / "test/labels_v16_corrected")
    if not images.is_dir():
        raise FileNotFoundError(f"Missing images: {images}")
    if not labels_corrected.is_dir():
        raise FileNotFoundError(
            f"Missing corrected labels: {labels_corrected}\n"
            "Run: python scripts/fix_test_labels.py --apply"
        )

    test_dir = STAGING / "test"
    test_dir.mkdir(parents=True, exist_ok=True)
    _junction(test_dir / "images", images)
    _junction(test_dir / "labels", labels_corrected)

    STAGING_YAML.parent.mkdir(parents=True, exist_ok=True)
    STAGING_YAML.write_text(
        f"path: {STAGING.as_posix()}\n"
        "train: test/images\n"
        "val: test/images\n"
        "test: test/images\n\n"
        "nc: 1\n"
        "names:\n"
        "  0: mealybug\n",
        encoding="utf-8",
    )
    return STAGING_YAML


def run_fix_test_labels_if_missing() -> bool:
    corrected = DATASET / "test/labels_v16_corrected"
    if corrected.is_dir() and any(corrected.glob("*.txt")):
        return True
    print("Running fix_test_labels.py --apply ...")
    subprocess.run(
        [sys.executable, str(ROOT / "scripts/fix_test_labels.py"), "--apply"],
        check=True,
        cwd=ROOT,
    )
    return corrected.is_dir()
