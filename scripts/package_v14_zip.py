#!/usr/bin/env python3
"""Package cleaned v10 YOLO export as mealybug v14 zip (no label backups)."""

from __future__ import annotations

import zipfile
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "mealybug.v10-8th-yolo26n.yolo26"
OUT = ROOT / "vast_upload" / "mealybug.v14-cleaned-yolo26n.yolo26.zip"
DATASET_NAME = "mealybug.v14-cleaned-yolo26n.yolo26"

SKIP_DIR_NAMES = {"backup_before_bad_clean", ".git"}
SKIP_SUFFIXES = {".cache", ".bak"}


def should_skip(path: Path) -> bool:
    if any(part in SKIP_DIR_NAMES for part in path.parts):
        return True
    if path.suffix.lower() in SKIP_SUFFIXES:
        return True
    if path.name.endswith(".txt.bak"):
        return True
    return False


DATA_YAML = """# PINYA-PIC v14 — cleaned Roboflow v10 export (polygon + bad-box cleanup)
# Source: mealybug.v10-8th-yolo26n.yolo26 after audit_and_clean + clean_bad_labels (2026-05-24)
train: train/images
val: valid/images
test: test/images
nc: 1
names:
- mealybug
pinya:
  version: v14
  cleaned: true
  boxes_train: 109544
  boxes_valid: 5863
  boxes_test: 2820
  docs: docs/data/LABEL_CLEANUP_V10.md
roboflow:
  workspace: pine3
  project: mealybug-y4fsp
  version: 9
  license: CC BY 4.0
  url: https://universe.roboflow.com/pine3/mealybug-y4fsp/dataset/9
"""


def main() -> None:
    if not SRC.is_dir():
        raise SystemExit(f"Missing cleaned v10 dataset: {SRC}")

    train_n = len(list((SRC / "train" / "images").glob("*.*")))
    if train_n < 10000:
        raise SystemExit(f"Expected ~16175 train images, found {train_n}")

    OUT.parent.mkdir(parents=True, exist_ok=True)
    if OUT.exists():
        OUT.unlink()

    files: list[tuple[Path, str]] = []
    for src in SRC.rglob("*"):
        if not src.is_file() or should_skip(src):
            continue
        rel = src.relative_to(SRC).as_posix()
        if rel.lower() == "data.yaml":
            continue
        files.append((src, f"{DATASET_NAME}/{rel}"))

    print(f"Zipping {len(files) + 1} files -> {OUT}")
    with zipfile.ZipFile(OUT, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=1) as zf:
        zf.writestr(f"{DATASET_NAME}/data.yaml", DATA_YAML)
        for i, (src, arc) in enumerate(files, 1):
            try:
                zf.write(src, arc)
            except OSError as exc:
                raise SystemExit(f"Failed to add {src}: {exc}") from exc
            if i % 2000 == 0:
                print(f"  {i}/{len(files)} ...")

    mb = OUT.stat().st_size / (1024 * 1024)
    print(f"Done: {OUT} ({mb:.1f} MB) @ {datetime.now(timezone.utc).isoformat()}")
    if mb < 500:
        raise SystemExit("Zip too small — packaging may have failed.")


if __name__ == "__main__":
    main()
