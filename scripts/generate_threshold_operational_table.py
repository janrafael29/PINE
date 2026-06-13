#!/usr/bin/env python3
"""
Build thesis-style operational threshold table data for PINYA-PIC (mealybug_v11).

Outputs:
  runs/calibration/threshold_operational_table.json  (raw metrics)
  docs/training/THRESHOLD_OPERATIONAL_TABLE.md                (narrative + Table)

Usage:
  python scripts/generate_threshold_operational_table.py
  python scripts/generate_threshold_operational_table.py --quick  # skip 0.5+ conf (use sweep only)
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_MODEL = ROOT / "runs" / "retrain" / "mealybug_v11" / "weights" / "best.pt"
DEFAULT_DATA = ROOT / "mealybug.v10-8th-yolo26n.yolo26" / "data.yaml"
SWEEP = ROOT / "runs" / "calibration" / "threshold_sweep.json"
OUT_JSON = ROOT / "runs" / "calibration" / "threshold_operational_table.json"
OUT_MD = ROOT / "docs" / "THRESHOLD_OPERATIONAL_TABLE.md"

# Tier definitions aligned with friend's 4.2.5 structure, adapted for pest scouting (recall-critical).
TIERS = [
    {
        "id": "accuracy_mode",
        "conf_range": "0.08 (accuracy mode)",
        "conf_eval": 0.08,
        "app_mapping": "Settings → Detection accuracy mode (+ tiled inference)",
    },
    {
        "id": "benchmark_map",
        "conf_range": "0.12",
        "conf_eval": 0.12,
        "app_mapping": "Offline mAP benchmark (evaluate_model_accuracy.py)",
    },
    {
        "id": "shipped_possible",
        "conf_range": "0.22",
        "conf_eval": 0.22,
        "app_mapping": "AppConstants.detectionThreshold (possible tier)",
    },
    {
        "id": "shipped_confirmed",
        "conf_range": "0.28",
        "conf_eval": 0.28,
        "app_mapping": "AppConstants.confirmedDetectionThreshold (count / severity)",
    },
    {
        "id": "yolo_default_band",
        "conf_range": "0.25",
        "conf_eval": 0.25,
        "app_mapping": "Common YOLO pre-label default (auto_label_yolo.py)",
    },
    {
        "id": "moderate_high",
        "conf_range": "0.35",
        "conf_eval": 0.35,
        "app_mapping": "Not deployed — illustrative high-precision band",
    },
    {
        "id": "eval_mid",
        "conf_range": "0.50",
        "conf_eval": 0.50,
        "app_mapping": "Not deployed — mid band (collision papers often cite ~0.50 for mAP)",
    },
    {
        "id": "sms_style_high",
        "conf_range": "0.80 – 0.90",
        "conf_eval": 0.85,
        "app_mapping": "Not deployed — collision-style alert precision (inappropriate for mealybug scouting)",
    },
]


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser()
    p.add_argument("--model", type=Path, default=DEFAULT_MODEL)
    p.add_argument("--data", type=Path, default=DEFAULT_DATA)
    p.add_argument("--quick", action="store_true", help="Use sweep JSON only for 0.08–0.40")
    return p.parse_args()


def metrics_at_conf(model, data: str, conf: float) -> dict:
    m = model.val(
        data=data,
        split="val",
        conf=conf,
        iou=0.45,
        imgsz=640,
        plots=False,
        verbose=False,
    )
    p, r = float(m.box.mp), float(m.box.mr)
    f1 = (2 * p * r / (p + r)) if (p + r) else 0.0
    return {
        "conf": conf,
        "precision": round(p, 4),
        "recall": round(r, 4),
        "f1": round(f1, 4),
        "mAP50": round(float(m.box.map50), 4),
        "precision_pct": round(p * 100, 1),
        "recall_pct": round(r * 100, 1),
        "f1_pct": round(f1 * 100, 1),
    }


def from_sweep(conf: float) -> dict | None:
    if not SWEEP.is_file():
        return None
    data = json.loads(SWEEP.read_text(encoding="utf-8"))
    for row in data["rows"]:
        if abs(row["conf"] - conf) < 1e-6:
            p, r, f1 = row["precision"], row["recall"], row["f1"]
            return {
                "conf": conf,
                "precision": p,
                "recall": r,
                "f1": f1,
                "mAP50": None,
                "precision_pct": round(p * 100, 1),
                "recall_pct": round(r * 100, 1),
                "f1_pct": round(f1 * 100, 1),
                "source": "threshold_sweep.json",
            }
    return None


def behavior_text(pct_p: float, pct_r: float, conf: float) -> str:
    if conf >= 0.75:
        return (
            f"Maximizes precision (~{pct_p:.0f}% P, ~{pct_r:.0f}% R); "
            "most detections suppressed — many real mealybugs never shown."
        )
    if conf >= 0.45:
        return (
            f"High precision (~{pct_p:.0f}% P), low recall (~{pct_r:.0f}% R); "
            "suitable for minimizing false boxes, not for field scouting coverage."
        )
    if conf >= 0.26:
        return (
            f"Elevated precision (~{pct_p:.0f}% P), reduced recall (~{pct_r:.0f}% R); "
            "fits confirmed count / severity tier."
        )
    if conf >= 0.20:
        return (
            f"Near F1-optimal (~{pct_p:.0f}% P, ~{pct_r:.0f}% R, F1≈56% on val); "
            "balanced default for on-screen possible detections."
        )
    return (
        f"Highest recall band (~{pct_p:.0f}% P, ~{pct_r:.0f}% R); "
        "more false boxes; used with tiling in accuracy mode."
    )


def impact_text(tier_id: str, pct_p: float, pct_r: float) -> str:
    impacts = {
        "accuracy_mode": (
            "Field scouts see more candidate boxes on crown photos; "
            "higher workload verifying false positives on white/yellow fruit. "
            "Recommended when infestation is suspected but balanced mode misses clusters."
        ),
        "benchmark_map": (
            "Used only for reporting mAP@0.5 (thesis: 47.4% val / 43.0% test at conf 0.12). "
            "Not the same as deployed UI thresholds."
        ),
        "shipped_possible": (
            "Default scan: possible mealybug overlays without flooding the UI. "
            "Pairs with NMS 0.45 (Dart, on-device)."
        ),
        "shipped_confirmed": (
            "Bug count, severity score, and saved records use this stricter tier — "
            "reduces over-counting vs possible tier while accepting missed low-score pests."
        ),
        "yolo_default_band": (
            "Pre-labeling field batches for CVAT; similar operating point to shipped possible."
        ),
        "moderate_high": (
            "Would under-report infestation extent; not used in PINYA-PIC."
        ),
        "eval_mid": (
            "Collision-detection literature often discusses ~0.50 for mAP; "
            "for dense tiny mealybugs, recall (~{:.0f}%) is too low for grower-facing scouting.".format(pct_r)
        ),
        "sms_style_high": (
            "Appropriate when false alerts are costly (e.g. emergency SMS). "
            "Inappropriate here: mealybugs are small and easily missed — "
            "recall (~{:.0f}%) would leave most pests invisible in the app.".format(pct_r)
        ),
    }
    return impacts.get(tier_id, "See precision/recall trade-off above.")


def main() -> None:
    args = parse_args()
    rows_by_conf: dict[float, dict] = {}

    if args.quick and SWEEP.is_file():
        for t in TIERS:
            hit = from_sweep(t["conf_eval"])
            if hit:
                rows_by_conf[t["conf_eval"]] = hit
    else:
        from ultralytics import YOLO

        model = YOLO(str(args.model))
        confs = sorted({t["conf_eval"] for t in TIERS})
        for conf in confs:
            rows_by_conf[conf] = metrics_at_conf(model, str(args.data), conf)

    table_rows = []
    for tier in TIERS:
        m = rows_by_conf.get(tier["conf_eval"])
        if not m:
            m = from_sweep(tier["conf_eval"]) or {}
        pp, pr = m.get("precision_pct", 0), m.get("recall_pct", 0)
        table_rows.append(
            {
                **tier,
                "metrics": m,
                "system_behavior": behavior_text(pp, pr, tier["conf_eval"]),
                "operational_impact": impact_text(tier["id"], pp, pr),
            }
        )

    payload = {
        "model": str(args.model),
        "data": str(args.data),
        "split": "val",
        "images": 923,
        "instances": 7170,
        "f1_peak_conf": 0.226,
        "note": (
            "Unlike collision SMS systems (0.90+ precision), mealybug scouting prioritizes "
            "recall; PINYA-PIC ships 0.22 / 0.28, not high-alert thresholds."
        ),
        "tiers": table_rows,
        "raw_by_conf": [rows_by_conf[k] for k in sorted(rows_by_conf)],
    }
    OUT_JSON.parent.mkdir(parents=True, exist_ok=True)
    OUT_JSON.write_text(json.dumps(payload, indent=2), encoding="utf-8")

    md = [
        "# PINYA-PIC — comparison of YOLO confidence thresholds (mealybug_v11)",
        "",
        "Data: `mealybug_v11` `best.pt`, Roboflow v10 **val** (923 images, 7,170 instances), ",
        "Ultralytics val @ IoU 0.45, imgsz 640. Regenerate: ",
        "`python scripts/generate_threshold_operational_table.py`.",
        "",
        "## Table X — Comparison of confidence thresholds (operational)",
        "",
        "| Confidence | Val P / R | System behavior | Operational impact (PINYA-PIC) |",
        "|------------|-----------|-----------------|--------------------------------|",
    ]
    for t in table_rows:
        m = t["metrics"]
        pr = f"{m.get('precision_pct', '—')}% / {m.get('recall_pct', '—')}%"
        md.append(
            f"| **{t['conf_range']}** | {pr} | {t['system_behavior']} | {t['operational_impact']} |"
        )
    md.extend(
        [
            "",
            "## Deployed vs collision-style systems",
            "",
            "| Aspect | Collision SMS (friend's Ch. 4.2.5) | PINYA-PIC (mealybugs) |",
            "|--------|----------------------------------|------------------------|",
            "| Primary risk | False alert → wasted dispatch | **Missed pest** → no treatment |",
            "| Typical deploy conf | **0.90+** | **0.22 possible / 0.28 confirmed** |",
            "| Accuracy mode | N/A | **0.08** + tiled inference |",
            "| mAP reporting conf | Often ~0.50 in papers | **0.12** (holdout benchmark) |",
            "",
            "## Source files",
            "",
            "- Raw metrics: `runs/calibration/threshold_operational_table.json`",
            "- Sweep: `runs/calibration/threshold_sweep.json`",
            "- Curves: `runs/calibration/mealybug_v11_ultralytics_curves/Box*.png`",
            "- App: `lib/core/constants.dart`",
        ]
    )
    OUT_MD.write_text("\n".join(md) + "\n", encoding="utf-8")
    print(f"Wrote {OUT_JSON}")
    print(f"Wrote {OUT_MD}")


if __name__ == "__main__":
    main()
