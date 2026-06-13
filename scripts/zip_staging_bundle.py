#!/usr/bin/env python3
"""Zip a staging folder for Vast upload (avoids Compress-Archive file locks on Windows)."""

from __future__ import annotations

import argparse
import os
import zipfile
from pathlib import Path


def main() -> None:
    p = argparse.ArgumentParser()
    p.add_argument("--staging", type=Path, required=True)
    p.add_argument("--out", type=Path, required=True)
    args = p.parse_args()

    root = args.staging.resolve()
    out = args.out.resolve()
    if not root.is_dir():
        raise SystemExit(f"Missing staging dir: {root}")

    out.parent.mkdir(parents=True, exist_ok=True)
    if out.is_file():
        out.unlink()

    skip_names = {".git", "__pycache__"}
    skip_suffix = (".cache", ".bak")

    count = 0
    with zipfile.ZipFile(out, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=6) as zf:
        for dirpath, dirnames, filenames in os.walk(root):
            dirnames[:] = [d for d in dirnames if d not in skip_names]
            for name in filenames:
                if name.endswith(skip_suffix):
                    continue
                full = Path(dirpath) / name
                arc = full.relative_to(root).as_posix()
                zf.write(full, arc)
                count += 1
                if count % 2000 == 0:
                    print(f"  ... {count} files")

    mb = out.stat().st_size / (1024 * 1024)
    print(f"Wrote {count} files -> {out}")
    print(f"Size: {mb:.1f} MB")


if __name__ == "__main__":
    main()
