#!/usr/bin/env python3
"""Build v2 / v10 / v11 comparison table, CSV, and bar charts from eval JSON."""

from __future__ import annotations

import argparse
import csv
import json
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_EVAL = ROOT / "runs" / "calibration" / "model_comparison_eval.json"
OUT_DIR = ROOT / "runs" / "calibration"
DOC = ROOT / "docs" / "MODEL_COMPARISON_V2_V10_V11.md"

MODELS = [
    ("mealybug_v2", "v2", "Legacy baseline (trained on `datasets/`)"),
    ("mealybug_v10", "v10", "Full 17k Roboflow train (Vast)"),
    ("mealybug_v11", "v11", "Fine-tune from v10 + label clean (shipped)"),
]


def load_eval(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def training_peak(results_csv: Path) -> dict | None:
    if not results_csv.is_file():
        return None
    rows = list(csv.DictReader(results_csv.open(newline="", encoding="utf-8")))
    if not rows:
        return None
    best = max(rows, key=lambda r: float(r["metrics/mAP50(B)"]))
    last = rows[-1]
    return {
        "epochs": len(rows),
        "best_epoch": int(best["epoch"]),
        "best_mAP50_pct": round(float(best["metrics/mAP50(B)"]) * 100, 1),
        "last_mAP50_pct": round(float(last["metrics/mAP50(B)"]) * 100, 1),
        "val_split_note": "Ultralytics val during training (not Roboflow 17k unless noted)",
    }


def write_csv(eval_data: dict, out_csv: Path) -> None:
    rows_out = []
    for key, label, _ in MODELS:
        m = eval_data["models"][key]
        for split in ("val", "test"):
            s = m["splits"][split]
            rows_out.append(
                {
                    "model": label,
                    "split": split,
                    "conf": eval_data["conf"],
                    "iou": eval_data["iou"],
                    "precision_pct": s["precision_pct"],
                    "recall_pct": s["recall_pct"],
                    "f1_pct": round(s["f1"] * 100, 1),
                    "mAP50_pct": s["mAP50_pct"],
                    "mAP50_95_pct": s["mAP50_95_pct"],
                }
            )
    fieldnames = list(rows_out[0].keys())
    with out_csv.open("w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=fieldnames)
        w.writeheader()
        w.writerows(rows_out)


def write_markdown(
    eval_data: dict,
    peaks: dict[str, dict | None],
    out_md: Path,
    *,
    bars_png: Path,
    overlay_png: Path | None,
) -> None:
    conf = eval_data["conf"]
    data = eval_data["data"]
    lines = [
        "# Model comparison: v2 vs v10 vs v11",
        "",
        f"Generated: {datetime.now(timezone.utc).strftime('%Y-%m-%d %H:%M UTC')}",
        "",
        "## Fair benchmark (same dataset, same settings)",
        "",
        f"- **Data:** `{data}` (Roboflow v10 export, ~17k aug train / 923 val / 462 test)",
        f"- **Inference:** conf={conf}, IoU=0.45, imgsz=640",
        f"- **Source:** `runs/calibration/model_comparison_eval.json`",
        "",
        "### Test split (primary for thesis / app claims)",
        "",
        "| Model | Role | P | R | F1 | mAP@0.5 | mAP@0.5:0.95 |",
        "|-------|------|---:|---:|---:|--------:|-------------:|",
    ]
    for key, label, note in MODELS:
        s = eval_data["models"][key]["splits"]["test"]
        ship = " **shipped**" if label == "v11" else ""
        lines.append(
            f"| **{label}**{ship} | {note.split('(')[0].strip()} | "
            f"{s['precision_pct']:.1f}% | {s['recall_pct']:.1f}% | {round(s['f1']*100,1)}% | "
            f"**{s['mAP50_pct']:.1f}%** | {s['mAP50_95_pct']:.1f}% |"
        )
    lines += [
        "",
        "### Val split",
        "",
        "| Model | P | R | F1 | mAP@0.5 | mAP@0.5:0.95 |",
        "|-------|---:|---:|---:|--------:|-------------:|",
    ]
    for key, label, _ in MODELS:
        s = eval_data["models"][key]["splits"]["val"]
        lines.append(
            f"| **{label}** | {s['precision_pct']:.1f}% | {s['recall_pct']:.1f}% | "
            f"{round(s['f1']*100,1)}% | {s['mAP50_pct']:.1f}% | {s['mAP50_95_pct']:.1f}% |"
        )

    v2_test = eval_data["models"]["mealybug_v2"]["splits"]["test"]["mAP50_pct"]
    v11_test = eval_data["models"]["mealybug_v11"]["splits"]["test"]["mAP50_pct"]
    delta = v11_test - v2_test
    lines += [
        "",
        "### Takeaways",
        "",
        f"- **v11 beats v2 on the same test set by +{delta:.1f} pp mAP@0.5** ({v11_test:.1f}% vs {v2_test:.1f}%).",
        "- **v11 slightly beats v10** (+0.9 pp test mAP@0.5; +1.7 pp val) after label-clean fine-tune.",
        "- Do **not** compare v2’s ~65% training val mAP to v11 — v2 was trained/evaluated on a different, easier `datasets/` split.",
        "",
        "## Training-curve peaks (during train — not the fair benchmark above)",
        "",
        "| Model | Epochs | Best val mAP@0.5 (epoch) | Last val mAP@0.5 | Notes |",
        "|-------|-------:|-------------------------:|-----------------:|-------|",
    ]
    for key, label, note in MODELS:
        pk = peaks.get(key)
        if pk:
            lines.append(
                f"| {label} | {pk['epochs']} | {pk['best_mAP50_pct']}% (ep {pk['best_epoch']}) | "
                f"{pk['last_mAP50_pct']}% | {note} |"
            )
        else:
            lines.append(f"| {label} | — | — | — | No local `results.csv` |")

    lines += [
        "",
        "## Figures",
        "",
        f"- Bar chart (val + test mAP@0.5, P, R): `{bars_png.relative_to(ROOT).as_posix()}`",
    ]
    if overlay_png and overlay_png.is_file():
        lines.append(
            f"- Training val mAP@0.5 overlay (v2 vs v11 only): "
            f"`{overlay_png.relative_to(ROOT).as_posix()}` — **different val sets**"
        )
    lines += [
        "",
        "## Regenerate",
        "",
        "```bash",
        "python scripts/evaluate_model_accuracy.py \\",
        "  --model runs/retrain/mealybug_v2/weights/best.pt \\",
        "  --model runs/retrain/mealybug_v10/weights/best.pt \\",
        "  --model runs/retrain/mealybug_v11/weights/best.pt \\",
        "  --data mealybug.v10-8th-yolo26n.yolo26/data.yaml --conf 0.12 \\",
        "  --out runs/calibration/model_comparison_eval.json",
        "python scripts/generate_model_comparison.py",
        "```",
    ]
    out_md.write_text("\n".join(lines) + "\n", encoding="utf-8")


def plot_bars(eval_data: dict, out_png: Path) -> None:
    import matplotlib.pyplot as plt
    import numpy as np

    labels = [m[1] for m in MODELS]
    x = np.arange(len(labels))
    width = 0.35

    def series(split: str, field: str) -> list[float]:
        return [eval_data["models"][m[0]]["splits"][split][field] for m in MODELS]

    fig, axes = plt.subplots(1, 2, figsize=(11, 5))
    fig.suptitle(
        f"mealybug v2 / v10 / v11 — conf={eval_data['conf']}, Roboflow v10 data.yaml",
        fontsize=12,
        fontweight="bold",
    )

    for ax, split, title in zip(axes, ("val", "test"), ("Val", "Test")):
        m50 = [v * 100 for v in series(split, "mAP50")]
        p = [v * 100 for v in series(split, "precision")]
        r = [v * 100 for v in series(split, "recall")]
        b1 = ax.bar(x - width / 2, m50, width, label="mAP@0.5", color="#d62728")
        b2 = ax.bar(x + width / 2, p, width, label="Precision", color="#1f77b4", alpha=0.85)
        ax2 = ax.twinx()
        ax2.plot(x, r, "o--", color="#2ca02c", linewidth=2, markersize=8, label="Recall")
        ax.set_ylabel("mAP@0.5 / Precision (%)")
        ax2.set_ylabel("Recall (%)", color="#2ca02c")
        ax2.tick_params(axis="y", labelcolor="#2ca02c")
        ax.set_xticks(x)
        ax.set_xticklabels(labels)
        ax.set_title(title)
        ax.set_ylim(0, max(max(m50), max(p)) * 1.15 + 5)
        ax2.set_ylim(0, max(r) * 1.2 + 5)
        ax.grid(True, axis="y", alpha=0.3)
        for bar in b1:
            h = bar.get_height()
            ax.text(bar.get_x() + bar.get_width() / 2, h + 1, f"{h:.1f}", ha="center", fontsize=8)
        ax.legend(loc="upper left", fontsize=8)
        ax2.legend(loc="upper right", fontsize=8)

    fig.tight_layout()
    out_png.parent.mkdir(parents=True, exist_ok=True)
    fig.savefig(out_png, dpi=200, bbox_inches="tight")
    plt.close(fig)


def _load_map50_series(results_csv: Path) -> tuple[list[int], list[float]]:
    epochs, map50 = [], []
    with results_csv.open(newline="", encoding="utf-8") as f:
        for row in csv.DictReader(f):
            epochs.append(int(row["epoch"]))
            map50.append(float(row["metrics/mAP50(B)"]))
    return epochs, map50


def plot_training_overlay(out_png: Path) -> None:
    import matplotlib.pyplot as plt

    v2 = ROOT / "runs" / "retrain" / "mealybug_v2" / "results.csv"
    v11 = ROOT / "runs" / "retrain" / "mealybug_v11" / "results.csv"
    e2, m2 = _load_map50_series(v2)
    e11, m11 = _load_map50_series(v11)
    m2 = [x * 100 for x in m2]
    m11 = [x * 100 for x in m11]

    fig, ax = plt.subplots(figsize=(9, 5))
    ax.plot(e2, m2, label="v2 val mAP@0.5 (`datasets/` train val)", linewidth=2)
    ax.plot(e11, m11, label="v11 val mAP@0.5 (v10 init, 17k val)", linewidth=2)
    ax.set_xlabel("Epoch")
    ax.set_ylabel("Validation mAP@0.5 (%)")
    ax.set_title("Training curves — different validation splits (not comparable)")
    ax.grid(True, alpha=0.35)
    ax.legend(loc="lower right", fontsize=9)
    fig.text(
        0.5,
        0.02,
        "Use model_comparison_bars.png / fair benchmark table for v2 vs v10 vs v11 claims.",
        ha="center",
        fontsize=9,
        color="#666666",
    )
    fig.tight_layout(rect=[0, 0.04, 1, 1])
    fig.savefig(out_png, dpi=150, bbox_inches="tight")
    plt.close(fig)


def main() -> None:
    p = argparse.ArgumentParser()
    p.add_argument("--eval", type=Path, default=DEFAULT_EVAL)
    args = p.parse_args()

    eval_data = load_eval(args.eval)
    peaks = {
        "mealybug_v2": training_peak(ROOT / "runs" / "retrain" / "mealybug_v2" / "results.csv"),
        "mealybug_v10": training_peak(ROOT / "runs" / "retrain" / "mealybug_v10" / "results.csv"),
        "mealybug_v11": training_peak(ROOT / "runs" / "retrain" / "mealybug_v11" / "results.csv"),
    }

    OUT_DIR.mkdir(parents=True, exist_ok=True)
    csv_path = OUT_DIR / "MODEL_COMPARISON_V2_V10_V11.csv"
    bars_png = OUT_DIR / "model_comparison_bars.png"
    overlay_png = OUT_DIR / "model_comparison_overlay_training.png"

    write_csv(eval_data, csv_path)
    try:
        import matplotlib  # noqa: F401

        plot_bars(eval_data, bars_png)
        plot_training_overlay(overlay_png)
    except ImportError:
        bars_png = Path("(skipped — pip install matplotlib)")
        overlay_png = Path("(skipped)")

    write_markdown(
        eval_data,
        peaks,
        DOC,
        bars_png=bars_png if bars_png.is_file() else OUT_DIR / "model_comparison_bars.png",
        overlay_png=overlay_png if isinstance(overlay_png, Path) and overlay_png.is_file() else None,
    )

    print(f"Wrote {DOC}")
    print(f"Wrote {csv_path}")
    if bars_png.is_file():
        print(f"Wrote {bars_png}")
    if overlay_png.is_file():
        print(f"Wrote {overlay_png}")


if __name__ == "__main__":
    main()
