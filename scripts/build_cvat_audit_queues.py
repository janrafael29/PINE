#!/usr/bin/env python3
"""Rank test images for CVAT audit queues (Q1 FN, Q2 poor IoU, Q3 FP).

Usage:
  python scripts/build_cvat_audit_queues.py
  python scripts/build_cvat_audit_queues.py --limit 300 --package 50
"""

from __future__ import annotations

import argparse
import csv
import json
import shutil
import sys
from dataclasses import dataclass, field
from datetime import datetime, timezone
from pathlib import Path

import cv2

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts"))
from label_eval_utils import ensure_corrected_eval_staging, run_fix_test_labels_if_missing

DEFAULT_MODEL = ROOT / "runs/retrain/mealybug_v16_selffix/weights/best.pt"
IMAGES = ROOT / "datasets/mealybug_v13afix/test/images"
LABELS_CORRECTED = ROOT / "datasets/mealybug_v13afix/test/labels_v16_corrected"
OUT_DIR = ROOT / "runs/audit/cvat_queues"
IMPORT_ROOT = ROOT / "datasets/cvat_import"


@dataclass
class ImageScore:
    name: str
    path: Path
    fn: int = 0
    fp: int = 0
    poor_iou: int = 0
    tp: int = 0
    gt_count: int = 0
    pred_count: int = 0
    notes: list[str] = field(default_factory=list)

    @property
    def fn_score(self) -> int:
        return self.fn * 100 + self.gt_count

    @property
    def poor_score(self) -> int:
        return self.poor_iou * 50 + self.fn

    @property
    def fp_score(self) -> int:
        return self.fp * 100 + self.pred_count


@dataclass(frozen=True)
class Box:
    x1: float
    y1: float
    x2: float
    y2: float
    conf: float = 1.0


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(description="Build CVAT audit queues from v16 vs corrected GT")
    p.add_argument("--model", type=Path, default=DEFAULT_MODEL)
    p.add_argument("--images", type=Path, default=IMAGES)
    p.add_argument("--labels", type=Path, default=LABELS_CORRECTED)
    p.add_argument("--conf", type=float, default=0.25)
    p.add_argument("--iou-match", type=float, default=0.50)
    p.add_argument("--iou-poor-max", type=float, default=0.75)
    p.add_argument("--imgsz", type=int, default=1280)
    p.add_argument("--batch", type=int, default=4, help="Inference batch size (lower if OOM)")
    p.add_argument("--chunk", type=int, default=64, help="Images per predict() call")
    p.add_argument("--limit", type=int, default=0, help="Max images to scan (0=all)")
    p.add_argument("--package", type=int, default=50, help="Copy top-N per queue for CVAT import (0=skip)")
    p.add_argument(
        "--package-only",
        action="store_true",
        help="Package from existing queue CSVs under --out (skip inference)",
    )
    p.add_argument("--out", type=Path, default=OUT_DIR)
    return p.parse_args()


def load_gt(label_path: Path, w: int, h: int) -> list[Box]:
    if not label_path.is_file():
        return []
    out: list[Box] = []
    for line in label_path.read_text(encoding="utf-8").splitlines():
        parts = line.strip().split()
        if len(parts) < 5:
            continue
        xc, yc, bw, bh = (float(parts[i]) for i in range(1, 5))
        x1 = (xc - bw / 2) * w
        y1 = (yc - bh / 2) * h
        x2 = (xc + bw / 2) * w
        y2 = (yc + bh / 2) * h
        out.append(Box(x1, y1, x2, y2))
    return out


def iou(a: Box, b: Box) -> float:
    ix1, iy1 = max(a.x1, b.x1), max(a.y1, b.y1)
    ix2, iy2 = min(a.x2, b.x2), min(a.y2, b.y2)
    iw, ih = max(0.0, ix2 - ix1), max(0.0, iy2 - iy1)
    inter = iw * ih
    if inter <= 0:
        return 0.0
    aa = max(0.0, a.x2 - a.x1) * max(0.0, a.y2 - a.y1)
    ab = max(0.0, b.x2 - b.x1) * max(0.0, b.y2 - b.y1)
    union = aa + ab - inter
    return inter / union if union > 0 else 0.0


def score_image(
    img_path: Path,
    label_path: Path,
    preds: list[Box],
    iou_match: float,
    iou_poor_max: float,
) -> ImageScore:
    img = cv2.imread(str(img_path))
    if img is None:
        return ImageScore(name=img_path.name, path=img_path)
    h, w = img.shape[:2]
    gts = load_gt(label_path, w, h)
    row = ImageScore(name=img_path.name, path=img_path, gt_count=len(gts), pred_count=len(preds))

    used_p: set[int] = set()
    used_g: set[int] = set()
    pairs: list[tuple[int, int, float]] = []
    for pi, p in enumerate(preds):
        for gi, g in enumerate(gts):
            pairs.append((pi, gi, iou(p, g)))
    pairs.sort(key=lambda x: x[2], reverse=True)

    for pi, gi, score in pairs:
        if score < iou_match:
            break
        if pi in used_p or gi in used_g:
            continue
        used_p.add(pi)
        used_g.add(gi)
        row.tp += 1
        if score < iou_poor_max:
            row.poor_iou += 1

    row.fn = len(gts) - len(used_g)
    row.fp = len(preds) - len(used_p)

    for pi, pred in enumerate(preds):
        if pi in used_p:
            continue
        best = max((iou(pred, g) for g in gts), default=0.0)
        if iou_match <= best < iou_poor_max:
            row.poor_iou += 1

    return row


def write_csv(path: Path, rows: list[ImageScore], sort_key: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    key_fn = {
        "fn": lambda r: r.fn_score,
        "poor": lambda r: r.poor_score,
        "fp": lambda r: r.fp_score,
    }[sort_key]
    rows_sorted = sorted(rows, key=key_fn, reverse=True)
    with path.open("w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(
            f,
            fieldnames=[
                "image",
                "path",
                "fn",
                "fp",
                "poor_iou",
                "tp",
                "gt_count",
                "pred_count",
            ],
        )
        w.writeheader()
        for r in rows_sorted:
            if sort_key == "fn" and r.fn == 0:
                continue
            if sort_key == "fp" and r.fp == 0:
                continue
            if sort_key == "poor" and r.poor_iou == 0:
                continue
            w.writerow(
                {
                    "image": r.name,
                    "path": str(r.path),
                    "fn": r.fn,
                    "fp": r.fp,
                    "poor_iou": r.poor_iou,
                    "tp": r.tp,
                    "gt_count": r.gt_count,
                    "pred_count": r.pred_count,
                }
            )


def package_queue(
    rows: list[ImageScore],
    labels_dir: Path,
    queue_name: str,
    n: int,
    sort_key: str,
) -> Path:
    key_fn = {
        "fn": lambda r: r.fn_score,
        "poor": lambda r: r.poor_score,
        "fp": lambda r: r.fp_score,
    }[sort_key]
    picked = sorted(
        [r for r in rows if (r.fn if sort_key == "fn" else r.fp if sort_key == "fp" else r.poor_iou) > 0],
        key=key_fn,
        reverse=True,
    )[:n]

    dest = IMPORT_ROOT / queue_name
    img_out = dest / "images"
    lbl_out = dest / "labels"
    if dest.exists():
        shutil.rmtree(dest)
    img_out.mkdir(parents=True)
    lbl_out.mkdir(parents=True)

    for r in picked:
        shutil.copy2(r.path, img_out / r.name)
        lbl = labels_dir / f"{r.path.stem}.txt"
        if lbl.is_file():
            shutil.copy2(lbl, lbl_out / lbl.name)
        else:
            (lbl_out / f"{r.path.stem}.txt").write_text("", encoding="utf-8")

    manifest = dest / "manifest.json"
    manifest.write_text(
        json.dumps(
            {
                "queue": queue_name,
                "count": len(picked),
                "images": [r.name for r in picked],
            },
            indent=2,
        ),
        encoding="utf-8",
    )
    return dest


def load_scores_from_csvs(out_dir: Path, images_dir: Path) -> list[ImageScore]:
    """Rebuild [ImageScore] from Q1/Q2/Q3 CSV exports (for --package-only)."""
    by_name: dict[str, ImageScore] = {}
    for csv_name in (
        "Q1_false_negatives.csv",
        "Q2_poor_localization.csv",
        "Q3_false_positives.csv",
    ):
        csv_path = out_dir / csv_name
        if not csv_path.is_file():
            continue
        with csv_path.open(newline="", encoding="utf-8") as f:
            for row in csv.DictReader(f):
                name = row["image"]
                path = Path(row["path"])
                if not path.is_file():
                    path = images_dir / name
                by_name[name] = ImageScore(
                    name=name,
                    path=path,
                    fn=int(row["fn"]),
                    fp=int(row["fp"]),
                    poor_iou=int(row["poor_iou"]),
                    tp=int(row["tp"]),
                    gt_count=int(row["gt_count"]),
                    pred_count=int(row["pred_count"]),
                )
    return list(by_name.values())


def main() -> int:
    args = parse_args()
    labels_dir = args.labels if args.labels.is_dir() else LABELS_CORRECTED

    if args.package_only:
        if args.package <= 0:
            raise SystemExit("--package-only requires --package N > 0")
        scores = load_scores_from_csvs(args.out, args.images)
        if not scores:
            raise SystemExit(f"No queue CSVs found under {args.out}")
        n = args.package
        for queue_name, sort_key in (
            (f"Q1_false_negatives_top{n}", "fn"),
            (f"Q2_poor_localization_top{n}", "poor"),
            (f"Q3_false_positives_top{n}", "fp"),
        ):
            pkg = package_queue(scores, labels_dir, queue_name, n, sort_key)
            print(f"CVAT import package: {pkg}")
        return 0

    if not args.model.is_file():
        raise SystemExit(f"Missing model: {args.model}")
    if not run_fix_test_labels_if_missing() and not args.labels.is_dir():
        raise SystemExit("Run: python scripts/fix_test_labels.py --apply")

    ensure_corrected_eval_staging()

    image_paths = sorted(
        p
        for p in args.images.iterdir()
        if p.suffix.lower() in {".jpg", ".jpeg", ".png", ".webp"}
    )
    if args.limit > 0:
        image_paths = image_paths[: args.limit]

    from ultralytics import YOLO

    model = YOLO(str(args.model))
    print(
        f"Predicting {len(image_paths)} images @ conf={args.conf} "
        f"imgsz={args.imgsz} batch={args.batch} chunk={args.chunk} ..."
    )

    scores: list[ImageScore] = []
    chunk_size = max(1, args.chunk)
    for start in range(0, len(image_paths), chunk_size):
        chunk = image_paths[start : start + chunk_size]
        pred_results = model.predict(
            source=[str(p) for p in chunk],
            conf=args.conf,
            iou=0.45,
            imgsz=args.imgsz,
            batch=args.batch,
            verbose=False,
            stream=True,
        )
        for idx, result in enumerate(pred_results):
            # result.path can be a synthetic "imageN.jpg" when source is a list;
            # results preserve source order, so map back to the real path.
            img_path = Path(result.path)
            if not img_path.is_file() and idx < len(chunk):
                img_path = chunk[idx]
            preds: list[Box] = []
            if result.boxes is not None:
                for row in result.boxes.xyxy.cpu().numpy():
                    x1, y1, x2, y2 = (float(v) for v in row[:4])
                    conf = float(row[4]) if len(row) > 4 else 1.0
                    preds.append(Box(x1, y1, x2, y2, conf))
            label_path = labels_dir / f"{img_path.stem}.txt"
            scores.append(
                score_image(img_path, label_path, preds, args.iou_match, args.iou_poor_max)
            )
        print(f"  scored {min(start + chunk_size, len(image_paths))}/{len(image_paths)}")

    args.out.mkdir(parents=True, exist_ok=True)
    write_csv(args.out / "Q1_false_negatives.csv", scores, "fn")
    write_csv(args.out / "Q2_poor_localization.csv", scores, "poor")
    write_csv(args.out / "Q3_false_positives.csv", scores, "fp")

    summary = {
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "model": str(args.model.relative_to(ROOT)),
        "images_scanned": len(scores),
        "conf": args.conf,
        "totals": {
            "images_with_fn": sum(1 for s in scores if s.fn > 0),
            "images_with_fp": sum(1 for s in scores if s.fp > 0),
            "images_with_poor_iou": sum(1 for s in scores if s.poor_iou > 0),
            "total_fn_boxes": sum(s.fn for s in scores),
            "total_fp_boxes": sum(s.fp for s in scores),
        },
    }
    (args.out / "summary.json").write_text(json.dumps(summary, indent=2), encoding="utf-8")
    print(json.dumps(summary, indent=2))

    if args.package > 0:
        n = args.package
        for queue_name, sort_key in (
            (f"Q1_false_negatives_top{n}", "fn"),
            (f"Q2_poor_localization_top{n}", "poor"),
            (f"Q3_false_positives_top{n}", "fp"),
        ):
            pkg = package_queue(scores, labels_dir, queue_name, n, sort_key)
            print(f"CVAT import package: {pkg}")

    print(f"Wrote queues under {args.out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
