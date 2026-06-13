#!/usr/bin/env python3
"""
Train / export YOLO26n for PINYA-PIC (Vast GPU or local).

Examples:
  python scripts/retrain_yolo.py --epochs 100 --batch 16
  python scripts/retrain_yolo.py --weights runs/retrain/mealybug_v2/weights/best.pt --name mealybug_fix500
  python scripts/retrain_yolo.py --preset v12-highres --dry-run
  python scripts/retrain_yolo.py --export-only runs/retrain/mealybug_v11/weights/best.pt --export-imgsz 640

Ship to app (after export on PC):
  copy runs\\retrain\\<name>\\weights\\best_float32.tflite assets\\model\\best.tflite
"""

from __future__ import annotations

import argparse
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_DATA = ROOT / "datasets" / "data.yaml"
DEFAULT_WEIGHTS = ROOT / "runs" / "retrain" / "mealybug_v2" / "weights" / "best.pt"
PROJECT = ROOT / "runs" / "retrain"
PRESET_V12 = ROOT / "configs" / "train_v12_highres.yaml"
PRESET_V10A = ROOT / "configs" / "train_v10a.yaml"
PRESET_VA = ROOT / "configs" / "train_va.yaml"
PRESET_V13AFIX = ROOT / "configs" / "train_v13afix.yaml"


def _load_yaml_preset(path: Path) -> dict[str, Any]:
    try:
        import yaml
    except ImportError:
        raise SystemExit("pip install pyyaml for --preset (or pass flags manually)")
    data = yaml.safe_load(path.read_text(encoding="utf-8"))
    if not isinstance(data, dict):
        raise SystemExit(f"Invalid preset yaml: {path}")
    return data


def _apply_preset_defaults(args: argparse.Namespace, preset: dict[str, Any]) -> None:
    """Fill unset CLI fields from yaml (CLI wins when explicitly provided)."""
    mapping = {
        "name": "name",
        "data": "data",
        "weights": "weights",
        "epochs": "epochs",
        "imgsz": "imgsz",
        "batch": "batch",
        "device": "device",
        "workers": "workers",
        "patience": "patience",
        "optimizer": "optimizer",
        "lr0": "lr0",
        "lrf": "lrf",
        "cos_lr": "cos_lr",
        "warmup_epochs": "warmup_epochs",
        "weight_decay": "weight_decay",
        "dropout": "dropout",
        "box": "box",
        "cls_gain": "cls_gain",
        "dfl": "dfl",
        "close_mosaic": "close_mosaic",
        "conf": "conf",
        "iou": "iou",
        "export_imgsz": "export_imgsz",
        "no_export": "no_export",
    }
    for yaml_key, attr in mapping.items():
        if yaml_key not in preset:
            continue
        val = preset[yaml_key]
        if attr in ("data", "weights") and isinstance(val, str):
            val = ROOT / val
        current = getattr(args, attr, None)
        # argparse defaults: only override when still at parser default for key fields
        if attr == "name" and args._explicit_name:
            continue
        if attr == "data" and args._explicit_data:
            continue
        if attr == "weights" and args._explicit_weights:
            continue
        setattr(args, attr, val)


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(description="Train or export YOLO26n mealybug model.")
    p.add_argument(
        "--preset",
        choices=["v12-highres", "v10a", "va", "v13afix"],
        default=None,
        help="Presets: v12-highres, v10a, va, v13afix (v10+field+fix500, from v12)",
    )
    p.add_argument("--data", type=Path, default=DEFAULT_DATA)
    p.add_argument(
        "--weights",
        type=Path,
        default=DEFAULT_WEIGHTS,
        help="yolo26n.pt or existing best.pt for fine-tune",
    )
    p.add_argument("--epochs", type=int, default=100)
    p.add_argument("--batch", type=int, default=16, help="Lower if OOM (1024: try 8–16 on 24GB)")
    p.add_argument("--imgsz", type=int, default=640)
    p.add_argument("--patience", type=int, default=20, help="0 = disable early stopping")
    p.add_argument("--device", default="0", help="0, cpu, or 0,1")
    p.add_argument("--workers", type=int, default=8)
    p.add_argument("--name", type=str, default="mealybug_fix500")
    p.add_argument("--project", type=Path, default=PROJECT)
    p.add_argument("--resume", action="store_true", help="Resume last.pt in run folder")
    p.add_argument("--optimizer", type=str, default=None, help="e.g. AdamW, auto, SGD")
    p.add_argument("--lr0", type=float, default=None)
    p.add_argument("--lrf", type=float, default=None)
    p.add_argument("--cos-lr", action="store_true", help="Cosine LR schedule")
    p.add_argument("--warmup-epochs", type=float, default=None)
    p.add_argument("--weight-decay", type=float, default=None)
    p.add_argument("--dropout", type=float, default=None)
    p.add_argument("--box", type=float, default=None, help="Box loss gain")
    p.add_argument("--cls", type=float, default=None, dest="cls_gain", help="Cls loss gain")
    p.add_argument("--dfl", type=float, default=None, help="DFL loss gain")
    p.add_argument("--close-mosaic", type=int, default=None, help="Disable mosaic last N epochs")
    p.add_argument("--conf", type=float, default=None, help="Val conf during training")
    p.add_argument("--iou", type=float, default=None, help="Val IoU / NMS during training")
    p.add_argument(
        "--export-imgsz",
        type=int,
        default=None,
        help="TFLite export size (default: same as --imgsz; use 640 for mobile after 1024 train)",
    )
    p.add_argument(
        "--export-only",
        type=Path,
        default=None,
        metavar="BEST_PT",
        help="Export TFLite from existing weights (no training)",
    )
    p.add_argument("--no-export", action="store_true", help="Train only; skip TFLite export")
    p.add_argument("--dry-run", action="store_true", help="Print config and exit")
    args = p.parse_args()
    args._explicit_name = "--name" in __import__("sys").argv
    args._explicit_data = "--data" in __import__("sys").argv
    args._explicit_weights = "--weights" in __import__("sys").argv
    if args.preset == "v12-highres":
        if not PRESET_V12.is_file():
            raise SystemExit(f"Missing preset: {PRESET_V12}")
        _apply_preset_defaults(args, _load_yaml_preset(PRESET_V12))
    elif args.preset == "v10a":
        if not PRESET_V10A.is_file():
            raise SystemExit(f"Missing preset: {PRESET_V10A}")
        _apply_preset_defaults(args, _load_yaml_preset(PRESET_V10A))
    elif args.preset == "va":
        if not PRESET_VA.is_file():
            raise SystemExit(f"Missing preset: {PRESET_VA}")
        _apply_preset_defaults(args, _load_yaml_preset(PRESET_VA))
    elif args.preset == "v13afix":
        if not PRESET_V13AFIX.is_file():
            raise SystemExit(f"Missing preset: {PRESET_V13AFIX}")
        _apply_preset_defaults(args, _load_yaml_preset(PRESET_V13AFIX))
    if args.export_imgsz is None:
        args.export_imgsz = args.imgsz
    return args


def export_tflite(model_path: Path, imgsz: int = 640) -> Path:
    from ultralytics import YOLO

    model = YOLO(str(model_path))
    out_dir = model_path.parent
    export_kw: dict = {
        "format": "tflite",
        "imgsz": imgsz,
        "half": False,
        "nms": False,
        "batch": 1,
    }
    try:
        model.export(**export_kw)
    except Exception as first_err:
        print(f"TFLite export failed ({first_err}); retrying after onnx2tf pin...")
        import subprocess
        import sys

        subprocess.check_call(
            [sys.executable, "-m", "pip", "install", "-q", "onnx2tf==1.26.3"],
        )
        model.export(**export_kw)
    candidates = [
        out_dir / "best_float32.tflite",
        out_dir / "best.tflite",
        out_dir / f"{model_path.stem}_float32.tflite",
        out_dir / f"{model_path.stem}.tflite",
        out_dir / f"{model_path.stem}_saved_model" / "best_float32.tflite",
        out_dir / f"{model_path.stem}_saved_model" / "best.tflite",
    ]
    for c in candidates:
        if c.is_file():
            return c
    raise SystemExit(f"TFLite not found under {out_dir} after export")


def build_train_kwargs(args: argparse.Namespace) -> dict[str, Any]:
    train_kw: dict[str, Any] = {
        "data": str(args.data.resolve()),
        "epochs": args.epochs,
        "imgsz": args.imgsz,
        "batch": args.batch,
        "patience": args.patience,
        "device": args.device,
        "workers": args.workers,
        "project": str(args.project),
        "name": args.name,
        "exist_ok": True,
        "pretrained": True,
        "verbose": True,
        "plots": True,
        "amp": True,
    }
    optional = {
        "optimizer": args.optimizer,
        "lr0": args.lr0,
        "lrf": args.lrf,
        "cos_lr": args.cos_lr if args.cos_lr else None,
        "warmup_epochs": args.warmup_epochs,
        "weight_decay": args.weight_decay,
        "dropout": args.dropout,
        "box": args.box,
        "cls": args.cls_gain,
        "dfl": args.dfl,
        "close_mosaic": args.close_mosaic,
        "conf": args.conf,
        "iou": args.iou,
    }
    for key, val in optional.items():
        if val is not None:
            train_kw[key] = val
    return train_kw


def main() -> None:
    args = parse_args()
    data = args.data.resolve()
    if not data.is_file():
        raise SystemExit(f"Missing data yaml: {data}")

    if args.export_only:
        pt = args.export_only.resolve()
        if not pt.is_file():
            raise SystemExit(f"Not found: {pt}")
        export_sz = args.export_imgsz or args.imgsz
        tflite = export_tflite(pt, export_sz)
        print(f"Exported: {tflite}")
        print("Copy to assets/model/best.tflite on your PC.")
        return

    train_kw = build_train_kwargs(args)
    if args.dry_run:
        print("Dry run — training config:")
        for k, v in sorted(train_kw.items()):
            print(f"  {k}={v}")
        print(f"  weights={args.weights}")
        print(f"  export_imgsz={args.export_imgsz}")
        print(f"  no_export={args.no_export}")
        return

    try:
        from ultralytics import YOLO
    except ImportError:
        raise SystemExit("pip install -r scripts/requirements-train.txt")

    weights = args.weights
    if not weights.is_file():
        print(f"Weights not found at {weights}, using yolo26n.pt")
        weights = Path("yolo26n.pt")

    model = YOLO(str(weights))
    if args.resume:
        last = args.project / args.name / "weights" / "last.pt"
        if last.is_file():
            train_kw["resume"] = str(last)
        else:
            print(f"No last.pt at {last}; training fresh")

    stamp = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    print(f"Training start {stamp}")
    print(f"  weights={weights}")
    print(f"  run={args.project / args.name}")
    for k, v in sorted(train_kw.items()):
        print(f"  {k}={v}")

    model.train(**train_kw)

    best = args.project / args.name / "weights" / "best.pt"
    if not best.is_file():
        raise SystemExit(f"Training finished but missing {best}")

    print(f"Best weights: {best}")

    if not args.no_export:
        try:
            tflite = export_tflite(best, args.export_imgsz)
            print(f"TFLite: {tflite}")
        except Exception as e:
            print(f"TFLite export failed on this machine ({e}).")
            print(f"Download {best} and run on PC:")
            print(
                f"  python scripts/retrain_yolo.py --export-only {best} "
                f"--export-imgsz {args.export_imgsz}"
            )


if __name__ == "__main__":
    main()
