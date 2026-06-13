#!/usr/bin/env python3
"""Download images from detections_rows.csv and pack into a zip."""

from __future__ import annotations

import argparse
import csv
import re
import sys
import zipfile
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen

USER_AGENT = "PINYA-PIC-extract/1.0"


def filename_for_url(url: str) -> str:
    url = url.strip().rstrip("/")
    parts = url.split("/")
    if len(parts) >= 2:
        user_id, name = parts[-2], parts[-1]
        safe_user = re.sub(r"[^\w\-]", "_", user_id)
        safe_name = re.sub(r"[^\w.\-]", "_", name)
        return f"{safe_user}_{safe_name}"
    return re.sub(r"[^\w.\-]", "_", parts[-1] if parts else "image.jpg")


def download(url: str, dest: Path) -> tuple[str, bool, str]:
    if dest.exists() and dest.stat().st_size > 0:
        return url, True, "cached"
    try:
        req = Request(url, headers={"User-Agent": USER_AGENT})
        with urlopen(req, timeout=60) as resp:
            data = resp.read()
        if len(data) < 100:
            return url, False, "empty response"
        dest.write_bytes(data)
        return url, True, "ok"
    except (HTTPError, URLError, TimeoutError, OSError) as e:
        return url, False, str(e)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--csv", type=Path, default=Path("results/detections_rows.csv"))
    parser.add_argument("--out-dir", type=Path, default=Path("results/detections_images"))
    parser.add_argument("--zip", type=Path, default=Path("results/detections_images.zip"))
    parser.add_argument("--workers", type=int, default=16)
    args = parser.parse_args()

    if not args.csv.is_file():
        print(f"CSV not found: {args.csv}", file=sys.stderr)
        return 1

    rows = list(csv.DictReader(args.csv.open(encoding="utf-8")))
    url_to_filename: dict[str, str] = {}
    manifest_rows: list[dict[str, str]] = []

    for row in rows:
        url = (row.get("image_url") or "").strip()
        det_id = (row.get("id") or "").strip()
        if not url:
            continue
        if url not in url_to_filename:
            url_to_filename[url] = filename_for_url(url)
        manifest_rows.append(
            {
                "detection_id": det_id,
                "image_url": url,
                "zip_filename": url_to_filename[url],
                "confidence": row.get("confidence", ""),
                "count": row.get("count", ""),
                "has_mealybugs": row.get("has_mealybugs", ""),
                "created_at": row.get("created_at", ""),
            }
        )

    args.out_dir.mkdir(parents=True, exist_ok=True)
    downloads: list[tuple[str, Path]] = []
    for url, fname in url_to_filename.items():
        downloads.append((url, args.out_dir / fname))

    print(f"CSV rows: {len(rows)}")
    print(f"Unique images: {len(downloads)}")
    print(f"Downloading to {args.out_dir} ...")

    ok = fail = 0
    with ThreadPoolExecutor(max_workers=args.workers) as pool:
        futures = {
            pool.submit(download, url, dest): (url, dest)
            for url, dest in downloads
        }
        for i, fut in enumerate(as_completed(futures), 1):
            url, success, msg = fut.result()
            if success:
                ok += 1
            else:
                fail += 1
                print(f"FAIL {url}: {msg}", file=sys.stderr)
            if i % 50 == 0 or i == len(futures):
                print(f"  {i}/{len(futures)} ({ok} ok, {fail} fail)")

    manifest_path = args.out_dir / "manifest.csv"
    with manifest_path.open("w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(
            f,
            fieldnames=[
                "detection_id",
                "image_url",
                "zip_filename",
                "confidence",
                "count",
                "has_mealybugs",
                "created_at",
            ],
        )
        writer.writeheader()
        writer.writerows(manifest_rows)

    print(f"Writing zip: {args.zip}")
    args.zip.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(args.zip, "w", compression=zipfile.ZIP_DEFLATED) as zf:
        zf.write(manifest_path, arcname="manifest.csv")
        for path in sorted(args.out_dir.glob("*")):
            if path.is_file() and path.name != "manifest.csv":
                zf.write(path, arcname=path.name)

    zip_mb = args.zip.stat().st_size / (1024 * 1024)
    print(f"Done: {ok} images, {fail} failed, zip={args.zip} ({zip_mb:.1f} MB)")
    return 0 if fail == 0 else 2


if __name__ == "__main__":
    raise SystemExit(main())
