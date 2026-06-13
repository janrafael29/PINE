#!/usr/bin/env python3
"""Wave 1 — copy labels, run conservative auto-fix into mealybug_v20_audit."""

from __future__ import annotations

import argparse
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_MODEL = ROOT / "runs/retrain/mealybug_v16_selffix/weights/best.pt"
SRC = ROOT / "datasets/mealybug_v13afix"
OUT = ROOT / "datasets/mealybug_v20_audit"


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(description="Prepare mealybug_v20_audit via auto-fix")
    p.add_argument("--model", type=Path, default=DEFAULT_MODEL)
    p.add_argument("--src", type=Path, default=SRC)
    p.add_argument("--out", type=Path, default=OUT)
    p.add_argument("--apply", action="store_true", help="Run auto_fix --apply (default dry-run only)")
    p.add_argument("--add-conf", type=float, default=0.50)
    p.add_argument("--limit", type=int, default=0)
    return p.parse_args()


def copy_split(src: Path, out: Path, split: str) -> None:
    for sub in ("images", "labels"):
        s, d = src / split / sub, out / split / sub
        if not s.is_dir():
            return
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
    ]
    if limit > 0:
        cmd.extend(["--limit", str(limit)])
    if apply:
        cmd.append("--apply")
    else:
        cmd.append("--dry-run")
    print(">", " ".join(cmd))
    subprocess.run(cmd, check=True)


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

    # Prefer corrected test labels when present
    corrected = args.src / "test" / "labels_v16_corrected"
    if corrected.is_dir():
        test_lbl = args.out / "test" / "labels"
        test_lbl.mkdir(parents=True, exist_ok=True)
        for f in corrected.glob("*.txt"):
            shutil.copy2(f, test_lbl / f.name)

    for split in ("train", "valid"):
        run_auto_fix(
            args.model,
            args.out / split / "images",
            args.out / split / "labels",
            args.apply,
            args.add_conf,
            args.limit,
        )

    if args.apply:
        run_auto_fix(
            args.model,
            args.out / "test" / "images",
            args.out / "test" / "labels",
            True,
            max(args.add_conf, 0.45),
            args.limit,
        )

    print(f"Audit dataset ready: {args.out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
