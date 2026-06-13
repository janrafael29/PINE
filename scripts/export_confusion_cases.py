#!/usr/bin/env python3
"""Export TP / FP / FN / poor-localization examples for thesis Ch. IV.

Runs mealybug_v16 on the held-out test split, matches predictions to ground
truth, and saves annotated crops for panel guidance #7.

Usage:
  python scripts/export_confusion_cases.py
  python scripts/export_confusion_cases.py --max-images 400 --samples-per-class 4
"""

from __future__ import annotations

import argparse
import json
import random
import sys
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path

import cv2
import numpy as np

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_MODEL = ROOT / "runs/retrain/mealybug_v16_selffix/weights/best.pt"
DEFAULT_IMAGES = ROOT / "datasets/mealybug_v13afix/test/images"
DEFAULT_LABELS = ROOT / "datasets/mealybug_v13afix/test/labels_v16_corrected"
FALLBACK_LABELS = ROOT / "datasets/mealybug_v13afix/test/labels"
OUT_DIR = ROOT / "docs/thesis/assets/confusion_cases_v16"
THESIS_MD = ROOT / "docs/thesis/CONFUSION_CASES_V16.md"


@dataclass(frozen=True)
class Box:
    x1: float
    y1: float
    x2: float
    y2: float
    conf: float = 1.0

    def clip(self, w: int, h: int) -> Box:
        return Box(
            max(0.0, min(self.x1, w)),
            max(0.0, min(self.y1, h)),
            max(0.0, min(self.x2, w)),
            max(0.0, min(self.y2, h)),
            self.conf,
        )


@dataclass
class Case:
    category: str
    image_path: Path
    box: Box
    gt_box: Box | None
    iou: float
    note: str


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(description="Export confusion-case figures for thesis")
    p.add_argument("--model", type=Path, default=DEFAULT_MODEL)
    p.add_argument("--images", type=Path, default=DEFAULT_IMAGES)
    p.add_argument("--labels", type=Path, default=None)
    p.add_argument("--out", type=Path, default=OUT_DIR)
    p.add_argument("--conf", type=float, default=0.25, help="Deploy threshold")
    p.add_argument("--iou-match", type=float, default=0.50)
    p.add_argument("--iou-poor-max", type=float, default=0.50)
    p.add_argument("--iou-poor-min", type=float, default=0.30)
    p.add_argument("--imgsz", type=int, default=1280)
    p.add_argument("--max-images", type=int, default=600)
    p.add_argument("--samples-per-class", type=int, default=4)
    p.add_argument("--seed", type=int, default=42)
    return p.parse_args()


def yolo_to_xyxy(row: list[float], w: int, h: int) -> Box:
    xc, yc, bw, bh = row
    x1 = (xc - bw / 2) * w
    y1 = (yc - bh / 2) * h
    x2 = (xc + bw / 2) * w
    y2 = (yc + bh / 2) * h
    return Box(x1, y1, x2, y2).clip(w, h)


def load_gt(label_path: Path, w: int, h: int) -> list[Box]:
    if not label_path.is_file():
        return []
    boxes: list[Box] = []
    for line in label_path.read_text(encoding="utf-8").splitlines():
        parts = line.strip().split()
        if len(parts) < 5:
            continue
        boxes.append(yolo_to_xyxy([float(x) for x in parts[1:5]], w, h))
    return boxes


def iou(a: Box, b: Box) -> float:
    ix1 = max(a.x1, b.x1)
    iy1 = max(a.y1, b.y1)
    ix2 = min(a.x2, b.x2)
    iy2 = min(a.y2, b.y2)
    iw = max(0.0, ix2 - ix1)
    ih = max(0.0, iy2 - iy1)
    inter = iw * ih
    if inter <= 0:
        return 0.0
    area_a = max(0.0, a.x2 - a.x1) * max(0.0, a.y2 - a.y1)
    area_b = max(0.0, b.x2 - b.x1) * max(0.0, b.y2 - b.y1)
    union = area_a + area_b - inter
    return inter / union if union > 0 else 0.0


def match_boxes(
    preds: list[Box], gts: list[Box], iou_match: float
) -> tuple[list[tuple[Box, Box, float]], list[Box], list[Box]]:
    if not preds and not gts:
        return [], [], []
    if not preds:
        return [], [], list(gts)
    if not gts:
        return [], list(preds), []

    pairs: list[tuple[int, int, float]] = []
    for pi, p in enumerate(preds):
        for gi, g in enumerate(gts):
            pairs.append((pi, gi, iou(p, g)))
    pairs.sort(key=lambda x: x[2], reverse=True)

    used_p: set[int] = set()
    used_g: set[int] = set()
    matched: list[tuple[Box, Box, float]] = []
    for pi, gi, score in pairs:
        if score < iou_match:
            break
        if pi in used_p or gi in used_g:
            continue
        used_p.add(pi)
        used_g.add(gi)
        matched.append((preds[pi], gts[gi], score))

    unmatched_preds = [p for i, p in enumerate(preds) if i not in used_p]
    unmatched_gts = [g for i, g in enumerate(gts) if i not in used_g]
    return matched, unmatched_preds, unmatched_gts


def expand_crop(box: Box, w: int, h: int, pad: float = 0.35) -> tuple[int, int, int, int]:
    bw = box.x2 - box.x1
    bh = box.y2 - box.y1
    cx = (box.x1 + box.x2) / 2
    cy = (box.y1 + box.y2) / 2
    side = max(bw, bh) * (1 + pad * 2)
    x1 = int(max(0, cx - side / 2))
    y1 = int(max(0, cy - side / 2))
    x2 = int(min(w, cx + side / 2))
    y2 = int(min(h, cy + side / 2))
    return x1, y1, x2, y2


def draw_case(img: np.ndarray, case: Case) -> np.ndarray:
    out = img.copy()
    x1, y1, x2, y2 = map(int, (case.box.x1, case.box.y1, case.box.x2, case.box.y2))
    colors = {
        "tp": (46, 204, 113),
        "fp": (231, 76, 60),
        "fn": (241, 196, 15),
        "poor_localization": (52, 152, 219),
    }
    color = colors.get(case.category, (255, 255, 255))
    cv2.rectangle(out, (x1, y1), (x2, y2), color, 2)
    if case.gt_box is not None:
        gx1, gy1, gx2, gy2 = map(
            int, (case.gt_box.x1, case.gt_box.y1, case.gt_box.x2, case.gt_box.y2)
        )
        cv2.rectangle(out, (gx1, gy1), (gx2, gy2), (255, 255, 255), 1)
    label = case.category.upper()
    if case.box.conf < 1.0:
        label += f" {case.box.conf:.2f}"
    if case.iou > 0:
        label += f" IoU={case.iou:.2f}"
    cv2.putText(
        out,
        label,
        (max(0, x1), max(18, y1 - 6)),
        cv2.FONT_HERSHEY_SIMPLEX,
        0.55,
        color,
        2,
        cv2.LINE_AA,
    )
    return out


def save_case(case: Case, out_dir: Path, index: int) -> Path:
    img = cv2.imread(str(case.image_path))
    if img is None:
        raise RuntimeError(f"Could not read {case.image_path}")
    h, w = img.shape[:2]
    x1, y1, x2, y2 = expand_crop(case.box if case.category != "fn" else case.gt_box or case.box, w, h)
    crop = draw_case(img[y1:y2, x1:x2], shift_case(case, -x1, -y1))
    stem = case.image_path.stem[:48]
    fname = f"{index:02d}_{case.category}_{stem}.jpg"
    dest = out_dir / case.category / fname
    dest.parent.mkdir(parents=True, exist_ok=True)
    cv2.imwrite(str(dest), crop, [int(cv2.IMWRITE_JPEG_QUALITY), 92])
    return dest


def shift_case(case: Case, dx: int, dy: int) -> Case:
    b = case.box
    shifted = Box(b.x1 + dx, b.y1 + dy, b.x2 + dx, b.y2 + dy, b.conf)
    gt = case.gt_box
    shifted_gt = None
    if gt is not None:
        shifted_gt = Box(gt.x1 + dx, gt.y1 + dy, gt.x2 + dx, gt.y2 + dy, gt.conf)
    return Case(case.category, case.image_path, shifted, shifted_gt, case.iou, case.note)


def pick_samples(cases: list[Case], n: int, rng: random.Random) -> list[Case]:
    if len(cases) <= n:
        return cases
    by_image: dict[str, list[Case]] = {}
    for c in cases:
        by_image.setdefault(c.image_path.name, []).append(c)
    keys = list(by_image.keys())
    rng.shuffle(keys)
    picked: list[Case] = []
    for key in keys:
        if len(picked) >= n:
            break
        picked.append(rng.choice(by_image[key]))
    if len(picked) < n:
        rest = [c for c in cases if c not in picked]
        rng.shuffle(rest)
        picked.extend(rest[: n - len(picked)])
    return picked[:n]


def build_markdown(
    saved: dict[str, list[dict]],
    meta: dict,
    out_dir: Path,
) -> str:
    rel = out_dir.relative_to(ROOT).as_posix()
    lines = [
        "# Confusion Cases — mealybug_v16_selffix (Panel Guidance #7)",
        "",
        f"*Generated: {meta['generated_at']}*",
        "",
        "Qualitative error analysis on the held-out test split. "
        "Green = true positive (pred); white = ground truth; red = false positive; "
        "yellow = false negative (missed GT); blue = poor localization.",
        "",
        f"- Model: `{meta['model']}`",
        f"- Labels: `{meta['labels']}`",
        f"- Confidence threshold: **{meta['conf']}** (deploy-aligned)",
        f"- IoU match threshold: **{meta['iou_match']}**",
        f"- Images scanned: **{meta['images_scanned']}**",
        "",
        "## Paste into Chapter IV (Discussion)",
        "",
        "> To complement aggregate metrics (73.3% mAP@0.5, 64.7% recall), "
        "Figure X presents representative detection outcomes on held-out test images. "
        "True positives show that the model detects visible mealybug clusters under "
        "reasonable field-like conditions. False positives often involve white leaf "
        "residue, glare, or textured patches that resemble mealybug wax. False negatives "
        "occur on small, partially occluded, or low-contrast pests — consistent with the "
        "recall limitation noted by the panel. Poor-localization cases (loose boxes or "
        "IoU below strict thresholds) contribute to the lower mAP@0.5:0.95 (40.7%) and "
        "indicate that bounding boxes are not yet consistently tight enough for strict "
        "localization evaluation.",
        "",
    ]
    captions = {
        "tp": "True positive — model correctly localizes a mealybug instance.",
        "fp": "False positive — model flags a non-pest region (e.g., white residue/glare).",
        "fn": "False negative — ground-truth mealybug missed at deploy threshold.",
        "poor_localization": "Poor localization — loose box (IoU 0.50–0.75) or overlap below match threshold.",
    }
    for cat in ("tp", "fp", "fn", "poor_localization"):
        items = saved.get(cat, [])
        lines += [f"## {cat.replace('_', ' ').title()}", ""]
        if not items:
            lines += ["*(No samples exported — re-run script with more images.)*", ""]
            continue
        for item in items:
            rel_path = Path(item["file"]).relative_to(ROOT).as_posix()
            lines += [
                f"![{cat}]({rel_path})",
                "",
                f"*{captions[cat]}* Source: `{item['source_image']}` — {item['note']}",
                "",
            ]
    lines += [
        "## Regenerate",
        "",
        "```powershell",
        "cd D:\\old_PINE",
        "python scripts/export_confusion_cases.py",
        "```",
        "",
        f"Output folder: `{rel}/`",
        "",
    ]
    return "\n".join(lines)


def main() -> int:
    args = parse_args()
    labels_dir = args.labels
    if labels_dir is None:
        labels_dir = DEFAULT_LABELS if DEFAULT_LABELS.is_dir() else FALLBACK_LABELS

    if not args.model.is_file():
        print(f"Missing model: {args.model}", file=sys.stderr)
        return 1
    if not args.images.is_dir():
        print(f"Missing images: {args.images}", file=sys.stderr)
        return 1
    if not labels_dir.is_dir():
        print(f"Missing labels: {labels_dir}", file=sys.stderr)
        return 1

    from ultralytics import YOLO

    rng = random.Random(args.seed)
    image_paths = sorted(
        p
        for p in args.images.iterdir()
        if p.suffix.lower() in {".jpg", ".jpeg", ".png", ".webp"}
    )
    rng.shuffle(image_paths)
    image_paths = image_paths[: args.max_images]

    model = YOLO(str(args.model))
    buckets: dict[str, list[Case]] = {
        "tp": [],
        "fp": [],
        "fn": [],
        "poor_localization": [],
    }

    print(f"Scanning {len(image_paths)} images @ conf={args.conf} ...")
    for img_path in image_paths:
        label_path = labels_dir / f"{img_path.stem}.txt"
        img = cv2.imread(str(img_path))
        if img is None:
            continue
        h, w = img.shape[:2]
        gts = load_gt(label_path, w, h)

        results = model.predict(
            source=str(img_path),
            conf=args.conf,
            iou=0.45,
            imgsz=args.imgsz,
            verbose=False,
        )
        preds: list[Box] = []
        if results and results[0].boxes is not None:
            for row in results[0].boxes.xyxy.cpu().numpy():
                x1, y1, x2, y2 = map(float, row[:4])
                conf = float(row[4]) if len(row) > 4 else 1.0
                preds.append(Box(x1, y1, x2, y2, conf))

        matched, fps, fns = match_boxes(preds, gts, args.iou_match)

        for pred, gt, score in matched:
            buckets["tp"].append(
                Case("tp", img_path, pred, gt, score, "Matched at IoU >= 0.50")
            )
            if score < 0.75:
                buckets["poor_localization"].append(
                    Case(
                        "poor_localization",
                        img_path,
                        pred,
                        gt,
                        score,
                        "Detected but box not tight (IoU 0.50–0.75)",
                    )
                )

        for pred in fps:
            best_iou = max((iou(pred, g) for g in gts), default=0.0)
            if args.iou_poor_min <= best_iou < args.iou_poor_max:
                gt = max(gts, key=lambda g: iou(pred, g))
                buckets["poor_localization"].append(
                    Case(
                        "poor_localization",
                        img_path,
                        pred,
                        gt,
                        best_iou,
                        "Overlap with GT but below IoU 0.50 match",
                    )
                )
            buckets["fp"].append(
                Case(
                    "fp",
                    img_path,
                    pred,
                    None,
                    0.0,
                    "No overlapping ground-truth box",
                )
            )

        for gt in fns:
            buckets["fn"].append(
                Case(
                    "fn",
                    img_path,
                    gt,
                    gt,
                    0.0,
                    "Ground truth not detected at deploy threshold",
                )
            )

    if args.out.exists():
        for child in args.out.iterdir():
            if child.is_dir():
                for f in child.glob("*"):
                    f.unlink()
            elif child.is_file():
                child.unlink()

    saved: dict[str, list[dict]] = {}
    for cat in buckets:
        samples = pick_samples(buckets[cat], args.samples_per_class, rng)
        saved[cat] = []
        for i, case in enumerate(samples, 1):
            dest = save_case(case, args.out, i)
            saved[cat].append(
                {
                    "file": str(dest),
                    "source_image": case.image_path.name,
                    "iou": round(case.iou, 3),
                    "conf": round(case.box.conf, 3),
                    "note": case.note,
                }
            )
            print(f"  saved {cat}: {dest.name}")

    meta = {
        "generated_at": datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M UTC"),
        "model": str(args.model.relative_to(ROOT)),
        "labels": str(labels_dir.relative_to(ROOT)),
        "conf": args.conf,
        "iou_match": args.iou_match,
        "images_scanned": len(image_paths),
        "counts_found": {k: len(v) for k, v in buckets.items()},
        "counts_exported": {k: len(v) for k, v in saved.items()},
    }
    (args.out / "manifest.json").write_text(
        json.dumps({"meta": meta, "samples": saved}, indent=2),
        encoding="utf-8",
    )
    THESIS_MD.write_text(build_markdown(saved, meta, args.out), encoding="utf-8")
    print(f"\nWrote {THESIS_MD}")
    print(f"Manifest: {args.out / 'manifest.json'}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
