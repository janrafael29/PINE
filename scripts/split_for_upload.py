#!/usr/bin/env python3
"""Split a large file into fixed-size parts for parallel/resumable scp upload."""
from __future__ import annotations

import argparse
import hashlib
from pathlib import Path

CHUNK = 1024 * 1024 * 1024  # 1 GiB


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("src", type=Path)
    ap.add_argument("--out-dir", type=Path, default=None)
    ap.add_argument("--part-size", type=int, default=CHUNK)
    args = ap.parse_args()

    src: Path = args.src
    out_dir: Path = args.out_dir or src.parent / (src.stem + "_parts")
    out_dir.mkdir(parents=True, exist_ok=True)

    md5 = hashlib.md5()
    idx = 0
    with src.open("rb") as f:
        while True:
            data = f.read(args.part_size)
            if not data:
                break
            md5.update(data)
            part = out_dir / f"{src.name}.part{idx:03d}"
            if part.exists() and part.stat().st_size == len(data):
                print(f"skip existing {part.name}")
            else:
                part.write_bytes(data)
                print(f"wrote {part.name} ({len(data) / 1e6:.0f} MB)")
            idx += 1

    (out_dir / f"{src.name}.md5").write_text(md5.hexdigest() + "\n", encoding="ascii")
    print(f"done: {idx} parts, md5={md5.hexdigest()}")


if __name__ == "__main__":
    main()
