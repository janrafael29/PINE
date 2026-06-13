#!/usr/bin/env python3
"""4-voter consensus labeling: v16 + v20s + v20m (YOLO) + GroundingDINO.

Decisions per train image (test GT is never touched):
  ADD     — box missing from GT, backed by >=2 voters (IoU>=0.5 cluster),
            at least one with conf >= --add-conf, OR backed by GDINO + 1 YOLO.
  REMOVE  — GT box with NO voter support at any conf (all 4 silent) -> dropped
            only when --apply-remove given (default: flagged for review only).
  TIGHTEN — GT box where >=2 voters agree with each other (IoU>=0.75 among
            voters) but GT box is loose vs the voter median (IoU 0.3-0.75).
            GT is replaced by the voter median box.
  UNSURE  — single-voter proposals in 0.25..add-conf band -> review queue CSV
            (feeds the crop-grid review page).

Usage:
  python scripts/build_consensus_labels.py \
      --labels datasets/mealybug_v20/train/labels \
      --caches runs/consensus/v16_train.jsonl runs/consensus/v20s_train.jsonl \
               runs/consensus/v20m_train.jsonl runs/consensus/gdino_train.jsonl \
      --gdino-index 3 \
      --out-labels datasets/mealybug_v21/train/labels \
      --report runs/consensus/consensus_report.json
"""

from __future__ import annotations

import argparse
import csv
import json
import statistics
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser()
    p.add_argument("--labels", type=Path, required=True, help="Existing GT labels dir (YOLO txt)")
    p.add_argument("--caches", type=Path, nargs="+", required=True, help="Detector JSONL caches")
    p.add_argument(
        "--yolo-indices", type=int, nargs="*", default=None,
        help="Indices in --caches that are domain-trained YOLOs (default: all). "
        "Auto-ADD requires at least one of these voters in the cluster.",
    )
    p.add_argument("--out-labels", type=Path, required=True)
    p.add_argument("--report", type=Path, default=ROOT / "runs/consensus/consensus_report.json")
    p.add_argument("--review-csv", type=Path, default=ROOT / "runs/consensus/review_queue.csv")
    p.add_argument("--add-conf", type=float, default=0.45, help="Min top-voter conf for auto-ADD")
    p.add_argument("--min-voters", type=int, default=2)
    p.add_argument("--iou-cluster", type=float, default=0.5)
    p.add_argument("--iou-gt-match", type=float, default=0.5)
    p.add_argument("--tighten-iou-lo", type=float, default=0.30)
    p.add_argument("--tighten-iou-hi", type=float, default=0.75)
    p.add_argument("--apply-remove", action="store_true", help="Actually drop zero-support GT boxes")
    p.add_argument("--remove-quarantine-conf", type=float, default=0.05)
    return p.parse_args()


def iou(a: list[float], b: list[float]) -> float:
    ix1, iy1 = max(a[0], b[0]), max(a[1], b[1])
    ix2, iy2 = min(a[2], b[2]), min(a[3], b[3])
    iw, ih = max(0.0, ix2 - ix1), max(0.0, iy2 - iy1)
    inter = iw * ih
    if inter <= 0:
        return 0.0
    aa = (a[2] - a[0]) * (a[3] - a[1])
    ab = (b[2] - b[0]) * (b[3] - b[1])
    return inter / (aa + ab - inter) if (aa + ab - inter) > 0 else 0.0


def load_cache(path: Path) -> dict[str, dict]:
    out: dict[str, dict] = {}
    for line in path.read_text(encoding="utf-8").splitlines():
        try:
            rec = json.loads(line)
            out[rec["image"]] = rec
        except Exception:
            continue
    return out


def yolo_to_xyxy(line: str, w: int, h: int) -> list[float] | None:
    parts = line.split()
    if len(parts) < 5:
        return None
    xc, yc, bw, bh = (float(v) for v in parts[1:5])
    return [(xc - bw / 2) * w, (yc - bh / 2) * h, (xc + bw / 2) * w, (yc + bh / 2) * h]


def xyxy_to_yolo(b: list[float], w: int, h: int) -> str:
    xc = (b[0] + b[2]) / 2 / w
    yc = (b[1] + b[3]) / 2 / h
    bw = (b[2] - b[0]) / w
    bh = (b[3] - b[1]) / h
    return f"0 {xc:.6f} {yc:.6f} {bw:.6f} {bh:.6f}"


def median_box(boxes: list[list[float]]) -> list[float]:
    return [statistics.median(b[i] for b in boxes) for i in range(4)]


def cluster_votes(per_voter: list[list[list[float]]], iou_thr: float) -> list[dict]:
    """Greedy cluster voter boxes across voters; one box per voter per cluster."""
    clusters: list[dict] = []
    for vi, boxes in enumerate(per_voter):
        for box in boxes:
            best, best_iou = None, iou_thr
            for c in clusters:
                if vi in c["voters"]:
                    continue
                i = iou(box[:4], c["ref"])
                if i >= best_iou:
                    best, best_iou = c, i
            if best is None:
                clusters.append({"ref": box[:4], "boxes": [box], "voters": {vi}, "max_conf": box[4]})
            else:
                best["boxes"].append(box)
                best["voters"].add(vi)
                best["max_conf"] = max(best["max_conf"], box[4])
                best["ref"] = median_box([b[:4] for b in best["boxes"]])
    return clusters


def main() -> None:
    args = parse_args()
    caches = [load_cache(c) for c in args.caches]
    names = set(caches[0])
    for c in caches[1:]:
        names &= set(c)
    print(f"voters={len(caches)} common_images={len(names)}")

    args.out_labels.mkdir(parents=True, exist_ok=True)
    args.report.parent.mkdir(parents=True, exist_ok=True)

    stats = defaultdict(int)
    review_rows: list[dict] = []

    for name in sorted(names):
        recs = [c[name] for c in caches]
        w, h = recs[0]["w"], recs[0]["h"]
        stem = Path(name).stem

        gt_path = args.labels / f"{stem}.txt"
        gt: list[list[float]] = []
        if gt_path.is_file():
            for line in gt_path.read_text(encoding="utf-8").splitlines():
                b = yolo_to_xyxy(line, w, h)
                if b:
                    gt.append(b)

        per_voter = [[b for b in r["boxes"]] for r in recs]
        clusters = cluster_votes(per_voter, args.iou_cluster)

        # match clusters to GT
        for c in clusters:
            c["gt_iou"] = max((iou(c["ref"], g) for g in gt), default=0.0)

        final: list[list[float]] = []

        # GT keep / tighten / remove
        for g in gt:
            support = [c for c in clusters if iou(c["ref"], g) >= args.iou_gt_match]
            weak_support = any(
                iou(b[:4], g) >= args.iou_gt_match
                for boxes in per_voter
                for b in boxes
            )
            strong = [c for c in support if len(c["voters"]) >= args.min_voters]
            if strong:
                c = max(strong, key=lambda x: len(x["voters"]))
                gt_vs_ref = iou(c["ref"], g)
                if args.tighten_iou_lo <= gt_vs_ref < args.tighten_iou_hi and len(c["voters"]) >= 2:
                    final.append(c["ref"])
                    stats["tightened"] += 1
                else:
                    final.append(g)
                    stats["kept"] += 1
            elif weak_support:
                final.append(g)
                stats["kept_weak"] += 1
            else:
                if args.apply_remove:
                    stats["removed"] += 1
                else:
                    final.append(g)
                    stats["flagged_remove"] += 1
                review_rows.append(
                    {"image": name, "kind": "remove?", "x1": round(g[0], 1), "y1": round(g[1], 1),
                     "x2": round(g[2], 1), "y2": round(g[3], 1), "conf": 0.0, "voters": 0}
                )

        # additions
        yolo_set = set(args.yolo_indices) if args.yolo_indices else set(range(len(caches)))
        for c in clusters:
            if c["gt_iou"] >= args.iou_gt_match:
                continue
            nv = len(c["voters"])
            has_yolo = bool(c["voters"] & yolo_set)
            has_independent = bool(c["voters"] - yolo_set)
            # Domain YOLO must be present; an independent witness lowers the conf bar.
            auto = has_yolo and (
                (nv >= args.min_voters and c["max_conf"] >= args.add_conf)
                or (has_independent and nv >= 2)
            )
            if auto:
                final.append(c["ref"])
                stats["added"] += 1
            elif c["max_conf"] >= 0.25:
                stats["review_add"] += 1
                review_rows.append(
                    {"image": name, "kind": "add?", "x1": round(c["ref"][0], 1), "y1": round(c["ref"][1], 1),
                     "x2": round(c["ref"][2], 1), "y2": round(c["ref"][3], 1),
                     "conf": round(c["max_conf"], 3), "voters": nv}
                )

        (args.out_labels / f"{stem}.txt").write_text(
            "\n".join(xyxy_to_yolo(b, w, h) for b in final) + ("\n" if final else ""),
            encoding="utf-8",
        )
        stats["images"] += 1

    with args.review_csv.open("w", newline="", encoding="utf-8") as f:
        wcsv = csv.DictWriter(f, fieldnames=["image", "kind", "x1", "y1", "x2", "y2", "conf", "voters"])
        wcsv.writeheader()
        wcsv.writerows(review_rows)

    report = {"params": {k: str(v) for k, v in vars(args).items()}, "stats": dict(stats)}
    args.report.write_text(json.dumps(report, indent=2), encoding="utf-8")
    print(json.dumps(dict(stats), indent=2))
    print(f"Labels -> {args.out_labels}")
    print(f"Review queue -> {args.review_csv} ({len(review_rows)} rows)")


if __name__ == "__main__":
    main()
