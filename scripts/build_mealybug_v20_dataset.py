#!/usr/bin/env python3
"""Wave 2 — publish mealybug_v20 from v20_audit (+ optional field batch merge)."""

from __future__ import annotations

import argparse
import json
import shutil
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
AUDIT = ROOT / "datasets/mealybug_v20_audit"
OUT = ROOT / "datasets/mealybug_v20"


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser()
    p.add_argument("--audit", type=Path, default=AUDIT)
    p.add_argument("--out", type=Path, default=OUT)
    p.add_argument("--field-batch", type=Path, default=None, help="field_batches/... with images/ labels/")
    p.add_argument("--dry-run", action="store_true")
    return p.parse_args()


def count_boxes(labels_dir: Path) -> int:
    n = 0
    if not labels_dir.is_dir():
        return 0
    for f in labels_dir.glob("*.txt"):
        n += sum(1 for line in f.read_text(encoding="utf-8").splitlines() if line.strip())
    return n


def write_data_yaml(out: Path) -> None:
    yaml = f"""# mealybug_v20 — auto-built {datetime.now(timezone.utc).isoformat()}
path: {out.as_posix()}
train: train/images
val: valid/images
test: test/images

nc: 1
names:
  0: mealybug
"""
    (out / "data.yaml").write_text(yaml, encoding="utf-8")


def main() -> int:
    args = parse_args()
    if not args.audit.is_dir():
        raise SystemExit(f"Run prepare_mealybug_v20_audit.py first: {args.audit}")

    if args.out.exists() and not args.dry_run:
        shutil.rmtree(args.out)

    if not args.dry_run:
        shutil.copytree(args.audit, args.out)
        write_data_yaml(args.out)

    if args.field_batch and args.field_batch.is_dir():
        img_s = args.field_batch / "images"
        lbl_s = args.field_batch / "labels"
        train_img = args.out / "train" / "images"
        train_lbl = args.out / "train" / "labels"
        if img_s.is_dir() and not args.dry_run:
            train_img.mkdir(parents=True, exist_ok=True)
            train_lbl.mkdir(parents=True, exist_ok=True)
            for img in img_s.iterdir():
                if img.is_file():
                    shutil.copy2(img, train_img / img.name)
                    lbl = lbl_s / f"{img.stem}.txt"
                    if lbl.is_file():
                        shutil.copy2(lbl, train_lbl / lbl.name)
                    else:
                        (train_lbl / f"{img.stem}.txt").write_text("", encoding="utf-8")

    report = {
        "built_at": datetime.now(timezone.utc).isoformat(),
        "source_audit": str(args.audit),
        "field_batch": str(args.field_batch) if args.field_batch else None,
        "splits": {},
    }
    for split in ("train", "valid", "test"):
        img_d = args.out / split / "images"
        lbl_d = args.out / split / "labels"
        report["splits"][split] = {
            "images": len(list(img_d.glob("*"))) if img_d.is_dir() else 0,
            "boxes": count_boxes(lbl_d),
        }

    report_path = args.out / "build_report.json"
    if not args.dry_run:
        report_path.write_text(json.dumps(report, indent=2), encoding="utf-8")
    print(json.dumps(report, indent=2))
    print(f"mealybug_v20 -> {args.out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
