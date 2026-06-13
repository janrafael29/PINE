#!/usr/bin/env python3
"""
Generate an EGG-style model + dataset report (PNG + HTML) for a YOLO detect run.

Usage:
  python scripts/generate_model_report.py --run mealybug_v12
  python scripts/generate_model_report.py --run mealybug_v12 --data mealybug.v10-8th-yolo26n.yolo26/data.yaml
"""

from __future__ import annotations

import argparse
import json
import textwrap
from datetime import datetime, timezone
from pathlib import Path

import matplotlib.pyplot as plt
import matplotlib.gridspec as gridspec
import numpy as np
import pandas as pd
from matplotlib.patches import Patch
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_DATA = ROOT / "mealybug.v10-8th-yolo26n.yolo26" / "data.yaml"
IMAGE_EXTS = {".jpg", ".jpeg", ".png", ".webp", ".bmp"}

# Per-run narrative (header + context panel). Benchmark plots always use --data yaml splits.
RUN_PROFILES: dict[str, dict] = {
    "mealybug_v12": {
        "train_imgsz": 1024,
        "intro": (
            "This report documents mealybug_v12 (YOLO26n), fine-tuned from v11 on the Roboflow v10 "
            "aug export (16,175 train / 923 val / 462 test). The Va field batch (~877 images) is not "
            "included in training."
        ),
        "dataset_title": "Dataset statistics (Roboflow v10 export — benchmark splits)",
        "field_note": (
            "Va (field batch, ~877 images) is separate — not in mealybug_v12 training data. "
            "Benchmark uses the fixed 462-image v10 test split only."
        ),
        "compare_line": "Prior shipped baseline: v11 test mAP@0.5 ≈ 43.0%.",
    },
    "mealybug_v13afix": {
        "train_imgsz": 640,
        "intro": (
            "This report documents mealybug_v13afix (YOLO26n), fine-tuned from v12 on the combined "
            "v13afix pool: Roboflow v10 + Va field images + unique fix500 labels + field horizontal-flip "
            "aug (70/20/10 split — 13,664 train / 3,904 val / 1,952 test). "
            "Headline benchmark below is still the original 462-image v10 test for fair comparison "
            "with v11, v12, and fix500."
        ),
        "dataset_title": "Benchmark dataset (Roboflow v10 export — val / test for fair compare)",
        "field_note": (
            "Training included ~877 field images and 500 fix500-unique images; v13afix internal test "
            "(1,952 images) is a different split — do not compare its 52.8% val mAP directly to the "
            "462-image benchmark below."
        ),
        "compare_line": "Beats v12 (43.8%) and fix500 (45.3%) on the same 462-image test @ conf 0.12.",
    },
}


def run_profile(run_name: str) -> dict:
    base = {
        "train_imgsz": 640,
        "intro": f"This report documents {run_name} (YOLO26n).",
        "dataset_title": "Dataset statistics",
        "field_note": "See training args.yaml for data source.",
        "compare_line": "",
    }
    base.update(RUN_PROFILES.get(run_name, {}))
    return base


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser()
    p.add_argument("--run", type=str, default="mealybug_v12", help="Folder under runs/retrain/")
    p.add_argument("--data", type=Path, default=DEFAULT_DATA)
    p.add_argument("--conf", type=float, default=0.12)
    p.add_argument("--iou", type=float, default=0.45)
    p.add_argument("--imgsz", type=int, default=640, help="Eval image size (benchmark)")
    p.add_argument("--train-imgsz", type=int, default=1024, help="Shown in header only")
    p.add_argument("--skip-val", action="store_true", help="Skip Ultralytics val (plots only from results.csv)")
    p.add_argument("--sample-images", type=int, default=6, help="Images in visual grid")
    p.add_argument("--dpi", type=int, default=110, help="PNG resolution (lower = smaller file)")
    p.add_argument("--jpeg-quality", type=int, default=85, help="Also write compressed .jpg")
    return p.parse_args()


def count_split(data_root: Path, split: str) -> dict:
    img_dir = data_root / split / "images"
    lbl_dir = data_root / split / "labels"
    imgs = [p for p in img_dir.iterdir() if p.is_file() and p.suffix.lower() in IMAGE_EXTS]
    empty = with_boxes = instances = 0
    for img in imgs:
        lbl = lbl_dir / f"{img.stem}.txt"
        if not lbl.is_file():
            continue
        lines = [ln for ln in lbl.read_text(encoding="utf-8").splitlines() if ln.strip()]
        if not lines:
            empty += 1
        else:
            with_boxes += 1
            instances += len(lines)
    return {
        "images": len(imgs),
        "with_boxes": with_boxes,
        "empty": empty,
        "instances": instances,
    }


def image_size_histogram(data_root: Path, max_samples: int = 800) -> tuple[list[int], list[int]]:
    widths: list[int] = []
    heights: list[int] = []
    for split in ("train", "valid", "test"):
        img_dir = data_root / split / "images"
        if not img_dir.is_dir():
            continue
        for i, p in enumerate(sorted(img_dir.iterdir())):
            if i >= max_samples:
                break
            if p.suffix.lower() not in IMAGE_EXTS:
                continue
            try:
                with Image.open(p) as im:
                    w, h = im.size
                widths.append(w)
                heights.append(h)
            except Exception:
                pass
    return widths, heights


def box_density_stats(data_root: Path, split: str) -> dict:
    lbl_dir = data_root / split / "labels"
    counts: list[int] = []
    if lbl_dir.is_dir():
        for p in lbl_dir.glob("*.txt"):
            n = sum(
                1
                for line in p.read_text(encoding="utf-8", errors="ignore").splitlines()
                if line.strip() and len(line.split()) >= 5
            )
            counts.append(n)
    if not counts:
        return {"images": 0, "max": 0, "p99": 0, "median": 0, "ge50": 0, "ge20": 0}
    counts.sort()
    n = len(counts)
    return {
        "images": n,
        "max": counts[-1],
        "p99": counts[int(0.99 * (n - 1))],
        "median": counts[n // 2],
        "ge50": sum(1 for c in counts if c >= 50),
        "ge20": sum(1 for c in counts if c >= 20),
    }


def load_run_augmentations(run_dir: Path) -> dict[str, str]:
    path = run_dir / "args.yaml"
    out: dict[str, str] = {}
    if not path.is_file():
        return out
    for line in path.read_text(encoding="utf-8").splitlines():
        if ":" not in line:
            continue
        key, _, val = line.partition(":")
        out[key.strip()] = val.strip()
    return out


def write_context_panel(
    ax,
    run_name: str,
    aug: dict[str, str],
    density: dict[str, dict],
    profile: dict,
) -> None:
    ax.axis("off")
    ax.text(0.5, 0.97, "Training & annotation context", ha="center", fontsize=12, fontweight="bold", va="top")

    on = lambda k, default="—": aug.get(k, default)
    train_aug = (
        f"Train-time (Ultralytics): HSV h/s/v={on('hsv_h')}/{on('hsv_s')}/{on('hsv_v')}, "
        f"fliplr={on('fliplr')}, translate={on('translate')}, scale={on('scale')}, "
        f"mosaic={on('mosaic')} (off last {on('close_mosaic')} epochs), "
        f"{on('auto_augment')}, erasing={on('erasing')}. "
        f"Off: mixup/cutmix/copy_paste/flipud/degrees."
    )
    dataset_aug = (
        "Dataset export (~5× Roboflow aug on ~3k sources): flip, 90° rotate, ±15° rotate, "
        "mild brightness/contrast, light noise."
    )
    annot = (
        "Labels: manual human review (CVAT / Roboflow); YOLO pre-label on new field photos only. "
        "Rules: docs/data/BOXING_GUIDELINES.md (one pest per box). Not SAM3."
    )
    va_note = profile.get("field_note", "")
    compare = profile.get("compare_line", "")
    tr, te = density.get("train", {}), density.get("test", {})
    boxes = (
        f"Box density: train max {tr.get('max', 0)} / p99 {tr.get('p99', 0)} / median {tr.get('median', 0)} "
        f"({tr.get('ge50', 0)} images ≥50 boxes); test max {te.get('max', 0)}. "
        "Most images are sparse; dense clusters are a minority."
    )
    diversity = (
        "Diversity: large aug train set, many tiny pests, empty negatives; mostly 640px Roboflow-style photos. "
        "Phone/crown field shots (Va) need merge + later train for full field generalization."
    )

    y = 0.86
    blocks = [train_aug, dataset_aug, annot, va_note, boxes, diversity]
    if compare:
        blocks.append(compare)
    for block in blocks:
        for line in textwrap.wrap(block, width=132):
            ax.text(0.02, y, line, ha="left", va="top", fontsize=7.8, color="#334155", transform=ax.transAxes)
            y -= 0.052


def donut(ax, labels: list[str], values: list[float], title: str, colors: list[str] | None = None) -> None:
    """Pie chart with legend below the chart (avoids overlap with neighbors)."""
    total = sum(values)
    if total <= 0:
        ax.text(0.5, 0.5, "No data", ha="center", va="center")
        ax.set_title(title, fontsize=10, fontweight="bold")
        ax.axis("off")
        return
    pcts = [100 * v / total for v in values]
    wedges, _, autotexts = ax.pie(
        values,
        labels=None,
        autopct=lambda pct: f"{pct:.1f}%" if pct > 5 else "",
        startangle=90,
        colors=colors,
        pctdistance=0.72,
        radius=0.52,
        center=(0.5, 0.62),
    )
    for t in autotexts:
        t.set_fontsize(7)
    ax.set_title(title, fontsize=10, fontweight="bold", pad=6)
    legend_lines = [f"{lab}: {int(val):,} ({pct:.1f}%)" for lab, val, pct in zip(labels, values, pcts)]
    ax.legend(
        wedges,
        legend_lines,
        loc="upper center",
        bbox_to_anchor=(0.5, -0.08),
        ncol=1,
        fontsize=7.5,
        frameon=False,
        handlelength=1.0,
        handletextpad=0.4,
        borderaxespad=0.0,
    )
    ax.set_xlim(0, 1)
    ax.set_ylim(-0.15, 1.05)
    ax.set_aspect("equal")
    ax.axis("off")


def write_header_block(
    ax,
    run_name: str,
    train_imgsz: int,
    eval_imgsz: int,
    conf: float,
    iou: float,
    val_metrics: dict | None,
    profile: dict,
) -> None:
    ax.axis("off")
    ax.text(
        0.5,
        0.97,
        "PINYA-PIC: YOLO-Based Mealybug Detection",
        ha="center",
        va="top",
        fontsize=20,
        fontweight="bold",
    )
    paragraphs = [
        (
            "PINYA-PIC is a mobile tool for pineapple farmers to screen photos for mealybugs. "
            "The app runs YOLO object detection on the phone: each pest is one bounding box, "
            "used for counts, severity hints, and geo-tagged field records."
        ),
        profile["intro"]
        + f" Train {train_imgsz}px; benchmark at conf={conf:.2f}, IoU={iou:.2f}, eval {eval_imgsz}px.",
    ]
    y = 0.78
    for para in paragraphs:
        for line in textwrap.wrap(para, width=118):
            ax.text(0.5, y, line, ha="center", va="top", fontsize=9.5, color="#334155")
            y -= 0.038
    ax.text(
        0.5,
        y - 0.02,
        f"Model: YOLO26n ({run_name})  ·  Task: detection (boxes)  ·  Train {train_imgsz}px  ·  Eval {eval_imgsz}px",
        ha="center",
        va="top",
        fontsize=9,
        color="#64748b",
    )
    if val_metrics:
        t = val_metrics["test"]
        ax.text(
            0.5,
            0.04,
            (
                f"Test benchmark — Precision {t['precision']*100:.1f}%  ·  "
                f"Recall {t['recall']*100:.1f}%  ·  "
                f"mAP@0.5 {t['mAP50']*100:.1f}%  ·  "
                f"mAP@0.5:0.95 {t['mAP50_95']*100:.1f}%"
            ),
            ha="center",
            va="bottom",
            fontsize=10,
            fontweight="bold",
            color="#0f766e",
        )


def save_figure_compressed(fig, path: Path, dpi: int, jpeg_quality: int) -> tuple[int, int]:
    """Save optimized PNG and optional JPEG; return (png_bytes, jpg_bytes)."""
    tmp = path.with_suffix(".tmp.png")
    fig.savefig(tmp, dpi=dpi, bbox_inches="tight", facecolor=fig.get_facecolor(), pad_inches=0.25)
    img = Image.open(tmp).convert("RGB")
    tmp.unlink(missing_ok=True)
    img.save(path, format="PNG", optimize=True, compress_level=9)
    png_size = path.stat().st_size
    jpg_path = path.with_name(f"{path.stem}_compressed.jpg")
    img.save(jpg_path, format="JPEG", quality=jpeg_quality, optimize=True)
    return png_size, jpg_path.stat().st_size


def plot_training_curves(ax_p, ax_r, ax_map, csv_path: Path) -> None:
    df = pd.read_csv(csv_path)
    df.columns = [c.strip() for c in df.columns]
    ep = df["epoch"]
    ax_p.plot(ep, df["metrics/precision(B)"], color="#2563eb", linewidth=1.5)
    ax_p.set_title("Precision (B) vs. Epoch", fontsize=10, fontweight="bold")
    ax_p.set_xlabel("Epoch")
    ax_p.set_ylabel("Precision")
    ax_p.set_ylim(0, 1)
    ax_p.grid(True, alpha=0.3)

    ax_r.plot(ep, df["metrics/recall(B)"], color="#16a34a", linewidth=1.5)
    ax_r.set_title("Recall (B) vs. Epoch", fontsize=10, fontweight="bold")
    ax_r.set_xlabel("Epoch")
    ax_r.set_ylabel("Recall")
    ax_r.set_ylim(0, 1)
    ax_r.grid(True, alpha=0.3)

    ax_map.plot(ep, df["metrics/mAP50(B)"], color="#9333ea", linewidth=1.5, label="mAP@0.5")
    ax_map.plot(ep, df["metrics/mAP50-95(B)"], color="#ea580c", linewidth=1.5, label="mAP@0.5:0.95")
    ax_map.set_title("mAP vs. Epoch", fontsize=10, fontweight="bold")
    ax_map.set_xlabel("Epoch")
    ax_map.set_ylabel("mAP")
    ax_map.set_ylim(0, 1)
    ax_map.legend(fontsize=8)
    ax_map.grid(True, alpha=0.3)


def embed_image_plot(ax, img_path: Path, title: str) -> None:
    ax.imshow(Image.open(img_path))
    ax.set_title(title, fontsize=9)
    ax.axis("off")


def run_val_plots(weights: Path, data: Path, out_dir: Path, conf: float, iou: float, imgsz: int) -> dict:
    from ultralytics import YOLO

    out_dir.mkdir(parents=True, exist_ok=True)
    model = YOLO(str(weights))
    metrics_test = model.val(
        data=str(data),
        split="test",
        conf=conf,
        iou=iou,
        imgsz=imgsz,
        plots=True,
        project=str(out_dir),
        name="val_test_plots",
        exist_ok=True,
        verbose=False,
    )
    plot_dir = out_dir / "val_test_plots"
    return {
        "test": {
            "precision": float(metrics_test.box.mp),
            "recall": float(metrics_test.box.mr),
            "mAP50": float(metrics_test.box.map50),
            "mAP50_95": float(metrics_test.box.map),
        },
        "plot_dir": str(plot_dir),
    }


def save_prediction_grid(
    weights: Path,
    data_root: Path,
    out_path: Path,
    n: int,
    conf: float,
    imgsz: int,
) -> None:
    from ultralytics import YOLO

    test_img = data_root / "test" / "images"
    paths = sorted(p for p in test_img.iterdir() if p.suffix.lower() in IMAGE_EXTS)[:n]
    if not paths:
        return
    model = YOLO(str(weights))
    labels_dir = data_root / "test" / "labels"
    cols = min(3, len(paths))
    rows = (len(paths) + cols - 1) // cols
    fig, axes = plt.subplots(rows * 2, cols, figsize=(4 * cols, 3.2 * rows * 2))
    if rows == 1 and cols == 1:
        axes = np.array([[axes[0]], [axes[1]]])  # type: ignore
    elif rows == 1:
        axes = np.array([axes[0], axes[1]])  # type: ignore
    fig.suptitle("Visual validation (test split sample)", fontsize=14, fontweight="bold", y=1.01)

    for idx, img_path in enumerate(paths):
        r, c = divmod(idx, cols)
        ax_gt = axes[r * 2, c] if rows > 1 else axes[0, c]
        ax_pr = axes[r * 2 + 1, c] if rows > 1 else axes[1, c]

        img = Image.open(img_path).convert("RGB")
        ax_gt.imshow(img)
        ax_gt.set_title(f"Labels: {img_path.name}", fontsize=8)
        ax_gt.axis("off")
        # draw GT boxes
        lbl = labels_dir / f"{img_path.stem}.txt"
        if lbl.is_file():
            w_img, h_img = img.size
            for line in lbl.read_text(encoding="utf-8").splitlines():
                parts = line.split()
                if len(parts) < 5:
                    continue
                _, cx, cy, bw, bh = map(float, parts[:5])
                x1 = (cx - bw / 2) * w_img
                y1 = (cy - bh / 2) * h_img
                rect = plt.Rectangle((x1, y1), bw * w_img, bh * h_img, fill=False, edgecolor="#22c55e", linewidth=2)
                ax_gt.add_patch(rect)

        results = model.predict(str(img_path), conf=conf, imgsz=imgsz, verbose=False)
        plot_img = results[0].plot()
        ax_pr.imshow(plot_img[:, :, ::-1] if plot_img.shape[2] == 3 else plot_img)
        ax_pr.set_title("Predictions", fontsize=8)
        ax_pr.axis("off")

    for idx in range(len(paths), rows * cols):
        r, c = divmod(idx, cols)
        axes[r * 2, c].axis("off")
        axes[r * 2 + 1, c].axis("off")

    fig.tight_layout()
    fig.savefig(out_path, dpi=120, bbox_inches="tight")
    plt.close(fig)


def compose_report(
    run_name: str,
    run_dir: Path,
    data_root: Path,
    train_imgsz: int,
    eval_imgsz: int,
    conf: float,
    iou: float,
    val_metrics: dict | None,
    skip_val: bool,
    dpi: int,
    jpeg_quality: int,
    profile: dict,
) -> Path:
    report_dir = run_dir / "report"
    report_dir.mkdir(parents=True, exist_ok=True)

    splits = {
        "train": count_split(data_root, "train"),
        "valid": count_split(data_root, "valid"),
        "test": count_split(data_root, "test"),
    }
    widths, heights = image_size_histogram(data_root)
    density = {s: box_density_stats(data_root, s) for s in ("train", "valid", "test")}
    aug = load_run_augmentations(run_dir)

    fig = plt.figure(figsize=(18, 34))
    fig.patch.set_facecolor("#f8fafc")
    gs = gridspec.GridSpec(
        7,
        3,
        figure=fig,
        height_ratios=[1.35, 0.25, 2.0, 1.05, 1.15, 0.25, 1.55],
        hspace=0.55,
        wspace=0.55,
    )

    ax_title = fig.add_subplot(gs[0, :])
    write_header_block(ax_title, run_name, train_imgsz, eval_imgsz, conf, iou, val_metrics, profile)

    # Dataset row
    ax_ds = fig.add_subplot(gs[1, :])
    ax_ds.axis("off")
    ax_ds.text(0.5, 0.95, profile["dataset_title"], ha="center", fontsize=14, fontweight="bold")

    ax_split = fig.add_subplot(gs[2, 0])
    donut(
        ax_split,
        ["Train", "Valid", "Test"],
        [splits["train"]["images"], splits["valid"]["images"], splits["test"]["images"]],
        "Split distribution",
        ["#3b82f6", "#8b5cf6", "#f59e0b"],
    )

    ax_inst = fig.add_subplot(gs[2, 1])
    inst_total = sum(splits[s]["instances"] for s in splits)
    donut(
        ax_inst,
        ["Train boxes", "Valid boxes", "Test boxes"],
        [splits["train"]["instances"], splits["valid"]["instances"], splits["test"]["instances"]],
        "Box instances by split",
        ["#3b82f6", "#8b5cf6", "#f59e0b"],
    )

    ax_dim = fig.add_subplot(gs[2, 2])
    if widths:
        bins = np.linspace(0, max(max(widths), max(heights)), 30)
        ax_dim.hist(widths, bins=bins, alpha=0.6, label="Width (px)", color="#3b82f6")
        ax_dim.hist(heights, bins=bins, alpha=0.5, label="Height (px)", color="#f97316")
        ax_dim.set_title("Image size (sampled splits)", fontsize=10, fontweight="bold")
        ax_dim.set_xlabel("Pixels")
        ax_dim.set_ylabel("Count")
        ax_dim.legend(fontsize=7, loc="upper right")
        ax_dim.tick_params(labelsize=8)
    else:
        ax_dim.axis("off")

    ax_ctx = fig.add_subplot(gs[3, :])
    write_context_panel(ax_ctx, run_name, aug, density, profile)

    # Training curves
    csv_path = run_dir / "results.csv"
    if csv_path.is_file():
        ax_p = fig.add_subplot(gs[4, 0])
        ax_r = fig.add_subplot(gs[4, 1])
        ax_map = fig.add_subplot(gs[4, 2])
        plot_training_curves(ax_p, ax_r, ax_map, csv_path)

    # Ultralytics plots
    plot_dir = report_dir / "val_test_plots"
    pr_curve = plot_dir / "BoxPR_curve.png"
    f1_curve = plot_dir / "BoxF1_curve.png"
    cm = plot_dir / "confusion_matrix_normalized.png"

    ax_eval_title = fig.add_subplot(gs[5, :])
    ax_eval_title.axis("off")
    ax_eval_title.text(0.5, 0.5, "Model evaluation (Ultralytics val plots)", ha="center", fontsize=14, fontweight="bold")

    for i, (path, label) in enumerate(
        [
            (pr_curve, "Box PR curve"),
            (f1_curve, "Box F1–confidence"),
            (cm, "Confusion matrix (normalized)"),
        ]
    ):
        ax = fig.add_subplot(gs[6, i])
        if path.is_file():
            embed_image_plot(ax, path, label)
        else:
            ax.text(0.5, 0.5, f"{label}\n(run with --skip-val off)", ha="center", va="center", fontsize=9)
            ax.axis("off")

    out_png = report_dir / f"pinya_{run_name}_report.png"
    png_bytes, jpg_bytes = save_figure_compressed(fig, out_png, dpi=dpi, jpeg_quality=jpeg_quality)
    plt.close(fig)

    # Visual grid separate (skip if already present — slow on CPU)
    grid_path = report_dir / f"pinya_{run_name}_visual_validation.png"
    weights = run_dir / "weights" / "best.pt"
    if weights.is_file() and not grid_path.is_file():
        save_prediction_grid(weights, data_root, grid_path, n=6, conf=conf, imgsz=eval_imgsz)

    # HTML
    html_path = report_dir / f"pinya_{run_name}_report.html"
    rel = lambda p: p.name
    desc_html = (
        "PINYA-PIC screens pineapple photos for mealybugs using on-device YOLO detection. "
        f"Report for {run_name}; benchmark on 462-image test split (conf={conf}, IoU={iou})."
    )
    html = f"""<!DOCTYPE html>
<html><head><meta charset="utf-8"><title>PINYA-PIC {run_name} Report</title>
<style>
body {{ font-family:Segoe UI,Arial,sans-serif; margin:24px; background:#f1f5f9; color:#0f172a; }}
h1 {{ font-size:28px; }} .card {{ background:#fff; border-radius:12px; padding:20px; margin:16px 0;
box-shadow:0 1px 3px rgba(0,0,0,.08); }} img {{ max-width:100%; height:auto; border-radius:8px; }}
table {{ border-collapse:collapse; width:100%; }} th,td {{ border:1px solid #e2e8f0; padding:8px; text-align:left; }}
.muted {{ color:#64748b; font-size:14px; }}
</style></head><body>
<h1>PINYA-PIC: YOLO mealybug detection ({run_name})</h1>
<div class="card"><p>{desc_html}</p>
<p class="muted">PNG ~{png_bytes//1024} KB · JPEG ~{jpg_bytes//1024} KB (compressed)</p></div>
<div class="card"><h2>Dataset splits</h2>
<table><tr><th>Split</th><th>Images</th><th>With boxes</th><th>Empty</th><th>Instances</th></tr>
"""
    for name, key in [("Train", "train"), ("Valid", "valid"), ("Test", "test")]:
        s = splits[key]
        html += f"<tr><td>{name}</td><td>{s['images']:,}</td><td>{s['with_boxes']:,}</td><td>{s['empty']:,}</td><td>{s['instances']:,}</td></tr>\n"
    html += "</table></div>\n"
    tr, te = density["train"], density["test"]
    html += f"""<div class="card"><h2>Context ({run_name})</h2>
<ul>
<li>{profile.get("field_note", "")}</li>
<li><b>Annotation</b> — manual review (CVAT/Roboflow); rules in BOXING_GUIDELINES.md; not SAM3.</li>
<li><b>Train aug</b> — mosaic, HSV, fliplr, RandAugment, erasing (see args.yaml); v10 export also ~5× Roboflow aug.</li>
<li><b>Box density (benchmark train split)</b> — max {tr['max']}, p99 {tr['p99']}, median {tr['median']} ({tr['ge50']} imgs ≥50); test max {te['max']}.</li>
"""
    if profile.get("compare_line"):
        html += f"<li><b>Benchmark</b> — {profile['compare_line']}</li>\n"
    html += "</ul></div>\n"
    html += f'<div class="card"><h2>Full report figure</h2><img src="{rel(out_png)}" alt="report"></div>\n'
    if grid_path.is_file():
        html += f'<div class="card"><h2>Visual validation</h2><img src="{rel(grid_path)}" alt="visual"></div>\n'
    html += f"<p><small>Generated {datetime.now(timezone.utc).isoformat()}</small></p></body></html>"
    html_path.write_text(html, encoding="utf-8")

    meta_json = {
        "run": run_name,
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "splits": splits,
        "box_density": density,
        "augmentations": aug,
        "val_metrics": val_metrics,
        "files": {
            "png": str(out_png),
            "jpg_compressed": str(out_png.with_name(f"{out_png.stem}_compressed.jpg")),
            "html": str(html_path),
            "visual": str(grid_path),
        },
        "sizes_bytes": {"png": png_bytes, "jpg": jpg_bytes},
    }
    (report_dir / "report_meta.json").write_text(json.dumps(meta_json, indent=2), encoding="utf-8")
    print(f"PNG: {png_bytes/1024:.0f} KB  |  JPEG: {jpg_bytes/1024:.0f} KB")
    return out_png


def main() -> None:
    args = parse_args()
    run_dir = ROOT / "runs" / "retrain" / args.run
    data_yaml = args.data.resolve()
    if not run_dir.is_dir():
        raise SystemExit(f"Run not found: {run_dir}")
    data_root = data_yaml.parent
    profile = run_profile(args.run)
    train_imgsz = RUN_PROFILES.get(args.run, {}).get("train_imgsz", args.train_imgsz)

    weights = run_dir / "weights" / "best.pt"
    val_metrics = None
    if not args.skip_val:
        if not weights.is_file():
            raise SystemExit(f"Weights not found: {weights}")
        print("Running val on test split (plots)...")
        val_metrics = run_val_plots(weights, data_yaml, run_dir / "report", args.conf, args.iou, args.imgsz)

    print("Composing report...")
    out = compose_report(
        args.run,
        run_dir,
        data_root,
        train_imgsz,
        args.imgsz,
        args.conf,
        args.iou,
        val_metrics,
        args.skip_val,
        args.dpi,
        args.jpeg_quality,
        profile,
    )
    print(f"Wrote {out}")
    print(f"Compressed JPEG: {out.with_name(out.stem + '_compressed.jpg')}")
    print(f"Open {out.parent / f'pinya_{args.run}_report.html'}")


if __name__ == "__main__":
    main()
