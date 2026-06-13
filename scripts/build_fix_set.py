#!/usr/bin/env python3
"""
Build a ~500-image "fix set" from val/test (worst labels vs model) for CVAT re-boxing.

Convention (see docs/data/BOXING_GUIDELINES.md):
  - One tight box per mealybug
  - Negatives = empty .txt

Outputs under fix_sets/<name>/:
  images/              — copied images
  labels_ground_truth/ — original dataset labels (reference)
  labels_pre/          — YOLO pre-labels from best.pt (import these into CVAT)
  queue.csv            — priority scores and reasons
  manifest.json
  cvat_import.zip      — YOLO 1.1 package for CVAT upload
  README.md

Usage:
  python scripts/build_fix_set.py
  python scripts/build_fix_set.py --n 500 --prelabel --conf 0.15
  python scripts/build_fix_set.py --dry-run
  python scripts/build_fix_set.py --field-dir D:\\field_photos\\2026-05-21 --field-max 100
"""

from __future__ import annotations

import argparse
import csv
import json
import math
import shutil
import zipfile
from dataclasses import dataclass, field
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_DATASET = ROOT / "mealybug.v10-8th-yolo26n.yolo26"
DEFAULT_MODEL = ROOT / "runs" / "retrain" / "mealybug_v2" / "weights" / "best.pt"
IMAGE_EXTS = {".jpg", ".jpeg", ".png", ".webp", ".bmp"}


@dataclass
class Box:
    cls: int
    cx: float
    cy: float
    w: float
    h: float

    def area(self) -> float:
        return self.w * self.h

    def to_xyxy(self) -> tuple[float, float, float, float]:
        x1 = self.cx - self.w / 2
        y1 = self.cy - self.h / 2
        x2 = self.cx + self.w / 2
        y2 = self.cy + self.h / 2
        return x1, y1, x2, y2


@dataclass
class ImageScore:
    rel_path: str
    split: str
    score: float
    reasons: list[str] = field(default_factory=list)
    gt_count: int = 0
    pred_count: int = 0
    fn: int = 0
    fp: int = 0
    is_negative: bool = False


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(description="Build CVAT fix set from val/test.")
    p.add_argument("--dataset-root", type=Path, default=DEFAULT_DATASET)
    p.add_argument("--model", type=Path, default=DEFAULT_MODEL)
    p.add_argument("--splits", nargs="+", default=["valid", "test"])
    p.add_argument("-n", "--count", type=int, default=500, help="Target image count.")
    p.add_argument(
        "--negatives",
        type=int,
        default=40,
        help="How many empty-GT images to include (hard negatives).",
    )
    p.add_argument("--conf", type=float, default=0.12, help="Conf for scoring + pre-label.")
    p.add_argument("--iou", type=float, default=0.45, help="NMS IoU.")
    p.add_argument("--match-iou", type=float, default=0.5, help="IoU for GT/pred matching.")
    p.add_argument("--imgsz", type=int, default=640)
    p.add_argument("--device", default="")
    p.add_argument(
        "--output-name",
        type=str,
        default=None,
        help="Folder under fix_sets/ (default: fix500_YYYYMMDD).",
    )
    p.add_argument(
        "--field-dir",
        type=Path,
        default=None,
        help="Optional folder of new field photos to include first.",
    )
    p.add_argument(
        "--field-max",
        type=int,
        default=0,
        help="Max images from --field-dir (0 = all).",
    )
    p.add_argument(
        "--prelabel",
        action="store_true",
        help="Run YOLO predict and write labels_pre/ + cvat zip.",
    )
    p.add_argument("--dry-run", action="store_true", help="Score and print only; no copies.")
    return p.parse_args()


def load_boxes(path: Path) -> list[Box]:
    if not path.is_file():
        return []
    boxes: list[Box] = []
    for line in path.read_text(encoding="utf-8").strip().splitlines():
        parts = line.split()
        if len(parts) < 5:
            continue
        boxes.append(
            Box(
                cls=int(float(parts[0])),
                cx=float(parts[1]),
                cy=float(parts[2]),
                w=float(parts[3]),
                h=float(parts[4]),
            )
        )
    return boxes


def iou(a: Box, b: Box) -> float:
    ax1, ay1, ax2, ay2 = a.to_xyxy()
    bx1, by1, bx2, by2 = b.to_xyxy()
    ix1 = max(ax1, bx1)
    iy1 = max(ay1, by1)
    ix2 = min(ax2, bx2)
    iy2 = min(ay2, by2)
    if ix2 <= ix1 or iy2 <= iy1:
        return 0.0
    inter = (ix2 - ix1) * (iy2 - iy1)
    area_a = (ax2 - ax1) * (ay2 - ay1)
    area_b = (bx2 - bx1) * (by2 - by1)
    union = area_a + area_b - inter
    return inter / union if union > 0 else 0.0


def match_boxes(
    gt: list[Box], pred: list[Box], iou_thresh: float
) -> tuple[int, int, int, list[float]]:
    """Returns fn, fp, matched_count, matched_ious."""
    if not gt and not pred:
        return 0, 0, 0, []
    if not gt:
        return 0, len(pred), 0, []
    if not pred:
        return len(gt), 0, 0, []

    pairs: list[tuple[float, int, int]] = []
    for gi, g in enumerate(gt):
        for pi, p in enumerate(pred):
            v = iou(g, p)
            if v >= iou_thresh:
                pairs.append((v, gi, pi))
    pairs.sort(reverse=True)

    used_g: set[int] = set()
    used_p: set[int] = set()
    matched_ious: list[float] = []
    for v, gi, pi in pairs:
        if gi in used_g or pi in used_p:
            continue
        used_g.add(gi)
        used_p.add(pi)
        matched_ious.append(v)

    fn = len(gt) - len(used_g)
    fp = len(pred) - len(used_p)
    return fn, fp, len(matched_ious), matched_ious


def score_image(
    gt: list[Box],
    pred: list[Box],
    match_iou: float,
) -> tuple[float, list[str]]:
    reasons: list[str] = []
    if not gt:
        if pred:
            reasons.append("negative_with_fp")
            return 5.0 + len(pred), reasons
        reasons.append("negative_ok")
        return 0.5, reasons

    fn, fp, n_match, matched_ious = match_boxes(gt, pred, match_iou)
    score = 0.0

    if fn:
        reasons.append(f"fn_{fn}")
        score += 3.0 * fn
    if fp:
        reasons.append(f"fp_{fp}")
        score += 2.0 * fp

    count_delta = abs(len(gt) - len(pred))
    if count_delta:
        reasons.append(f"count_delta_{count_delta}")
        score += 2.5 * count_delta

    if matched_ious:
        mean_iou = sum(matched_ious) / len(matched_ious)
        if mean_iou < 0.65:
            reasons.append(f"low_iou_{mean_iou:.2f}")
            score += 2.0 * (0.65 - mean_iou)
    elif gt and pred:
        reasons.append("no_match")
        score += 4.0

    huge = [b for b in gt if b.area() > 0.04]
    if huge:
        reasons.append(f"large_gt_box_{len(huge)}")
        score += 1.5 * len(huge)

    tiny_gt = [b for b in gt if b.area() < 0.0008]
    if tiny_gt:
        reasons.append(f"tiny_gt_{len(tiny_gt)}")
        score += 0.5 * len(tiny_gt)

    if len(gt) == 1 and len(pred) >= 3:
        reasons.append("cluster_split_candidate")
        score += 3.0

    return score, reasons


def collect_split_images(dataset: Path, split: str) -> list[tuple[Path, Path, str]]:
    img_dir = dataset / split / "images"
    lbl_dir = dataset / split / "labels"
    if not img_dir.is_dir():
        raise SystemExit(f"Missing {img_dir}")
    rows: list[tuple[Path, Path, str]] = []
    for img in sorted(img_dir.iterdir()):
        if not img.is_file() or img.suffix.lower() not in IMAGE_EXTS:
            continue
        lbl = lbl_dir / f"{img.stem}.txt"
        rel = f"{split}/images/{img.name}"
        rows.append((img, lbl, rel))
    return rows


def collect_field_images(field_dir: Path, field_max: int) -> list[tuple[Path, Path | None, str]]:
    files: list[Path] = []
    for p in field_dir.rglob("*"):
        if p.is_file() and p.suffix.lower() in IMAGE_EXTS:
            files.append(p)
    files.sort(key=lambda x: x.name.lower())
    if field_max > 0:
        files = files[:field_max]
    rows: list[tuple[Path, Path | None, str]] = []
    for img in files:
        rel = f"field/{img.name}"
        rows.append((img, None, rel))
    return rows


def run_predict(
    model_path: Path,
    image_paths: list[Path],
    conf: float,
    iou: float,
    imgsz: int,
    device: str,
    scratch: Path,
) -> dict[str, list[Box]]:
    try:
        from ultralytics import YOLO
    except ImportError:
        raise SystemExit("pip install -U ultralytics torch")

    scratch.mkdir(parents=True, exist_ok=True)
    staging = scratch / "images"
    if staging.exists():
        shutil.rmtree(staging)
    staging.mkdir(parents=True)

    name_map: dict[str, str] = {}
    for i, src in enumerate(image_paths):
        dest = staging / f"{i:06d}_{src.stem}{src.suffix.lower()}"
        shutil.copy2(src, dest)
        name_map[src.as_posix()] = dest.stem

    model = YOLO(str(model_path))
    model.predict(
        source=str(staging),
        conf=conf,
        iou=iou,
        imgsz=imgsz,
        device=device or None,
        save_txt=True,
        save_conf=False,
        project=str(scratch),
        name="predict",
        exist_ok=True,
        verbose=False,
    )

    pred_dir = scratch / "predict" / "labels"
    out: dict[str, list[Box]] = {}
    for src in image_paths:
        stem = name_map[src.as_posix()]
        lbl = pred_dir / f"{stem}.txt"
        out[src.as_posix()] = load_boxes(lbl)
    return out


def write_yolo_labels(boxes: list[Box], path: Path) -> None:
    lines = [f"{b.cls} {b.cx:.6f} {b.cy:.6f} {b.w:.6f} {b.h:.6f}" for b in boxes]
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("\n".join(lines) + ("\n" if lines else ""), encoding="utf-8")


def package_cvat_zip(out_dir: Path, label_subdir: str = "labels_pre") -> Path:
    """CVAT YOLO 1.1: obj.data, obj.names, train.txt, obj_train_data/{img+txt}."""
    zip_path = out_dir / "cvat_import_yolo11.zip"
    img_dir = out_dir / "images"
    lbl_dir = out_dir / label_subdir
    data_name = "obj_train_data"

    names = out_dir / "obj.names"
    names.write_text("mealybug\n", encoding="utf-8")
    obj_data = out_dir / "obj.data"
    obj_data.write_text("classes = 1\nnames = obj.names\ntrain = train.txt\n", encoding="utf-8")

    images = sorted(p for p in img_dir.iterdir() if p.is_file())
    train_txt = out_dir / "train.txt"
    train_txt.write_text(
        "\n".join(f"{data_name}/{p.name}" for p in images) + ("\n" if images else ""),
        encoding="utf-8",
    )

    with zipfile.ZipFile(zip_path, "w", compression=zipfile.ZIP_DEFLATED) as zf:
        zf.write(obj_data, "obj.data")
        zf.write(names, "obj.names")
        zf.write(train_txt, "train.txt")
        for img in images:
            zf.write(img, f"{data_name}/{img.name}")
            lbl = lbl_dir / f"{img.stem}.txt"
            text = lbl.read_text(encoding="utf-8") if lbl.is_file() else ""
            zf.writestr(f"{data_name}/{img.stem}.txt", text)

    # Legacy name symlink note in manifest; images-only zip for two-step CVAT upload
    return zip_path


def write_readme(out_dir: Path, name: str) -> None:
    text = f"""# Fix set: {name}

## Boxing rules

Read **docs/data/BOXING_GUIDELINES.md** (one box per mealybug, tight boxes, empty negatives).

## CVAT import

1. Open [CVAT](https://app.cvat.ai) → **Tasks** → **Create task**.
2. **Import dataset** → format **YOLO 1.1** → upload `{out_dir.name}/cvat_import.zip`.
3. Review every image; fix pre-labels in `labels_pre/` convention.
4. **Export** → YOLO 1.1 → extract to `labels_reviewed/`.

## After export

```powershell
cd D:\\old_PINE
.\\.venv\\Scripts\\python.exe scripts\\merge_fix_set_review.py --fix-set fix_sets\\{out_dir.name}
```

## Folders

| Folder | Purpose |
|--------|---------|
| `images/` | Images for review |
| `labels_ground_truth/` | Original labels (reference only) |
| `labels_pre/` | Model pre-labels (what CVAT imported) |
| `labels_reviewed/` | Put CVAT export here after review |
| `queue.csv` | Why each image was selected |

"""
    (out_dir / "README.md").write_text(text, encoding="utf-8")


def main() -> None:
    args = parse_args()
    dataset = args.dataset_root.resolve()
    if not dataset.is_dir():
        raise SystemExit(f"Dataset not found: {dataset}")
    if not args.dry_run and not args.model.is_file():
        raise SystemExit(f"Model not found: {args.model}")

    stamp = datetime.now(timezone.utc).strftime("%Y%m%d")
    out_name = args.output_name or f"fix500_{stamp}"
    out_dir = ROOT / "fix_sets" / out_name

    entries: list[tuple[Path, Path | None, str, str]] = []
    for split in args.splits:
        for img, lbl, rel in collect_split_images(dataset, split):
            entries.append((img, lbl, rel, split))

    field_count = 0
    if args.field_dir and args.field_dir.is_dir():
        field_rows = collect_field_images(
            args.field_dir.resolve(),
            args.field_max,
        )
        field_count = len(field_rows)
        for img, lbl, rel in field_rows:
            entries.insert(0, (img, lbl, rel, "field"))

    if not entries:
        raise SystemExit("No images found.")

    print(f"Scoring {len(entries)} images (conf={args.conf})...")
    image_paths = [e[0] for e in entries]
    preds_by_src: dict[str, list[Box]] = {}
    if not args.dry_run:
        scratch = out_dir / "_scratch_predict"
        preds_by_src = run_predict(
            args.model,
            image_paths,
            args.conf,
            args.iou,
            args.imgsz,
            args.device,
            scratch,
        )
    else:
        for img, _, _, _ in entries:
            preds_by_src[img.as_posix()] = []

    scored: list[ImageScore] = []
    for img, lbl_path, rel, split in entries:
        gt = load_boxes(lbl_path) if lbl_path else []
        pred = preds_by_src.get(img.as_posix(), [])
        score, reasons = score_image(gt, pred, args.match_iou)
        if split == "field":
            score += 10.0
            reasons.insert(0, "field_new")
        scored.append(
            ImageScore(
                rel_path=rel,
                split=split,
                score=score,
                reasons=reasons,
                gt_count=len(gt),
                pred_count=len(pred),
                fn=match_boxes(gt, pred, args.match_iou)[0],
                fp=match_boxes(gt, pred, args.match_iou)[1],
                is_negative=len(gt) == 0,
            )
        )

    positives = [s for s in scored if not s.is_negative]
    negatives = [s for s in scored if s.is_negative]
    positives.sort(key=lambda s: s.score, reverse=True)
    negatives.sort(key=lambda s: s.score, reverse=True)

    n_field = min(field_count, args.count)
    n_neg = min(args.negatives, len(negatives), max(0, args.count - n_field))
    n_pos = args.count - n_field - n_neg

    selected: list[ImageScore] = []
    if n_field:
        selected.extend([s for s in scored if s.split == "field"][:n_field])
    selected.extend(positives[:n_pos])
    selected.extend(negatives[:n_neg])
    # Dedupe by rel_path
    seen: set[str] = set()
    unique: list[ImageScore] = []
    for s in selected:
        if s.rel_path in seen:
            continue
        seen.add(s.rel_path)
        unique.append(s)
    selected = unique[: args.count]

    print(f"Selected {len(selected)} images (field={n_field}, pos={n_pos}, neg={n_neg})")
    if args.dry_run:
        for s in selected[:15]:
            print(f"  {s.score:.2f} {s.rel_path} {','.join(s.reasons)}")
        print("Dry run — no files written.")
        return

    if out_dir.exists():
        shutil.rmtree(out_dir)
    img_out = out_dir / "images"
    gt_out = out_dir / "labels_ground_truth"
    pre_out = out_dir / "labels_pre"
    for d in (img_out, gt_out, pre_out):
        d.mkdir(parents=True, exist_ok=True)

    path_by_rel = {rel: img for img, _, rel, _ in entries}
    lbl_by_rel = {rel: lbl for img, lbl, rel, _ in entries if lbl}

    for s in selected:
        src_img = path_by_rel[s.rel_path]
        dest_name = f"{s.split}_{src_img.stem}{src_img.suffix.lower()}"
        shutil.copy2(src_img, img_out / dest_name)
        gt_lbl = lbl_by_rel.get(s.rel_path)
        if gt_lbl and gt_lbl.is_file():
            shutil.copy2(gt_lbl, gt_out / f"{dest_name.rsplit('.', 1)[0]}.txt")
        else:
            (gt_out / f"{Path(dest_name).stem}.txt").write_text("", encoding="utf-8")

        pred_boxes = preds_by_src.get(src_img.as_posix(), [])
        write_yolo_labels(pred_boxes, pre_out / f"{Path(dest_name).stem}.txt")

    with (out_dir / "queue.csv").open("w", newline="", encoding="utf-8") as f:
        w = csv.writer(f)
        w.writerow(
            [
                "dest_image",
                "source_rel",
                "split",
                "score",
                "gt_count",
                "pred_count",
                "fn",
                "fp",
                "reasons",
            ]
        )
        for s in selected:
            dest_name = f"{s.split}_{path_by_rel[s.rel_path].stem}{path_by_rel[s.rel_path].suffix.lower()}"
            w.writerow(
                [
                    dest_name,
                    s.rel_path,
                    s.split,
                    f"{s.score:.3f}",
                    s.gt_count,
                    s.pred_count,
                    s.fn,
                    s.fp,
                    ";".join(s.reasons),
                ]
            )

    manifest = {
        "created_utc": datetime.now(timezone.utc).isoformat(),
        "name": out_name,
        "dataset_root": str(dataset),
        "model": str(args.model),
        "conf": args.conf,
        "iou": args.iou,
        "target_count": args.count,
        "selected_count": len(selected),
        "field_included": n_field,
        "negatives_included": n_neg,
        "boxing_guidelines": "docs/data/BOXING_GUIDELINES.md",
        "cvat_format": "YOLO 1.1",
        "cvat_zip": str(out_dir / "cvat_import.zip"),
    }
    (out_dir / "manifest.json").write_text(json.dumps(manifest, indent=2), encoding="utf-8")

    zip_path = package_cvat_zip(out_dir, "labels_pre")
    write_readme(out_dir, out_name)
    manifest["cvat_zip"] = str(zip_path)
    (out_dir / "manifest.json").write_text(json.dumps(manifest, indent=2), encoding="utf-8")

    scratch = out_dir / "_scratch_predict"
    if scratch.is_dir():
        shutil.rmtree(scratch, ignore_errors=True)

    print(json.dumps(manifest, indent=2))
    print(f"\nFix set ready: {out_dir}")
    print(f"CVAT upload: {zip_path}")
    print("Guidelines: docs/data/BOXING_GUIDELINES.md")


if __name__ == "__main__":
    main()
