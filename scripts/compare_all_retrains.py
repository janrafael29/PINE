#!/usr/bin/env python3
"""
Fair benchmark comparison for all runs/retrain/*/weights/best.pt.

Usage:
  python scripts/compare_all_retrains.py
  python scripts/compare_all_retrains.py --skip-eval   # regenerate docs from JSON only
"""

from __future__ import annotations

import argparse
import csv
import json
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BENCH_DATA = ROOT / "mealybug.v10-8th-yolo26n.yolo26" / "data.yaml"
FIELD_DATA = ROOT / "datasets" / "mealybug_va_field" / "data.yaml"
RETRAIN = ROOT / "runs" / "retrain"
OUT_DIR = ROOT / "runs" / "calibration"
EVAL_JSON = OUT_DIR / "all_retrains_eval.json"
DOC = ROOT / "docs" / "MODEL_COMPARISON_ALL_RETRAINS.md"
CSV_OUT = OUT_DIR / "MODEL_COMPARISON_ALL_RETRAINS.csv"
BARS_PNG = OUT_DIR / "all_retrains_comparison_bars.png"

# Display order and descriptions
MODEL_META: list[tuple[str, str, str]] = [
    ("mealybug_v2", "v2", "Legacy baseline (`datasets/`)"),
    ("mealybug_fix500", "fix500", "v2 fine-tune (500-step fix)"),
    ("mealybug_v10", "v10", "Full 17k Roboflow train"),
    ("mealybug_v11", "v11", "Fine-tune v10 + label clean — **shipped in app**"),
    ("mealybug_v12", "v12", "v11 init, 1024 train, v10 data only"),
    ("mealybug_v10a", "v10a", "v10 + 877 field images (combined)"),
    ("mealybug_va", "Va", "Field-only ~877 images"),
]


def discover_weights() -> list[Path]:
    found: list[Path] = []
    for key, _, _ in MODEL_META:
        p = RETRAIN / key / "weights" / "best.pt"
        if p.is_file():
            found.append(p)
    # any other runs with best.pt
    known = {m[0] for m in MODEL_META}
    for d in sorted(RETRAIN.iterdir()):
        if not d.is_dir() or d.name in known:
            continue
        p = d / "weights" / "best.pt"
        if p.is_file():
            found.append(p)
    return found


def run_eval(model_path: Path, data: Path, split: str, conf: float, iou: float, imgsz: int) -> dict:
    from ultralytics import YOLO

    metrics = YOLO(str(model_path)).val(
        data=str(data),
        split=split,
        conf=conf,
        iou=iou,
        imgsz=imgsz,
        plots=False,
        verbose=False,
    )
    p, r = float(metrics.box.mp), float(metrics.box.mr)
    map50, map5095 = float(metrics.box.map50), float(metrics.box.map)
    f1 = (2 * p * r / (p + r)) if (p + r) else 0.0
    return {
        "precision_pct": round(p * 100, 1),
        "recall_pct": round(r * 100, 1),
        "f1_pct": round(f1 * 100, 1),
        "mAP50_pct": round(map50 * 100, 1),
        "mAP50_95_pct": round(map5095 * 100, 1),
        "precision": round(p, 4),
        "recall": round(r, 4),
        "f1": round(f1, 4),
        "mAP50": round(map50, 4),
        "mAP50_95": round(map5095, 4),
    }


def _load_cached_benchmark(name: str, conf: float, iou: float) -> dict | None:
    """Reuse prior eval JSON when settings match."""
    caches = [
        OUT_DIR / "model_comparison_eval.json",
        OUT_DIR / "mealybug_v12_eval.json",
        OUT_DIR / "all_retrains_eval.json",
    ]
    for path in caches:
        if not path.is_file():
            continue
        data = json.loads(path.read_text(encoding="utf-8"))
        if data.get("conf") != conf or data.get("iou") != iou:
            continue
        m = data.get("models", {}).get(name)
        if not m:
            continue
        splits = m.get("splits") or m.get("benchmark")
        if splits and "test" in splits:
            return {"benchmark": splits, "field_test": m.get("field_test")}
    return None


def _split_row(row: dict) -> dict:
    return {
        "precision_pct": row["precision_pct"],
        "recall_pct": row["recall_pct"],
        "f1_pct": round(row.get("f1", 0) * 100, 1) if row.get("f1", 0) <= 1 else row.get("f1_pct"),
        "mAP50_pct": row["mAP50_pct"],
        "mAP50_95_pct": row["mAP50_95_pct"],
        "precision": row.get("precision", row["precision_pct"] / 100),
        "recall": row.get("recall", row["recall_pct"] / 100),
        "f1": row.get("f1", row.get("f1_pct", 0) / 100 if "f1_pct" in row else 0),
        "mAP50": row.get("mAP50", row["mAP50_pct"] / 100),
        "mAP50_95": row.get("mAP50_95", row["mAP50_95_pct"] / 100),
    }


def build_eval_report(conf: float, iou: float, imgsz: int) -> dict:
    report: dict = {
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "benchmark_data": str(BENCH_DATA.resolve()),
        "field_data": str(FIELD_DATA.resolve()) if FIELD_DATA.is_file() else None,
        "conf": conf,
        "iou": iou,
        "imgsz": imgsz,
        "models": {},
    }

    for w in discover_weights():
        name = w.parent.parent.name
        print(f"\n=== {name} ===")
        cached = _load_cached_benchmark(name, conf, iou)
        entry: dict = {
            "weights": str(w.resolve()),
            "benchmark": {},
            "field_test": None,
        }

        if cached:
            print("  (cached benchmark)")
            entry["benchmark"] = {k: _split_row(v) for k, v in cached["benchmark"].items()}
            entry["field_test"] = (
                _split_row(cached["field_test"]) if cached.get("field_test") else None
            )
        else:
            for split in ("val", "test"):
                print(f"  benchmark {split}...")
                entry["benchmark"][split] = run_eval(w, BENCH_DATA, split, conf, iou, imgsz)
                s = entry["benchmark"][split]
                print(f"    mAP@0.5={s['mAP50_pct']}%  P={s['precision_pct']}%  R={s['recall_pct']}%")

            if name == "mealybug_va" and FIELD_DATA.is_file():
                print("  field test (133 images)...")
                entry["field_test"] = run_eval(w, FIELD_DATA, "test", conf, iou, imgsz)
                s = entry["field_test"]
                print(f"    mAP@0.5={s['mAP50_pct']}%  P={s['precision_pct']}%  R={s['recall_pct']}%")

        for split in ("val", "test"):
            if split in entry["benchmark"]:
                s = entry["benchmark"][split]
                print(f"  {split}: mAP@0.5={s['mAP50_pct']}%")

        report["models"][name] = entry

    return report


def label_for_key(key: str) -> tuple[str, str]:
    for k, lab, desc in MODEL_META:
        if k == key:
            return lab, desc
    return key.replace("mealybug_", ""), key


def training_peak(key: str) -> dict | None:
    csv_path = RETRAIN / key / "results.csv"
    if not csv_path.is_file():
        return None
    rows = list(csv.DictReader(csv_path.open(newline="", encoding="utf-8")))
    if not rows:
        return None
    best = max(rows, key=lambda r: float(r["metrics/mAP50(B)"]))
    return {
        "epochs": len(rows),
        "best_epoch": int(best["epoch"]),
        "best_mAP50_pct": round(float(best["metrics/mAP50(B)"]) * 100, 1),
    }


def write_csv(report: dict) -> None:
    rows = []
    for key, _, _ in MODEL_META:
        if key not in report["models"]:
            continue
        m = report["models"][key]
        for split in ("val", "test"):
            if split not in m.get("benchmark", {}):
                continue
            s = m["benchmark"][split]
            rows.append(
                {
                    "model_key": key,
                    "label": label_for_key(key)[0],
                    "dataset": "17k_benchmark",
                    "split": split,
                    "mAP50_pct": s["mAP50_pct"],
                    "mAP50_95_pct": s["mAP50_95_pct"],
                    "precision_pct": s["precision_pct"],
                    "recall_pct": s["recall_pct"],
                    "f1_pct": s["f1_pct"],
                }
            )
        if m.get("field_test"):
            s = m["field_test"]
            rows.append(
                {
                    "model_key": key,
                    "label": label_for_key(key)[0],
                    "dataset": "field_only",
                    "split": "test",
                    "mAP50_pct": s["mAP50_pct"],
                    "mAP50_95_pct": s["mAP50_95_pct"],
                    "precision_pct": s["precision_pct"],
                    "recall_pct": s["recall_pct"],
                    "f1_pct": s["f1_pct"],
                }
            )
    if not rows:
        return
    with CSV_OUT.open("w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=list(rows[0].keys()))
        w.writeheader()
        w.writerows(rows)


def write_markdown(report: dict) -> None:
    conf, iou, imgsz = report["conf"], report["iou"], report["imgsz"]
    lines = [
        "# All retrain comparison (fair 17k benchmark)",
        "",
        f"Generated: {report['generated_at']}",
        "",
        "## Settings",
        "",
        f"- **Benchmark:** `{report['benchmark_data']}` (923 val / 462 test)",
        f"- **conf={conf}, IoU={iou}, imgsz={imgsz}**",
        f"- **JSON:** `runs/calibration/all_retrains_eval.json`",
        "",
        "### Test split (primary — thesis / app)",
        "",
        "| Model | Description | P | R | F1 | mAP@0.5 | mAP@0.5:0.95 |",
        "|-------|-------------|--:|--:|---:|--------:|-------------:|",
    ]

    best_map = -1.0
    best_name = ""
    for key, lab, desc in MODEL_META:
        if key not in report["models"]:
            continue
        s = report["models"][key]["benchmark"].get("test")
        if not s:
            continue
        ship = " ✓ app" if key == "mealybug_v11" else ""
        lines.append(
            f"| **{lab}**{ship} | {desc} | {s['precision_pct']}% | {s['recall_pct']}% | "
            f"{s['f1_pct']}% | **{s['mAP50_pct']}%** | {s['mAP50_95_pct']}% |"
        )
        if s["mAP50_pct"] > best_map:
            best_map = s["mAP50_pct"]
            best_name = lab

    lines += [
        "",
        f"**Best on benchmark test:** **{best_name}** ({best_map}% mAP@0.5)",
        "",
        "### Val split",
        "",
        "| Model | P | R | F1 | mAP@0.5 | mAP@0.5:0.95 |",
        "|-------|--:|--:|---:|--------:|-------------:|",
    ]
    for key, lab, _ in MODEL_META:
        if key not in report["models"]:
            continue
        s = report["models"][key]["benchmark"].get("val")
        if not s:
            continue
        lines.append(
            f"| **{lab}** | {s['precision_pct']}% | {s['recall_pct']}% | {s['f1_pct']}% | "
            f"{s['mAP50_pct']}% | {s['mAP50_95_pct']}% |"
        )

    if any(report["models"].get(k, {}).get("field_test") for k, _, _ in MODEL_META):
        lines += [
            "",
            "### Field-only test (133 images — Va only)",
            "",
            "| Model | mAP@0.5 | P | R |",
            "|-------|--------:|--:|--:|",
        ]
        for key, lab, _ in MODEL_META:
            ft = report["models"].get(key, {}).get("field_test")
            if ft:
                lines.append(
                    f"| **{lab}** | {ft['mAP50_pct']}% | {ft['precision_pct']}% | {ft['recall_pct']}% |"
                )

    lines += [
        "",
        "## Training peaks (during train — not fair benchmark)",
        "",
        "| Model | Epochs | Best train-val mAP@0.5 |",
        "|-------|-------:|---------------------:|",
    ]
    for key, lab, _ in MODEL_META:
        pk = training_peak(key)
        if pk:
            lines.append(f"| {lab} | {pk['epochs']} | {pk['best_mAP50_pct']}% (ep {pk['best_epoch']}) |")
        elif key in report["models"]:
            lines.append(f"| {lab} | — | (no results.csv) |")

    lines += [
        "",
        "## Figure",
        "",
        f"![Test mAP comparison]({BARS_PNG.relative_to(ROOT).as_posix()})",
        "",
        "## Regenerate",
        "",
        "```bash",
        "python scripts/compare_all_retrains.py",
        "```",
    ]
    DOC.write_text("\n".join(lines) + "\n", encoding="utf-8")


def plot_bars(report: dict) -> None:
    import matplotlib.pyplot as plt
    import numpy as np

    keys, labels, m50 = [], [], []
    for key, lab, _ in MODEL_META:
        if key not in report["models"]:
            continue
        s = report["models"][key]["benchmark"].get("test")
        if not s:
            continue
        keys.append(key)
        labels.append(lab)
        m50.append(s["mAP50_pct"])

    if not labels:
        return

    x = np.arange(len(labels))
    colors = ["#9467bd" if k == "mealybug_v11" else "#1f77b4" for k in keys]
    fig, ax = plt.subplots(figsize=(10, 5))
    bars = ax.bar(x, m50, color=colors, edgecolor="black", linewidth=0.5)
    ax.set_xticks(x)
    ax.set_xticklabels(labels, rotation=25, ha="right")
    ax.set_ylabel("Test mAP@0.5 (%)")
    ax.set_title(
        f"All retrains — 17k benchmark test (conf={report['conf']}, IoU={report['iou']})",
        fontweight="bold",
    )
    ax.set_ylim(0, max(m50) * 1.15 + 5)
    ax.grid(True, axis="y", alpha=0.3)
    for bar, v in zip(bars, m50):
        ax.text(bar.get_x() + bar.get_width() / 2, bar.get_height() + 0.5, f"{v:.1f}%", ha="center", fontsize=9)
    fig.tight_layout()
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    fig.savefig(BARS_PNG, dpi=200, bbox_inches="tight")
    plt.close(fig)


def main() -> None:
    p = argparse.ArgumentParser()
    p.add_argument("--skip-eval", action="store_true")
    p.add_argument("--conf", type=float, default=0.12)
    p.add_argument("--iou", type=float, default=0.45)
    p.add_argument("--imgsz", type=int, default=640)
    args = p.parse_args()

    if not BENCH_DATA.is_file():
        raise SystemExit(f"Missing {BENCH_DATA}")

    if args.skip_eval and EVAL_JSON.is_file():
        report = json.loads(EVAL_JSON.read_text(encoding="utf-8"))
    else:
        report = build_eval_report(args.conf, args.iou, args.imgsz)
        OUT_DIR.mkdir(parents=True, exist_ok=True)
        EVAL_JSON.write_text(json.dumps(report, indent=2), encoding="utf-8")
        print(f"\nWrote {EVAL_JSON}")

    write_csv(report)
    try:
        plot_bars(report)
    except ImportError:
        print("matplotlib not installed — skip chart")

    write_markdown(report)
    print(f"Wrote {DOC}")
    print(f"Wrote {CSV_OUT}")
    if BARS_PNG.is_file():
        print(f"Wrote {BARS_PNG}")


if __name__ == "__main__":
    main()
