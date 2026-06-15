#!/usr/bin/env python3
"""Plot training and threshold calibration curves for thesis / reports."""

from __future__ import annotations

import csv
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT_DIR = ROOT / "runs" / "calibration"


def load_training_rows(results_csv: Path) -> tuple[list[int], list[float], list[float], list[float], list[float]]:
    epochs, map50, map5095, prec, rec = [], [], [], [], []
    with results_csv.open(newline="", encoding="utf-8") as f:
        for row in csv.DictReader(f):
            epochs.append(int(row["epoch"]))
            prec.append(float(row["metrics/precision(B)"]))
            rec.append(float(row["metrics/recall(B)"]))
            map50.append(float(row["metrics/mAP50(B)"]))
            map5095.append(float(row["metrics/mAP50-95(B)"]))
    return epochs, prec, rec, map50, map5095


def plot_figure_26_grid(
    results_csv: Path,
    out_png: Path,
    *,
    model_label: str,
    run_note: str,
) -> None:
    """Thesis-style 2x2: Precision, Recall, mAP@0.5, mAP@0.5:0.95 vs epoch."""
    import matplotlib.pyplot as plt

    epochs, prec, rec, map50, map5095 = load_training_rows(results_csv)
    n = len(epochs)

    fig, axes = plt.subplots(2, 2, figsize=(10, 8))
    fig.suptitle(
        "YOLO26n Training Performance Curves (Precision, Recall, mAP)",
        fontsize=14,
        fontweight="bold",
        y=0.98,
    )
    fig.text(
        0.5,
        0.93,
        f"{model_label} — validation metrics (from results.csv). {run_note}",
        ha="center",
        fontsize=10,
        color="#444444",
    )

    specs = [
        (axes[0, 0], prec, "Precision", "#1f77b4"),
        (axes[0, 1], rec, "Recall", "#2ca02c"),
        (axes[1, 0], map50, "mAP@0.5", "#d62728"),
        (axes[1, 1], map5095, "mAP@0.5:0.95", "#9467bd"),
    ]
    for ax, series, ylab, color in specs:
        ax.plot(epochs, series, color=color, linewidth=2)
        ax.set_xlabel("Epoch", fontsize=11)
        ax.set_ylabel(ylab, fontsize=11)
        ax.set_xlim(1, max(epochs))
        ax.grid(True, alpha=0.35)
        ax.set_axisbelow(True)

    fig.subplots_adjust(top=0.88, hspace=0.32, wspace=0.28)
    fig.savefig(out_png, dpi=200, bbox_inches="tight")
    plt.close(fig)


def plot_training(results_csv: Path, out_png: Path, title: str) -> None:
    import matplotlib.pyplot as plt

    epochs, prec, rec, map50, map5095 = load_training_rows(results_csv)
    map50 = [x * 100 for x in map50]
    map5095 = [x * 100 for x in map5095]
    prec = [x * 100 for x in prec]
    rec = [x * 100 for x in rec]

    fig, ax = plt.subplots(figsize=(8, 5))
    ax.plot(epochs, map50, "o-", label="mAP@0.5 (val)", linewidth=2, markersize=5)
    ax.plot(epochs, map5095, "s--", label="mAP@0.5:0.95 (val)", linewidth=1.5, alpha=0.85)
    ax.plot(epochs, prec, "^-", label="Precision (val)", linewidth=1.5, alpha=0.9)
    ax.plot(epochs, rec, "v-", label="Recall (val)", linewidth=1.5, alpha=0.9)
    best_i = max(range(len(map50)), key=lambda i: map50[i])
    ax.axvline(epochs[best_i], color="gray", linestyle=":", alpha=0.6)
    ax.annotate(
        f"best epoch {epochs[best_i]}\nmAP@0.5={map50[best_i]:.1f}%",
        xy=(epochs[best_i], map50[best_i]),
        xytext=(epochs[best_i] - 4, map50[best_i] + 2),
        fontsize=9,
        arrowprops=dict(arrowstyle="->", color="gray"),
    )
    ax.set_xlabel("Epoch")
    ax.set_ylabel("Metric (%)")
    ax.set_title(title)
    ax.set_ylim(0, max(max(map50), max(prec), max(rec)) + 8)
    ax.grid(True, alpha=0.3)
    ax.legend(loc="lower right", fontsize=9)
    fig.tight_layout()
    fig.savefig(out_png, dpi=150)
    plt.close(fig)


def plot_threshold(sweep_json: Path, out_png: Path) -> None:
    import matplotlib.pyplot as plt

    data = json.loads(sweep_json.read_text(encoding="utf-8"))
    rows = data["rows"]
    rec = data["recommendation"]
    conf = [r["conf"] for r in rows]
    p = [r["precision"] * 100 for r in rows]
    r = [r["recall"] * 100 for r in rows]
    f1 = [r["f1"] * 100 for r in rows]

    fig, ax = plt.subplots(figsize=(8, 5))
    ax.plot(conf, p, "o-", label="Precision", linewidth=2)
    ax.plot(conf, r, "s-", label="Recall", linewidth=2)
    ax.plot(conf, f1, "D-", label="F1", linewidth=2)
    ax.axvline(rec["two_tier"]["possible_threshold"], color="C0", linestyle=":", alpha=0.7)
    ax.axvline(rec["two_tier"]["confirmed_threshold"], color="C1", linestyle=":", alpha=0.7)
    ax.annotate(
        f"possible {rec['two_tier']['possible_threshold']}",
        xy=(rec["two_tier"]["possible_threshold"], max(f1) - 1),
        fontsize=8,
        ha="center",
    )
    ax.annotate(
        f"confirmed {rec['two_tier']['confirmed_threshold']}",
        xy=(rec["two_tier"]["confirmed_threshold"], max(f1) - 6),
        fontsize=8,
        ha="center",
    )
    ax.set_xlabel("Confidence threshold")
    ax.set_ylabel("Metric (%) on val split")
    ax.set_title("v11 — precision / recall / F1 vs confidence (Ultralytics val)")
    ax.grid(True, alpha=0.3)
    ax.legend(loc="center right", fontsize=9)
    fig.tight_layout()
    fig.savefig(out_png, dpi=150)
    plt.close(fig)


def main() -> None:
    try:
        import matplotlib  # noqa: F401
    except ImportError:
        raise SystemExit("pip install matplotlib")

    OUT_DIR.mkdir(parents=True, exist_ok=True)
    v11_csv = ROOT / "runs" / "retrain" / "mealybug_v11" / "results.csv"
    sweep = ROOT / "runs" / "calibration" / "threshold_sweep.json"

    train_png = OUT_DIR / "model_training_curve_v11.png"
    thresh_png = OUT_DIR / "model_threshold_curve_v11.png"

    v2_csv = ROOT / "runs" / "retrain" / "mealybug_v2" / "results.csv"
    v16_csv = ROOT / "runs" / "retrain" / "mealybug_v16_selffix" / "results.csv"
    fig26_v11 = OUT_DIR / "figure_26_training_curves_v11.png"
    fig26_v2 = OUT_DIR / "figure_26_training_curves_v2.png"
    fig26_v16 = OUT_DIR / "figure_26_training_curves_v16_selffix.png"

    plot_training(
        v11_csv,
        train_png,
        "mealybug_v11 fine-tune — validation metrics per epoch",
    )
    plot_threshold(sweep, thresh_png)
    plot_figure_26_grid(
        v11_csv,
        fig26_v11,
        model_label="YOLO26n mealybug_v11",
        run_note="Fine-tune from v10; 16 epochs (early stop).",
    )
    plot_figure_26_grid(
        v2_csv,
        fig26_v2,
        model_label="YOLO26n mealybug_v2",
        run_note="Full train; 50 epochs (legacy comparison).",
    )
    if v16_csv.is_file():
        plot_figure_26_grid(
            v16_csv,
            fig26_v16,
            model_label="YOLO26s mealybug_v16_selffix",
            run_note="Fine-tune from v15; 92 epochs (deployed checkpoint).",
        )

    print(f"Wrote {train_png}")
    print(f"Wrote {thresh_png}")
    print(f"Wrote {fig26_v11}")
    print(f"Wrote {fig26_v2}")
    if v16_csv.is_file():
        print(f"Wrote {fig26_v16}")


if __name__ == "__main__":
    main()
