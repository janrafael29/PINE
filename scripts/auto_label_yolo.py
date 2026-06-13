#!/usr/bin/env python3
"""
Auto-label images with a local YOLO model (Option A — no Roboflow credits).

Writes YOLO detection labels under:
  <output_dir>/images/
  <output_dir>/labels/

Usage:
  python scripts/auto_label_yolo.py --source D:\\field_photos\\2026-05-21
  python scripts/auto_label_yolo.py --source ... --conf 0.25 --mark-empty

Review labels in CVAT / Label Studio / LabelImg, then:
  python scripts/merge_field_batch.py --batch <output_dir>
"""

from __future__ import annotations

import argparse
import json
import shutil
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_MODEL = ROOT / "runs" / "retrain" / "mealybug_v11" / "weights" / "best.pt"
IMAGE_EXTS = {".jpg", ".jpeg", ".png", ".webp", ".bmp"}


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(description="Pre-label images with YOLO (local, free).")
    p.add_argument(
        "--source",
        type=Path,
        required=True,
        help="Folder of new field photos (flat or nested).",
    )
    p.add_argument(
        "--output-dir",
        type=Path,
        default=None,
        help="YOLO batch folder (default: field_batches/<date>_<source_name>).",
    )
    p.add_argument(
        "--model",
        type=Path,
        default=DEFAULT_MODEL,
        help=f"YOLO .pt weights (default: {DEFAULT_MODEL}).",
    )
    p.add_argument(
        "--conf",
        type=float,
        default=0.22,
        help="Confidence for saving boxes (v11 val sweep F1-optimal; see threshold_sweep.json).",
    )
    p.add_argument("--iou", type=float, default=0.45, help="NMS IoU (match app default).")
    p.add_argument("--imgsz", type=int, default=640, help="Inference size.")
    p.add_argument(
        "--mark-empty",
        action="store_true",
        help="Write empty .txt for images with no detection (negatives).",
    )
    p.add_argument(
        "--copy-images",
        action="store_true",
        default=True,
        help="Copy images into output_dir/images (default: on).",
    )
    p.add_argument(
        "--no-copy-images",
        action="store_false",
        dest="copy_images",
        help="Only write labels; keep images in --source.",
    )
    p.add_argument("--device", default="", help="cuda device id, cpu, or empty for auto.")
    p.add_argument(
        "--resume",
        action="store_true",
        help="Skip images that already have a label in output_dir/labels.",
    )
    p.add_argument(
        "--tighten",
        action="store_true",
        help="Shrink each box to pale-pest foreground (scripts/label_tighten.py).",
    )
    p.add_argument(
        "--tighten-method",
        choices=("hsv", "grabcut"),
        default="hsv",
        help="Tightening method when --tighten is set (default: hsv).",
    )
    return p.parse_args()


def collect_images(src: Path) -> list[Path]:
    files: list[Path] = []
    for p in src.rglob("*"):
        if p.is_file() and p.suffix.lower() in IMAGE_EXTS:
            files.append(p)
    return sorted(files, key=lambda x: x.name.lower())


def main() -> None:
    args = parse_args()
    src = args.source.resolve()
    if not src.is_dir():
        raise SystemExit(f"Source not found: {src}")
    if not args.model.is_file():
        raise SystemExit(
            f"Model not found: {args.model}\n"
            "Train first or pass --model path/to/best.pt"
        )

    tighten_fn = None
    tighten_params = None
    if args.tighten:
        try:
            import cv2
        except ImportError:
            raise SystemExit("pip install opencv-python-headless (for --tighten)")
        import sys

        labeling_root = Path(__file__).resolve().parents[1] / "labeling_system"
        if str(labeling_root) not in sys.path:
            sys.path.insert(0, str(labeling_root))
        from pine_label.engine import Box, TightenParams, tighten_boxes_on_image

        tighten_params = TightenParams(method=args.tighten_method)
        tighten_fn = tighten_boxes_on_image

    images = collect_images(src)
    if not images:
        raise SystemExit(f"No images under {src}")

    if args.output_dir:
        out = args.output_dir.resolve()
    else:
        stamp = datetime.now(timezone.utc).strftime("%Y-%m-%d")
        out = ROOT / "field_batches" / f"{stamp}_{src.name}"

    img_dir = out / "images"
    lbl_dir = out / "labels"
    img_dir.mkdir(parents=True, exist_ok=True)
    lbl_dir.mkdir(parents=True, exist_ok=True)

    name_map: dict[str, str] = {}
    for i, img in enumerate(images):
        dest_name = f"{src.name}_{img.stem}{img.suffix.lower()}" if len(images) > 1 else img.name
        if dest_name in name_map.values():
            dest_name = f"{i:05d}_{img.stem}{img.suffix.lower()}"
        name_map[img.as_posix()] = dest_name
        dest_path = img_dir / dest_name
        if args.copy_images and not (args.resume and dest_path.is_file()):
            shutil.copy2(img, dest_path)
    try:
        from ultralytics import YOLO
    except ImportError:
        raise SystemExit("Install ultralytics: pip install -U ultralytics torch")

    model = YOLO(str(args.model))
    pred_labels = out / "_predict" / "run" / "labels"
    pred_labels.mkdir(parents=True, exist_ok=True)

    stats = {"with_boxes": 0, "empty": 0, "missing_label": 0, "skipped_resume": 0}
    predict_paths = sorted(
        p for p in img_dir.iterdir() if p.is_file() and p.suffix.lower() in IMAGE_EXTS
    )
    if not predict_paths:
        predict_paths = images
    total = len(predict_paths)
    for idx, path in enumerate(predict_paths, start=1):
        stem = path.stem
        dst_lbl = lbl_dir / f"{stem}.txt"
        if args.resume and dst_lbl.is_file():
            stats["skipped_resume"] += 1
            text = dst_lbl.read_text(encoding="utf-8").strip()
            if text:
                stats["with_boxes"] += 1
            else:
                stats["empty"] += 1
            continue

        preds = model.predict(
            source=str(path),
            conf=args.conf,
            iou=args.iou,
            imgsz=args.imgsz,
            device=args.device or None,
            save=False,
            verbose=False,
            batch=1,
            workers=0,
            stream=False,
        )
        boxes_out: list = []
        if preds:
            r0 = preds[0]
            if r0.boxes is not None and len(r0.boxes):
                for box in r0.boxes:
                    cls = int(box.cls.item())
                    xywhn = box.xywhn[0].tolist()
                    boxes_out.append(Box(cls, *xywhn))

        if boxes_out and tighten_fn is not None:
            import cv2

            bgr = cv2.imread(str(path))
            if bgr is not None:
                boxes_out = tighten_fn(bgr, boxes_out, tighten_params)

        lines = [b.to_yolo_line() for b in boxes_out]
        dst_lbl.write_text("\n".join(lines) + ("\n" if lines else ""), encoding="utf-8")
        if lines:
            stats["with_boxes"] += 1
        elif args.mark_empty:
            stats["empty"] += 1
        else:
            stats["missing_label"] += 1

        if idx % 25 == 0 or idx == total:
            print(f"labeled {idx}/{total}", flush=True)

    manifest = {
        "created_utc": datetime.now(timezone.utc).isoformat(),
        "source": str(src),
        "output_dir": str(out),
        "model": str(args.model),
        "conf": args.conf,
        "iou": args.iou,
        "tighten": args.tighten,
        "tighten_method": args.tighten_method if args.tighten else None,
        "image_count": len(images),
        "stats": stats,
        "next_steps": [
            "Review/fix labels in CVAT or Label Studio (import images + labels).",
            f"Merge into datasets: python scripts/merge_field_batch.py --batch {out}",
            "Roboflow: upload small batch only if you want cloud backup (browser or zip API).",
            "Train: python scripts/retrain_yolo.py (see RUN.md) or Vast GPU script.",
        ],
    }
    (out / "manifest.json").write_text(json.dumps(manifest, indent=2), encoding="utf-8")

    print(json.dumps(manifest, indent=2))
    print(f"\nDone. Labels: {lbl_dir}")
    if stats["missing_label"]:
        print(
            f"Warning: {stats['missing_label']} images have no label file. "
            "Re-run with --mark-empty to create empty negatives."
        )


if __name__ == "__main__":
    main()
