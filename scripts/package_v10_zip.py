#!/usr/bin/env python3
"""Build pine_v10_train_bundle.zip for Vast (avoids empty Compress-Archive failures)."""

from __future__ import annotations

import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "vast_upload" / "pine_v10_train_bundle.zip"
V10 = ROOT / "mealybug.v10-8th-yolo26n.yolo26"

EXTRA = [
    ROOT / "scripts" / "retrain_yolo.py",
    ROOT / "scripts" / "vast_train_v10.sh",
    ROOT / "scripts" / "requirements-train.txt",
    ROOT / "runs" / "retrain" / "mealybug_v2" / "weights" / "best.pt",
]


def main() -> None:
    if not V10.is_dir():
        raise SystemExit(f"Missing dataset: {V10}")

    train_n = len(list((V10 / "train" / "images").glob("*.*")))
    if train_n < 10000:
        raise SystemExit(f"Expected ~16175 train images, found {train_n}")

    OUT.parent.mkdir(parents=True, exist_ok=True)
    if OUT.exists():
        OUT.unlink()

    files: list[tuple[Path, str]] = []
    for p in V10.rglob("*"):
        if p.is_file() and not p.name.endswith(".cache"):
            arc = str(p.relative_to(ROOT)).replace("\\", "/")
            files.append((p, arc))
    for p in EXTRA:
        if not p.is_file():
            raise SystemExit(f"Missing: {p}")
        files.append((p, str(p.relative_to(ROOT)).replace("\\", "/")))

    print(f"Zipping {len(files)} files -> {OUT}")
    with zipfile.ZipFile(OUT, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=1) as zf:
        for i, (src, arc) in enumerate(files, 1):
            zf.write(src, arc)
            if i % 2000 == 0:
                print(f"  {i}/{len(files)} ...")

    mb = OUT.stat().st_size / (1024 * 1024)
    print(f"Done: {OUT} ({mb:.1f} MB)")
    if mb < 500:
        raise SystemExit("Zip too small — packaging failed.")


if __name__ == "__main__":
    main()
