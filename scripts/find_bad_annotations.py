#!/usr/bin/env python3
"""
Find bad/suspicious annotations using FiftyOne + model predictions.
Launches a web UI where you can visually review the worst annotations.

Usage:
  python scripts/find_bad_annotations.py
  python scripts/find_bad_annotations.py --limit 500  # only check 500 images
  python scripts/find_bad_annotations.py --no-ui      # just output CSV, no browser
"""

import argparse
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def parse_args():
    p = argparse.ArgumentParser(description="Find bad annotations with FiftyOne")
    p.add_argument("--dataset-dir", type=str,
                   default=str(ROOT / "datasets" / "mealybug_v13afix" / "train"),
                   help="Path to train folder (with images/ and labels/)")
    p.add_argument("--model", type=str,
                   default=str(ROOT / "runs" / "retrain" / "mealybug_v13afix" / "weights" / "best.pt"),
                   help="Model weights for prediction comparison")
    p.add_argument("--imgsz", type=int, default=640)
    p.add_argument("--conf", type=float, default=0.15,
                   help="Confidence threshold for model predictions")
    p.add_argument("--limit", type=int, default=None,
                   help="Limit number of images to process")
    p.add_argument("--no-ui", action="store_true",
                   help="Skip launching browser, just save results")
    p.add_argument("--output", type=str, default=str(ROOT / "runs" / "audit" / "suspicious_annotations.csv"))
    return p.parse_args()


def main():
    args = parse_args()

    import fiftyone as fo
    import fiftyone.utils.yolo as fouy
    from ultralytics import YOLO

    dataset_dir = Path(args.dataset_dir)
    images_dir = dataset_dir / "images"
    labels_dir = dataset_dir / "labels"

    print("=" * 60)
    print("  ANNOTATION QUALITY CHECK")
    print("=" * 60)
    print(f"  Images: {images_dir}")
    print(f"  Labels: {labels_dir}")
    print(f"  Model:  {args.model}")
    print(f"  Conf:   {args.conf}")
    print()

    # Load dataset into FiftyOne
    print("Loading dataset into FiftyOne...")
    dataset_name = "mealybug_annotation_check"

    if fo.dataset_exists(dataset_name):
        fo.delete_dataset(dataset_name)

    dataset = fo.Dataset.from_dir(
        dataset_type=fo.types.YOLOv5Dataset,
        dataset_dir=str(dataset_dir),
        name=dataset_name,
    )

    if args.limit:
        dataset = dataset.limit(args.limit)
        print(f"  Limited to {args.limit} images")

    print(f"  Loaded {len(dataset)} images")

    # Run model predictions
    print("\nRunning model predictions...")
    model = YOLO(args.model)

    image_paths = [s.filepath for s in dataset]
    total = len(image_paths)

    for i, sample in enumerate(dataset.iter_samples(autosave=True)):
        if (i + 1) % 200 == 0:
            print(f"  [{i+1}/{total}] processed...")

        results = model(sample.filepath, imgsz=args.imgsz, conf=args.conf, verbose=False)

        detections = []
        for r in results:
            if r.boxes is None:
                continue
            for box in r.boxes:
                x1, y1, x2, y2 = box.xyxy[0].cpu().numpy()
                conf = float(box.conf[0])
                w_img = r.orig_shape[1]
                h_img = r.orig_shape[0]
                # Convert to FiftyOne format [x, y, w, h] relative
                bounding_box = [
                    x1 / w_img,
                    y1 / h_img,
                    (x2 - x1) / w_img,
                    (y2 - y1) / h_img,
                ]
                detections.append(
                    fo.Detection(
                        label="mealybug",
                        bounding_box=bounding_box,
                        confidence=conf,
                    )
                )

        sample["predictions"] = fo.Detections(detections=detections)

    print(f"  Done! {total} images processed.")

    # Compute mistakenness (how likely annotations are wrong)
    print("\nComputing annotation quality scores...")
    import fiftyone.brain as fob

    fob.compute_mistakenness(
        dataset,
        "predictions",
        label_field="ground_truth",
    )

    # Sort by mistakenness (most suspicious first)
    suspicious = dataset.sort_by("mistakenness", reverse=True)

    # Save top suspicious to CSV
    output_path = Path(args.output)
    output_path.parent.mkdir(parents=True, exist_ok=True)

    print(f"\nTop 20 most suspicious images:")
    print("-" * 60)

    rows = []
    for i, sample in enumerate(suspicious.limit(500)):
        score = getattr(sample, "mistakenness", 0) or 0
        gt_count = len(sample.ground_truth.detections) if sample.ground_truth else 0
        pred_count = len(sample.predictions.detections) if sample.predictions else 0

        if i < 20:
            print(f"  {i+1}. {Path(sample.filepath).name}  "
                  f"score={score:.3f}  GT={gt_count}  Pred={pred_count}  "
                  f"diff={pred_count - gt_count:+d}")

        rows.append({
            "rank": i + 1,
            "filename": Path(sample.filepath).name,
            "mistakenness": round(score, 4),
            "gt_boxes": gt_count,
            "pred_boxes": pred_count,
            "difference": pred_count - gt_count,
        })

    # Write CSV
    import csv
    with open(output_path, "w", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=rows[0].keys())
        writer.writeheader()
        writer.writerows(rows)

    print(f"\n  Saved top 500 suspicious annotations to: {output_path}")

    if not args.no_ui:
        print("\n" + "=" * 60)
        print("  LAUNCHING FIFTYONE UI")
        print("  Open http://localhost:5151 in your browser")
        print("  Images are sorted by 'mistakenness' (worst first)")
        print("  Press Ctrl+C to stop")
        print("=" * 60)

        session = fo.launch_app(suspicious, port=5151)
        session.wait()
    else:
        print("\n  Skipped UI launch (--no-ui). Review the CSV to find bad images.")
        print("  Then fix them in Roboflow or CVAT.")


if __name__ == "__main__":
    main()
