#!/usr/bin/env python3
"""Cache detector predictions to JSONL for consensus labeling.

Backends:
  yolo  — any ultralytics .pt checkpoint
  gdino — GroundingDINO via HF transformers (no custom CUDA ops)

Usage (H100):
  /venv/main/bin/python3 scripts/cache_detections.py --backend gdino \
      --images datasets/mealybug_v20/train/images --out runs/consensus/gdino_train.jsonl
  /venv/main/bin/python3 scripts/cache_detections.py --backend yolo \
      --model runs/retrain/mealybug_v16_selffix/weights/best.pt \
      --images datasets/mealybug_v20/train/images --out runs/consensus/v16_train.jsonl

Each JSONL line: {"image": name, "w": W, "h": H, "boxes": [[x1,y1,x2,y2,conf], ...]}
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PROMPT = "mealybug . white insect . pest on leaf"
IMG_EXTS = {".jpg", ".jpeg", ".png", ".webp"}


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser()
    p.add_argument("--backend", choices=["yolo", "gdino", "owlv2", "yoloworld"], required=True)
    p.add_argument("--model", type=Path, default=None, help="YOLO .pt (backend=yolo)")
    p.add_argument("--images", type=Path, required=True)
    p.add_argument("--out", type=Path, required=True)
    p.add_argument("--conf", type=float, default=0.05, help="YOLO min conf to record")
    p.add_argument("--imgsz", type=int, default=1280)
    p.add_argument("--batch", type=int, default=4)
    p.add_argument("--chunk", type=int, default=32)
    p.add_argument("--box-threshold", type=float, default=0.20, help="gdino box threshold")
    p.add_argument("--text-threshold", type=float, default=0.15, help="gdino text threshold")
    p.add_argument("--limit", type=int, default=0)
    return p.parse_args()


def list_images(d: Path, limit: int) -> list[Path]:
    paths = sorted(p for p in d.iterdir() if p.suffix.lower() in IMG_EXTS)
    return paths[:limit] if limit > 0 else paths


def done_names(out: Path) -> set[str]:
    if not out.is_file():
        return set()
    names = set()
    for line in out.read_text(encoding="utf-8").splitlines():
        try:
            names.add(json.loads(line)["image"])
        except Exception:
            continue
    return names


def run_yolo(args: argparse.Namespace, paths: list[Path], fh) -> None:
    from ultralytics import YOLO

    model = YOLO(str(args.model))
    for start in range(0, len(paths), args.chunk):
        chunk = paths[start : start + args.chunk]
        results = model.predict(
            source=[str(p) for p in chunk],
            conf=args.conf,
            iou=0.45,
            imgsz=args.imgsz,
            batch=args.batch,
            verbose=False,
            stream=True,
        )
        for idx, r in enumerate(results):
            img_path = chunk[idx]
            h, w = r.orig_shape
            boxes = []
            if r.boxes is not None:
                for row in r.boxes.data.cpu().numpy():
                    x1, y1, x2, y2, conf = (float(v) for v in row[:5])
                    boxes.append([round(x1, 1), round(y1, 1), round(x2, 1), round(y2, 1), round(conf, 4)])
            fh.write(json.dumps({"image": img_path.name, "w": int(w), "h": int(h), "boxes": boxes}) + "\n")
        fh.flush()
        print(f"  {min(start + args.chunk, len(paths))}/{len(paths)}", flush=True)


def run_gdino(args: argparse.Namespace, paths: list[Path], fh) -> None:
    import torch
    from PIL import Image
    from transformers import AutoModelForZeroShotObjectDetection, AutoProcessor

    device = "cuda" if torch.cuda.is_available() else "cpu"
    model_id = "IDEA-Research/grounding-dino-base"
    processor = AutoProcessor.from_pretrained(model_id)
    model = AutoModelForZeroShotObjectDetection.from_pretrained(model_id).to(device).eval()

    for i, img_path in enumerate(paths, 1):
        image = Image.open(img_path).convert("RGB")
        w, h = image.size
        inputs = processor(images=image, text=PROMPT, return_tensors="pt").to(device)
        with torch.no_grad():
            outputs = model(**inputs)
        res = processor.post_process_grounded_object_detection(
            outputs,
            inputs.input_ids,
            threshold=args.box_threshold,
            text_threshold=args.text_threshold,
            target_sizes=[(h, w)],
        )[0]
        boxes = []
        for box, score in zip(res["boxes"].cpu().numpy(), res["scores"].cpu().numpy()):
            x1, y1, x2, y2 = (float(v) for v in box)
            boxes.append([round(x1, 1), round(y1, 1), round(x2, 1), round(y2, 1), round(float(score), 4)])
        fh.write(json.dumps({"image": img_path.name, "w": w, "h": h, "boxes": boxes}) + "\n")
        if i % 25 == 0:
            fh.flush()
            print(f"  {i}/{len(paths)}", flush=True)
    fh.flush()


def run_owlv2(args: argparse.Namespace, paths: list[Path], fh) -> None:
    import torch
    from PIL import Image
    from transformers import Owlv2ForObjectDetection, Owlv2Processor

    device = "cuda" if torch.cuda.is_available() else "cpu"
    model_id = "google/owlv2-base-patch16-ensemble"
    processor = Owlv2Processor.from_pretrained(model_id)
    model = Owlv2ForObjectDetection.from_pretrained(model_id).to(device).eval()
    texts = [["mealybug", "white insect", "small white pest"]]

    for i, img_path in enumerate(paths, 1):
        image = Image.open(img_path).convert("RGB")
        w, h = image.size
        inputs = processor(text=texts, images=image, return_tensors="pt").to(device)
        with torch.no_grad():
            outputs = model(**inputs)
        post = getattr(processor, "post_process_grounded_object_detection", None) or getattr(
            processor, "post_process_object_detection"
        )
        res = post(outputs, threshold=args.box_threshold, target_sizes=torch.tensor([(h, w)]))[0]
        boxes = []
        for box, score in zip(res["boxes"].cpu().numpy(), res["scores"].cpu().numpy()):
            x1, y1, x2, y2 = (float(v) for v in box)
            boxes.append([round(x1, 1), round(y1, 1), round(x2, 1), round(y2, 1), round(float(score), 4)])
        fh.write(json.dumps({"image": img_path.name, "w": w, "h": h, "boxes": boxes}) + "\n")
        if i % 25 == 0:
            fh.flush()
            print(f"  {i}/{len(paths)}", flush=True)
    fh.flush()


def run_yoloworld(args: argparse.Namespace, paths: list[Path], fh) -> None:
    from ultralytics import YOLOWorld

    model = YOLOWorld("yolov8x-worldv2.pt")
    model.set_classes(["mealybug", "white insect", "small white pest"])
    for start in range(0, len(paths), args.chunk):
        chunk = paths[start : start + args.chunk]
        results = model.predict(
            source=[str(p) for p in chunk],
            conf=args.conf,
            iou=0.45,
            imgsz=args.imgsz,
            verbose=False,
            stream=True,
        )
        for idx, r in enumerate(results):
            img_path = chunk[idx]
            h, w = r.orig_shape
            boxes = []
            if r.boxes is not None:
                for row in r.boxes.data.cpu().numpy():
                    x1, y1, x2, y2, conf = (float(v) for v in row[:5])
                    boxes.append([round(x1, 1), round(y1, 1), round(x2, 1), round(y2, 1), round(conf, 4)])
            fh.write(json.dumps({"image": img_path.name, "w": int(w), "h": int(h), "boxes": boxes}) + "\n")
        fh.flush()
        print(f"  {min(start + args.chunk, len(paths))}/{len(paths)}", flush=True)


def main() -> None:
    args = parse_args()
    if args.backend == "yolo" and not (args.model and args.model.is_file()):
        raise SystemExit(f"Missing YOLO model: {args.model}")
    if not args.images.is_dir():
        raise SystemExit(f"Missing images dir: {args.images}")

    paths = list_images(args.images, args.limit)
    skip = done_names(args.out)
    todo = [p for p in paths if p.name not in skip]
    print(f"{args.backend}: {len(paths)} images, {len(skip)} cached, {len(todo)} to do")
    if not todo:
        print("Nothing to do.")
        return

    args.out.parent.mkdir(parents=True, exist_ok=True)
    runners = {"yolo": run_yolo, "gdino": run_gdino, "owlv2": run_owlv2, "yoloworld": run_yoloworld}
    with args.out.open("a", encoding="utf-8") as fh:
        runners[args.backend](args, todo, fh)
    print(f"Wrote {args.out}")


if __name__ == "__main__":
    main()
