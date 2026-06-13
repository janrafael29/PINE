#!/usr/bin/env python3
"""
Export FiftyOne annotation check results to CSV and optionally
auto-fix labels by replacing ground truth with model predictions
for high-mistakenness samples.

Usage:
  python scripts/export_fiftyone_results.py                    # just export CSV
  python scripts/export_fiftyone_results.py --auto-fix         # export + fix bad labels
  python scripts/export_fiftyone_results.py --threshold 0.6    # custom mistakenness cutoff
"""

import argparse
import csv
import shutil
from pathlib import Path
from datetime import datetime

ROOT = Path(__file__).resolve().parents[1]


def parse_args():
    p = argparse.ArgumentParser(description="Export FiftyOne results & auto-fix annotations")
    p.add_argument("--dataset-name", type=str, default="mealybug_annotation_check")
    p.add_argument("--threshold", type=float, default=0.7,
                   help="Mistakenness threshold above which to consider labels bad (0-1)")
    p.add_argument("--pred-conf", type=float, default=0.35,
                   help="Min prediction confidence to keep when replacing labels")
    p.add_argument("--auto-fix", action="store_true",
                   help="Actually overwrite label files for bad samples with model predictions")
    p.add_argument("--output-dir", type=str,
                   default=str(ROOT / "runs" / "audit"))
    p.add_argument("--labels-dir", type=str,
                   default=str(ROOT / "datasets" / "mealybug_v13afix" / "train" / "labels"))
    return p.parse_args()


def main():
    args = parse_args()
    import fiftyone as fo

    output_dir = Path(args.output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)

    # Load existing dataset
    if not fo.dataset_exists(args.dataset_name):
        print(f"ERROR: Dataset '{args.dataset_name}' not found in FiftyOne.")
        print("Run find_bad_annotations.py first.")
        return

    dataset = fo.load_dataset(args.dataset_name)
    print(f"Loaded dataset: {len(dataset)} samples")

    # Export full results CSV
    csv_path = output_dir / "full_mistakenness_report.csv"
    sorted_ds = dataset.sort_by("mistakenness", reverse=True)

    rows = []
    bad_samples = []

    for sample in sorted_ds.iter_samples(progress=True):
        score = getattr(sample, "mistakenness", 0) or 0
        gt_count = len(sample.ground_truth.detections) if sample.ground_truth else 0
        pred_count = len(sample.predictions.detections) if sample.predictions else 0
        possible_missing = getattr(sample, "possible_missing", None)
        possible_spurious = getattr(sample, "possible_spurious", None)

        row = {
            "filename": Path(sample.filepath).name,
            "mistakenness": round(score, 4),
            "gt_boxes": gt_count,
            "pred_boxes": pred_count,
            "difference": pred_count - gt_count,
            "possible_missing": possible_missing,
            "possible_spurious": possible_spurious,
            "needs_fix": "YES" if score > args.threshold else "no",
        }
        rows.append(row)

        if score > args.threshold:
            bad_samples.append(sample)

    with open(csv_path, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=rows[0].keys())
        writer.writeheader()
        writer.writerows(rows)

    total_bad = len(bad_samples)
    print(f"\n{'='*60}")
    print(f"  RESULTS SUMMARY")
    print(f"{'='*60}")
    print(f"  Total samples:    {len(dataset)}")
    print(f"  Bad (>{args.threshold}):    {total_bad}")
    print(f"  Good (≤{args.threshold}):   {len(dataset) - total_bad}")
    print(f"  Full report:      {csv_path}")
    print()

    if not args.auto_fix:
        print("  To auto-fix, re-run with --auto-fix flag")
        print(f"  This will replace labels for {total_bad} images with model predictions")
        return

    # Auto-fix: replace bad labels with model predictions
    labels_dir = Path(args.labels_dir)
    backup_dir = output_dir / f"labels_backup_{datetime.now().strftime('%Y%m%d_%H%M%S')}"

    print(f"\n  AUTO-FIX MODE")
    print(f"  Backing up labels to: {backup_dir}")
    print(f"  Fixing {total_bad} label files...")

    backup_dir.mkdir(parents=True, exist_ok=True)
    fixed = 0
    skipped = 0

    for sample in bad_samples:
        filename = Path(sample.filepath).stem + ".txt"
        label_file = labels_dir / filename

        # Backup original
        if label_file.exists():
            shutil.copy2(label_file, backup_dir / filename)

        # Get model predictions above threshold
        preds = sample.predictions
        if not preds or not preds.detections:
            skipped += 1
            continue

        good_preds = [d for d in preds.detections if d.confidence >= args.pred_conf]

        if not good_preds:
            skipped += 1
            continue

        # Write new YOLO label file
        lines = []
        for det in good_preds:
            bx, by, bw, bh = det.bounding_box  # relative [x, y, w, h] top-left
            cx = bx + bw / 2  # center x
            cy = by + bh / 2  # center y
            lines.append(f"0 {cx:.6f} {cy:.6f} {bw:.6f} {bh:.6f}")

        with open(label_file, "w") as f:
            f.write("\n".join(lines) + "\n")

        fixed += 1

    print(f"\n  Fixed:   {fixed} label files")
    print(f"  Skipped: {skipped} (no confident predictions)")
    print(f"  Backup:  {backup_dir}")
    print(f"\n  Done! Your labels are now cleaned.")


if __name__ == "__main__":
    main()
