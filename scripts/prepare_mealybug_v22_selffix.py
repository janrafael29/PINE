#!/usr/bin/env python3
"""v16 selffix round 2 — add high-conf v16 boxes to v13afix train labels → mealybug_v22."""

from __future__ import annotations

import argparse
import json
import shutil
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_MODEL = ROOT / "runs/retrain/mealybug_v16_selffix/weights/best.pt"
SRC = ROOT / "datasets/mealybug_v13afix"
OUT = ROOT / "datasets/mealybug_v22"


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(description="Build mealybug_v22 via v16 selffix (train add-only)")
    p.add_argument("--model", type=Path, default=DEFAULT_MODEL)
    p.add_argument("--src", type=Path, default=SRC)
    p.add_argument("--out", type=Path, default=OUT)
    p.add_argument("--apply", action="store_true")
    p.add_argument("--add-conf", type=float, default=0.45)
    p.add_argument("--limit", type=int, default=0)
    return p.parse_args()


def copy_split(src: Path, out: Path, split: str) -> None:
    for sub in ("images", "labels"):
        s, d = src / split / sub, out / split / sub
        if not s.is_dir():
            continue
        d.mkdir(parents=True, exist_ok=True)
        for f in s.iterdir():
            if f.is_file():
                shutil.copy2(f, d / f.name)


def run_auto_fix(
    model: Path,
    images: Path,
    labels: Path,
    apply: bool,
    add_conf: float,
    limit: int,
) -> None:
    cmd = [
        sys.executable,
        str(ROOT / "scripts/auto_fix_annotations.py"),
        "--model",
        str(model),
        "--images",
        str(images),
        "--labels",
        str(labels),
        "--add-conf",
        str(add_conf),
        "--no-remove",
        "--no-tighten",
    ]
    if limit > 0:
        cmd.extend(["--limit", str(limit)])
    cmd.append("--apply" if apply else "--dry-run")
    print(">", " ".join(cmd))
    subprocess.run(cmd, check=True)


def write_data_yaml(out: Path) -> None:
    yaml = f"""# mealybug_v22 — v16 selffix round 2 on v13afix train labels
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
    if not args.src.is_dir():
        raise SystemExit(f"Missing source dataset: {args.src}")
    if not args.model.is_file():
        raise SystemExit(f"Missing model: {args.model}")

    if args.out.exists():
        shutil.rmtree(args.out)
    args.out.mkdir(parents=True)

    for split in ("train", "valid", "test"):
        copy_split(args.src, args.out, split)

    # Train only — do not relabel test (corrected test eval uses separate staging).
    run_auto_fix(
        args.model,
        args.out / "train" / "images",
        args.out / "train" / "labels",
        args.apply,
        args.add_conf,
        args.limit,
    )

    write_data_yaml(args.out)

    report = ROOT / "runs/v22_pipeline/build_report.json"
    report.parent.mkdir(parents=True, exist_ok=True)
    fix_report = ROOT / "runs/audit/auto_fix_report.json"
    stats = {}
    if fix_report.is_file():
        stats = json.loads(fix_report.read_text(encoding="utf-8"))
    report.write_text(
        json.dumps(
            {
                "built_at": datetime.now(timezone.utc).isoformat(),
                "source": str(args.src),
                "model": str(args.model),
                "add_conf": args.add_conf,
                "train_only": True,
                "auto_fix_stats": stats,
            },
            indent=2,
        ),
        encoding="utf-8",
    )
    print(f"Dataset ready: {args.out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
