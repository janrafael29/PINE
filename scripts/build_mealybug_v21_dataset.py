#!/usr/bin/env python3
"""Build mealybug_v21 from mealybug_v20 images + consensus train labels."""

from __future__ import annotations

import argparse
import shutil
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
V20 = ROOT / "datasets/mealybug_v20"
OUT = ROOT / "datasets/mealybug_v21"


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser()
    p.add_argument("--v20", type=Path, default=V20)
    p.add_argument("--consensus-labels", type=Path, default=ROOT / "runs/consensus/v21_train_labels")
    p.add_argument("--out", type=Path, default=OUT)
    return p.parse_args()


def write_data_yaml(out: Path) -> None:
    yaml = f"""# mealybug_v21 — consensus labels {datetime.now(timezone.utc).isoformat()}
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
    if not args.v20.is_dir():
        raise SystemExit(f"Missing {args.v20}")
    if not args.consensus_labels.is_dir():
        raise SystemExit(f"Missing consensus labels: {args.consensus_labels}")

    if args.out.exists():
        shutil.rmtree(args.out)

    shutil.copytree(args.v20, args.out)
    dst_labels = args.out / "train/labels"
    if dst_labels.exists():
        shutil.rmtree(dst_labels)
    shutil.copytree(args.consensus_labels, dst_labels)
    write_data_yaml(args.out)
    print(f"Built {args.out} — train labels from consensus, val/test unchanged from v20")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
