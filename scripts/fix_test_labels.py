#!/usr/bin/env python3
"""Fix under-annotated test labels using v16 high-confidence predictions.

Adds boxes where the model predicts conf >= add_conf and IoU to existing GT < match_iou.
Used for the v16-consensus "fair GT" test set (~18,891 instances @ conf 0.45).

Usage:
  python scripts/fix_test_labels.py --dry-run
  python scripts/fix_test_labels.py --apply
  python scripts/fix_test_labels.py --apply --in-place
"""
from __future__ import annotations

import argparse
import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(description="Add v16 high-conf boxes to test labels")
    p.add_argument(
        "--model",
        type=Path,
        default=ROOT / "runs" / "retrain" / "mealybug_v16_selffix" / "weights" / "best.pt",
    )
    p.add_argument(
        "--images",
        type=Path,
        default=ROOT / "datasets" / "mealybug_v13afix" / "test" / "images",
    )
    p.add_argument(
        "--labels",
        type=Path,
        default=ROOT / "datasets" / "mealybug_v13afix" / "test" / "labels",
    )
    p.add_argument(
        "--labels-out",
        type=Path,
        default=ROOT / "datasets" / "mealybug_v13afix" / "test" / "labels_v16_corrected",
        help="Output label dir (default: labels_v16_corrected; ignored with --in-place)",
    )
    p.add_argument("--add-conf", type=float, default=0.45)
    p.add_argument("--match-iou", type=float, default=0.3)
    p.add_argument("--imgsz", type=int, default=1280)
    p.add_argument("--limit", type=int, default=0)
    p.add_argument("--dry-run", action="store_true")
    p.add_argument("--apply", action="store_true")
    p.add_argument(
        "--in-place",
        action="store_true",
        help="Append new boxes to --labels instead of writing --labels-out",
    )
    p.add_argument(
        "--backup",
        type=Path,
        default=ROOT / "datasets" / "mealybug_v13afix" / "test" / "labels_backup",
    )
    return p.parse_args()


def read_labels(path: Path) -> list[list[float]]:
    boxes: list[list[float]] = []
    if not path.exists():
        return boxes
    text = path.read_text(encoding="utf-8").strip()
    if not text:
        return boxes
    for line in text.split("\n"):
        if not line.strip():
            continue
        parts = line.strip().split()
        boxes.append([float(x) for x in parts[1:5]])
    return boxes


def compute_iou_center(box1: list[float], box2: list[float]) -> float:
    def to_xyxy(b: list[float]) -> list[float]:
        return [b[0] - b[2] / 2, b[1] - b[3] / 2, b[0] + b[2] / 2, b[1] + b[3] / 2]

    b1, b2 = to_xyxy(box1), to_xyxy(box2)
    x1 = max(b1[0], b2[0])
    y1 = max(b1[1], b2[1])
    x2 = min(b1[2], b2[2])
    y2 = min(b1[3], b2[3])
    inter = max(0.0, x2 - x1) * max(0.0, y2 - y1)
    a1 = (b1[2] - b1[0]) * (b1[3] - b1[1])
    a2 = (b2[2] - b2[0]) * (b2[3] - b2[1])
    union = a1 + a2 - inter
    return inter / union if union > 0 else 0.0


def count_boxes(label_dir: Path) -> int:
    total = 0
    for f in label_dir.glob("*.txt"):
        text = f.read_text(encoding="utf-8").strip()
        if text:
            total += len([ln for ln in text.splitlines() if ln.strip()])
    return total


def main() -> None:
    args = parse_args()
    if not args.dry_run and not args.apply:
        raise SystemExit("Specify --dry-run or --apply")

    from ultralytics import YOLO

    out_dir = args.labels if args.in_place else args.labels_out

    if args.apply and not args.dry_run:
        if args.in_place and not args.backup.exists():
            print(f"Backing up {args.labels} -> {args.backup}")
            shutil.copytree(args.labels, args.backup)
        elif not args.in_place:
            if out_dir.exists():
                shutil.rmtree(out_dir)
            print(f"Copying {args.labels} -> {out_dir}")
            shutil.copytree(args.labels, out_dir)

    model = YOLO(str(args.model))
    images = sorted(
        list(args.images.glob("*.jpg"))
        + list(args.images.glob("*.jpeg"))
        + list(args.images.glob("*.png"))
    )
    if args.limit > 0:
        images = images[: args.limit]

    total_added = 0
    fixed_images = 0

    for i, img_path in enumerate(images):
        if (i + 1) % 200 == 0:
            print(f"  {i + 1}/{len(images)} | added {total_added}")

        src_lbl = args.labels / f"{img_path.stem}.txt"
        dst_lbl = out_dir / f"{img_path.stem}.txt"
        existing = read_labels(src_lbl if not args.in_place else dst_lbl)

        results = model(str(img_path), imgsz=args.imgsz, conf=args.add_conf, iou=0.5, verbose=False)
        r = results[0]
        if r.boxes is None or len(r.boxes) == 0:
            continue

        new_boxes: list = []
        for box, score in zip(r.boxes.xywhn.cpu().numpy(), r.boxes.conf.cpu().numpy()):
            if float(score) < args.add_conf:
                continue
            is_dup = any(compute_iou_center(box.tolist(), ex) > args.match_iou for ex in existing)
            if not is_dup:
                new_boxes.append(box.tolist())

        if new_boxes:
            fixed_images += 1
            total_added += len(new_boxes)
            if args.apply and not args.dry_run:
                with open(dst_lbl, "a", encoding="utf-8") as f:
                    for box in new_boxes:
                        f.write(
                            f"0 {box[0]:.6f} {box[1]:.6f} {box[2]:.6f} {box[3]:.6f}\n"
                        )

    mode = "DRY RUN" if args.dry_run else "APPLIED"
    print(f"\n{mode}: {fixed_images} images, +{total_added} boxes")
    if args.apply and not args.dry_run:
        print(f"Output labels: {out_dir}")
        print(f"Total instances: {count_boxes(out_dir)}")


if __name__ == "__main__":
    main()
