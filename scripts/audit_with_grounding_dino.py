#!/usr/bin/env python3
"""
Audit annotations using GroundingDINO (zero-shot detector).
This gives an unbiased second opinion since GroundingDINO was never trained on your data.

Usage:
  python scripts/audit_with_grounding_dino.py
  python scripts/audit_with_grounding_dino.py --limit 500
  python scripts/audit_with_grounding_dino.py --text-prompt "mealybug . insect . white pest"
"""

import argparse
import csv
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def parse_args():
    p = argparse.ArgumentParser(description="Audit annotations with GroundingDINO")
    p.add_argument("--dataset-dir", type=str,
                   default=str(ROOT / "datasets" / "mealybug_v13afix" / "train"),
                   help="Path to train folder (with images/ and labels/)")
    p.add_argument("--text-prompt", type=str, default="mealybug . white insect . pest on leaf",
                   help="Text prompt for GroundingDINO (use ' . ' to separate classes)")
    p.add_argument("--box-threshold", type=float, default=0.25,
                   help="GroundingDINO box confidence threshold")
    p.add_argument("--text-threshold", type=float, default=0.20,
                   help="GroundingDINO text confidence threshold")
    p.add_argument("--limit", type=int, default=None,
                   help="Limit number of images to process")
    p.add_argument("--output-dir", type=str,
                   default=str(ROOT / "runs" / "audit_dino"))
    p.add_argument("--no-ui", action="store_true",
                   help="Skip FiftyOne UI, just save results")
    return p.parse_args()


def load_grounding_dino():
    """Load GroundingDINO model."""
    try:
        from groundingdino.util.inference import load_model, predict
        import groundingdino
        
        # Find the config and weights
        gd_path = Path(groundingdino.__file__).parent
        config_path = gd_path / "config" / "GroundingDINO_SwinT_OGC.py"
        
        # Try to find or download weights
        import huggingface_hub
        weights_path = huggingface_hub.hf_hub_download(
            repo_id="ShilongLiu/GroundingDINO",
            filename="groundingdino_swint_ogc.pth",
        )
        
        model = load_model(str(config_path), weights_path)
        return model
    except Exception as e:
        print(f"  Error loading GroundingDINO: {e}")
        print("  Trying alternative loading method...")
        
        # Alternative: use the groundingdino-py package directly
        from groundingdino.util.inference import load_model, predict
        import torch
        import huggingface_hub
        
        weights_path = huggingface_hub.hf_hub_download(
            repo_id="ShilongLiu/GroundingDINO",
            filename="groundingdino_swint_ogc.pth",
        )
        
        # Find config in package
        import importlib.resources
        import groundingdino.config
        config_dir = Path(groundingdino.config.__file__).parent
        config_path = config_dir / "GroundingDINO_SwinT_OGC.py"
        
        model = load_model(str(config_path), weights_path)
        return model


def run_grounding_dino(model, image_path, text_prompt, box_threshold, text_threshold):
    """Run GroundingDINO on a single image."""
    from groundingdino.util.inference import predict
    from groundingdino.util.utils import get_phrases_from_posmap
    import groundingdino.datasets.transforms as T
    from PIL import Image
    import torch

    # Load and transform image
    image_pil = Image.open(image_path).convert("RGB")
    w, h = image_pil.size

    transform = T.Compose([
        T.RandomResize([800], max_size=1333),
        T.ToTensor(),
        T.Normalize([0.485, 0.456, 0.406], [0.229, 0.224, 0.225]),
    ])
    image_tensor, _ = transform(image_pil, None)

    # Run prediction
    boxes, logits, phrases = predict(
        model=model,
        image=image_tensor,
        caption=text_prompt,
        box_threshold=box_threshold,
        text_threshold=text_threshold,
    )

    # Convert boxes from cxcywh (0-1) to xywh (0-1) for FiftyOne
    detections = []
    for box, logit, phrase in zip(boxes, logits, phrases):
        cx, cy, bw, bh = box.tolist()
        x = cx - bw / 2
        y = cy - bh / 2
        detections.append({
            "bbox": [x, y, bw, bh],
            "confidence": logit.item(),
            "phrase": phrase,
        })

    return detections


def main():
    args = parse_args()
    
    import fiftyone as fo
    import fiftyone.brain as fob
    import torch

    dataset_dir = Path(args.dataset_dir)
    output_dir = Path(args.output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)

    print("=" * 60)
    print("  ANNOTATION AUDIT WITH GROUNDING DINO")
    print("=" * 60)
    print(f"  Images:         {dataset_dir / 'images'}")
    print(f"  Labels:         {dataset_dir / 'labels'}")
    print(f"  Text prompt:    {args.text_prompt}")
    print(f"  Box threshold:  {args.box_threshold}")
    print(f"  Text threshold: {args.text_threshold}")
    print(f"  Device:         {'cuda' if torch.cuda.is_available() else 'cpu'}")
    print()

    # Load GroundingDINO
    print("Loading GroundingDINO model...")
    model = load_grounding_dino()
    print("  Model loaded!")

    # Load dataset
    print("\nLoading dataset into FiftyOne...")
    dataset_name = "mealybug_dino_audit"
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

    total = len(dataset)
    print(f"  Loaded {total} images")

    # Run GroundingDINO on all images
    print("\nRunning GroundingDINO predictions...")
    for i, sample in enumerate(dataset.iter_samples(autosave=True)):
        if (i + 1) % 100 == 0:
            print(f"  [{i+1}/{total}] processed...")

        try:
            dets = run_grounding_dino(
                model, sample.filepath,
                args.text_prompt, args.box_threshold, args.text_threshold
            )
        except Exception as e:
            if (i + 1) <= 3:
                print(f"  Warning: Failed on {Path(sample.filepath).name}: {e}")
            dets = []

        fo_dets = []
        for d in dets:
            fo_dets.append(fo.Detection(
                label="mealybug",
                bounding_box=d["bbox"],
                confidence=d["confidence"],
            ))
        sample["dino_predictions"] = fo.Detections(detections=fo_dets)

    print(f"  Done! {total} images processed.")

    # Compute mistakenness
    print("\nComputing mistakenness scores...")
    fob.compute_mistakenness(
        dataset,
        "dino_predictions",
        label_field="ground_truth",
    )

    # Sort and export results
    sorted_ds = dataset.sort_by("mistakenness", reverse=True)

    csv_path = output_dir / "dino_audit_report.csv"
    rows = []
    bad_count = 0

    for sample in sorted_ds.iter_samples(progress=True):
        score = getattr(sample, "mistakenness", 0) or 0
        gt_count = len(sample.ground_truth.detections) if sample.ground_truth else 0
        pred_count = len(sample.dino_predictions.detections) if sample.dino_predictions else 0

        if score > 0.5:
            bad_count += 1

        rows.append({
            "filename": Path(sample.filepath).name,
            "mistakenness": round(score, 4),
            "gt_boxes": gt_count,
            "dino_boxes": pred_count,
            "difference": pred_count - gt_count,
            "needs_review": "YES" if score > 0.5 else "no",
        })

    with open(csv_path, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=rows[0].keys())
        writer.writeheader()
        writer.writerows(rows)

    print(f"\n{'='*60}")
    print(f"  DINO AUDIT RESULTS")
    print(f"{'='*60}")
    print(f"  Total samples:        {total}")
    print(f"  Needs review (>0.5):  {bad_count}")
    print(f"  Looks good (≤0.5):    {total - bad_count}")
    print(f"  Report saved:         {csv_path}")

    # Show top 20
    print(f"\n  Top 20 most suspicious:")
    print(f"  {'-'*55}")
    for i, row in enumerate(rows[:20]):
        print(f"  {i+1:3d}. {row['filename']:<25s} score={row['mistakenness']:.4f} "
              f"GT={row['gt_boxes']} DINO={row['dino_boxes']} diff={row['difference']:+d}")

    if not args.no_ui:
        print(f"\n{'='*60}")
        print("  LAUNCHING FIFTYONE UI")
        print("  Open http://localhost:5151 in your browser")
        print("  Sort by 'mistakenness' to see worst annotations first")
        print("  Press Ctrl+C to stop")
        print("=" * 60)

        session = fo.launch_app(sorted_ds, port=5151)
        session.wait()
    else:
        print("\n  Skipped UI (--no-ui). Review the CSV for suspicious images.")


if __name__ == "__main__":
    main()
