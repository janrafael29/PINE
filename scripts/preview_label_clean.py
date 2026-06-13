#!/usr/bin/env python3
"""Draw GT boxes for worst-for-CVAT images (before/after from .bak)."""

from __future__ import annotations

import argparse
import csv
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser()
    p.add_argument("--root", type=Path, default=ROOT / "mealybug.v10-8th-yolo26n.yolo26")
    p.add_argument(
        "--csv",
        type=Path,
        default=ROOT / "runs" / "label_clean" / "worst_for_cvat.csv",
    )
    p.add_argument("--n", type=int, default=24)
    p.add_argument("--out", type=Path, default=ROOT / "runs" / "label_clean" / "previews")
    return p.parse_args()


def yolo_boxes(path: Path, w_img: int, h_img: int) -> list[tuple[int, int, int, int]]:
    boxes = []
    for line in path.read_text(encoding="utf-8", errors="ignore").splitlines():
        parts = line.split()
        if len(parts) < 5:
            continue
        try:
            cx, cy, bw, bh = map(float, parts[-4:])
        except ValueError:
            continue
        x1 = int((cx - bw / 2) * w_img)
        y1 = int((cy - bh / 2) * h_img)
        x2 = int((cx + bw / 2) * w_img)
        y2 = int((cy + bh / 2) * h_img)
        boxes.append((x1, y1, x2, y2))
    return boxes


def main() -> None:
    args = parse_args()
    try:
        import cv2
    except ImportError:
        raise SystemExit("Install opencv: pip install opencv-python-headless")

    args.out.mkdir(parents=True, exist_ok=True)
    rows = list(csv.DictReader(args.csv.open(encoding="utf-8")))
    for row in rows[: args.n]:
        rel = row["label_path"].replace("\\", "/")
        split, _, name = rel.partition("/")
        stem = Path(name).stem
        img_path = args.root / split / "images" / f"{stem}.jpg"
        if not img_path.is_file():
            for ext in (".png", ".jpeg", ".JPG"):
                alt = img_path.with_suffix(ext)
                if alt.is_file():
                    img_path = alt
                    break
        if not img_path.is_file():
            continue
        lbl = args.root / rel
        bak = lbl.with_suffix(lbl.suffix + ".bak")
        img = cv2.imread(str(img_path))
        if img is None:
            continue
        h, w = img.shape[:2]
        before = yolo_boxes(bak, w, h) if bak.is_file() else []
        after = yolo_boxes(lbl, w, h)
        panel = img.copy()
        for x1, y1, x2, y2 in before:
            cv2.rectangle(panel, (x1, y1), (x2, y2), (0, 0, 255), 1)
        for x1, y1, x2, y2 in after:
            cv2.rectangle(panel, (x1, y1), (x2, y2), (0, 255, 0), 2)
        cv2.putText(
            panel,
            f"red=before({len(before)}) green=after({len(after)})",
            (8, 24),
            cv2.FONT_HERSHEY_SIMPLEX,
            0.6,
            (255, 255, 255),
            2,
        )
        out_path = args.out / f"{stem}_clean.jpg"
        cv2.imwrite(str(out_path), panel)
        print(out_path)

    print(f"Wrote up to {args.n} previews to {args.out}")


if __name__ == "__main__":
    main()
