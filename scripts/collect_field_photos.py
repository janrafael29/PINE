#!/usr/bin/env python3
"""
Collect field-day photos from multiple collector subfolders into one staging tree.

Typical Drive layout (download/sync to PC first):
  field_day/
    era/  ghaz/  jan/  ...   (camera rolls)
    FOR VALIDATION/           (optional — copied aside, not auto-labeled)
    datasets/                 (skipped by default)

Usage:
  python scripts/collect_field_photos.py --source "D:\\field_day"
  python scripts/collect_field_photos.py --source ... --dry-run

Then:
  .\\scripts\\field_day_option_a.ps1 -Source field_staging\\2026-05-19_collected
"""

from __future__ import annotations

import argparse
import json
import shutil
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
IMAGE_EXTS = {".jpg", ".jpeg", ".png", ".webp", ".bmp", ".heic", ".heif"}

DEFAULT_SKIP_DIRS = {
    "datasets",
    "dataset",
    "for validation",
    "1st testing results",
    "1st testing result",
    "_predict",
    "images",
    "labels",
    "__macosx",
    ".git",
}


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(
        description="Flatten team field folders into one staging directory.",
    )
    p.add_argument(
        "--source",
        type=Path,
        required=True,
        help="Parent folder containing era/, ghaz/, jan/, etc.",
    )
    p.add_argument(
        "--output-dir",
        type=Path,
        default=None,
        help="Staging folder (default: field_staging/<date>_collected).",
    )
    p.add_argument(
        "--validation-subdir",
        type=str,
        default="FOR VALIDATION",
        help="Subfolder name to copy aside (not mixed into training staging).",
    )
    p.add_argument(
        "--skip-dir",
        action="append",
        default=[],
        help=f"Extra subfolder names to skip (defaults include {sorted(DEFAULT_SKIP_DIRS)}).",
    )
    p.add_argument(
        "--only-collector",
        action="append",
        default=[],
        help="If set, only these subfolder names (case-insensitive), e.g. era jan.",
    )
    p.add_argument("--dry-run", action="store_true", help="Print plan only.")
    return p.parse_args()


def is_image(path: Path) -> bool:
    return path.is_file() and path.suffix.lower() in IMAGE_EXTS


def safe_dest_name(collector: str, rel: Path) -> str:
    """Unique filename: collector_relPath_with_underscores."""
    parts = [collector.replace(" ", "_")] + [
        p.replace(" ", "_") for p in rel.with_suffix("").parts
    ]
    return "_".join(parts) + rel.suffix.lower()


def main() -> None:
    args = parse_args()
    src = args.source.resolve()
    if not src.is_dir():
        raise SystemExit(f"Source not found: {src}")

    skip = {s.lower() for s in DEFAULT_SKIP_DIRS}
    skip.update(s.lower() for s in args.skip_dir)
    only = {s.lower() for s in args.only_collector} if args.only_collector else None

    stamp = datetime.now(timezone.utc).strftime("%Y-%m-%d")
    out = (
        args.output_dir.resolve()
        if args.output_dir
        else ROOT / "field_staging" / f"{stamp}_collected"
    )
    val_out = out.parent / f"{stamp}_for_validation"

    copied = 0
    skipped_dup = 0
    by_collector: dict[str, int] = {}
    seen_names: set[str] = set()
    manifest_rows: list[dict[str, str]] = []

    val_src = src / args.validation_subdir
    val_copied = 0
    if val_src.is_dir() and not args.dry_run:
        val_out.mkdir(parents=True, exist_ok=True)
        for img in sorted(val_src.rglob("*")):
            if not is_image(img):
                continue
            dest = val_out / img.name
            if dest.exists():
                val_copied += 1
                dest = val_out / f"{img.stem}_{val_copied}{img.suffix.lower()}"
            shutil.copy2(img, dest)

    for sub in sorted(src.iterdir()):
        if not sub.is_dir():
            continue
        name_lower = sub.name.lower()
        if name_lower in skip:
            continue
        if name_lower == args.validation_subdir.lower():
            continue
        if only is not None and name_lower not in only:
            continue

        collector = sub.name
        for img in sorted(sub.rglob("*")):
            if not is_image(img):
                continue
            rel = img.relative_to(sub)
            dest_name = safe_dest_name(collector, rel)
            if dest_name in seen_names:
                skipped_dup += 1
                dest_name = f"{Path(dest_name).stem}_{skipped_dup}{img.suffix.lower()}"
            seen_names.add(dest_name)

            dest_path = out / dest_name
            manifest_rows.append(
                {
                    "collector": collector,
                    "source": str(img),
                    "dest": dest_name,
                }
            )
            if args.dry_run:
                copied += 1
                by_collector[collector] = by_collector.get(collector, 0) + 1
                continue

            out.mkdir(parents=True, exist_ok=True)
            shutil.copy2(img, dest_path)
            copied += 1
            by_collector[collector] = by_collector.get(collector, 0) + 1

    if copied == 0:
        raise SystemExit(
            f"No images found under {src}\n"
            "Check --source path (sync Google Drive to PC first)."
        )

    summary = {
        "created_utc": datetime.now(timezone.utc).isoformat(),
        "source": str(src),
        "staging_dir": str(out),
        "validation_dir": str(val_out) if val_src.is_dir() else None,
        "image_count": copied,
        "by_collector": by_collector,
        "skipped_duplicate_names": skipped_dup,
        "next_steps": [
            f'powershell -File scripts/field_day_option_a.ps1 -Source "{out}" -MarkEmpty',
            "Review labels (CVAT), then merge_field_batch.py",
            "Optional: augment_yolo_subset.py on reviewed batch before merge",
        ],
    }
    if not args.dry_run:
        (out.parent / f"{out.name}_manifest.json").write_text(
            json.dumps({"summary": summary, "files": manifest_rows}, indent=2),
            encoding="utf-8",
        )

    print(json.dumps(summary, indent=2))
    if args.dry_run:
        print("\n(dry-run — no files copied)")


if __name__ == "__main__":
    main()
