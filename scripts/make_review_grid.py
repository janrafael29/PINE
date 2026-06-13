#!/usr/bin/env python3
"""Build a fast human-review HTML page from the consensus review queue.

Crops each proposal (with context padding), writes crops/ + review.html.
Open review.html in a browser, click the bad ones (toggle red), then
"Download decisions" -> decisions.json. Apply with apply_review_decisions.py.

Usage:
  python scripts/make_review_grid.py \
      --csv runs/consensus/review_queue.csv \
      --images datasets/mealybug_v20/train/images \
      --out runs/consensus/review
"""

from __future__ import annotations

import argparse
import csv
import json
from pathlib import Path

import cv2

ROOT = Path(__file__).resolve().parents[1]

HTML_TEMPLATE = """<!doctype html>
<html><head><meta charset="utf-8"><title>Consensus review</title>
<style>
body{font-family:system-ui;background:#111;color:#eee;margin:16px}
h1{font-size:18px} .meta{color:#9ab;margin-bottom:12px}
.grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(150px,1fr));gap:8px}
.cell{position:relative;border:3px solid #2a6;border-radius:6px;overflow:hidden;cursor:pointer}
.cell.rejected{border-color:#e33;opacity:.55}
.cell img{width:100%;display:block}
.tag{position:absolute;left:4px;top:4px;background:#000a;padding:1px 6px;border-radius:4px;font-size:11px}
.kind-remove{border-color:#e90}
.cell.kind-remove.rejected{border-color:#e33}
button{background:#2a6;color:#fff;border:0;padding:10px 18px;border-radius:6px;font-size:15px;cursor:pointer;margin:12px 4px 24px 0}
.sticky{position:sticky;top:0;background:#111;padding:8px 0;z-index:5}
</style></head><body>
<h1>Consensus proposals — click to REJECT (red = wrong box)</h1>
<div class="meta">Green = accept (default). For <b>add?</b>: reject if the crop is NOT a mealybug.
For <b>remove?</b>: these GT boxes had zero model support — reject if the box IS a real mealybug (i.e. keep it).</div>
<div class="sticky"><button onclick="dl()">Download decisions</button>
<span id="count"></span></div>
<div class="grid">
__CELLS__
</div>
<script>
const cells=[...document.querySelectorAll('.cell')];
function upd(){const r=cells.filter(c=>c.classList.contains('rejected')).length;
document.getElementById('count').textContent=` ${cells.length} crops, ${r} rejected`;}
cells.forEach(c=>c.onclick=()=>{c.classList.toggle('rejected');upd();});
function dl(){
const out=cells.map(c=>({id:c.dataset.id,kind:c.dataset.kind,image:c.dataset.image,
box:c.dataset.box.split(',').map(Number),accepted:!c.classList.contains('rejected')}));
const blob=new Blob([JSON.stringify(out,null,1)],{type:'application/json'});
const a=document.createElement('a');a.href=URL.createObjectURL(blob);
a.download='decisions.json';a.click();}
upd();
</script></body></html>
"""


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--csv", type=Path, required=True)
    ap.add_argument("--images", type=Path, required=True)
    ap.add_argument("--out", type=Path, required=True)
    ap.add_argument("--pad", type=float, default=1.6, help="Context padding factor around box")
    ap.add_argument("--max-crops", type=int, default=4000)
    args = ap.parse_args()

    rows = list(csv.DictReader(args.csv.open(encoding="utf-8")))
    rows = rows[: args.max_crops]
    crops_dir = args.out / "crops"
    crops_dir.mkdir(parents=True, exist_ok=True)

    cells = []
    cache: dict[str, object] = {}
    for i, r in enumerate(rows):
        img_path = args.images / r["image"]
        if r["image"] not in cache:
            cache.clear()
            cache[r["image"]] = cv2.imread(str(img_path))
        img = cache[r["image"]]
        if img is None:
            continue
        h, w = img.shape[:2]
        x1, y1, x2, y2 = (float(r[k]) for k in ("x1", "y1", "x2", "y2"))
        cx, cy = (x1 + x2) / 2, (y1 + y2) / 2
        bw, bh = (x2 - x1) * args.pad, (y2 - y1) * args.pad
        side = max(bw, bh, 64)
        ax1, ay1 = max(0, int(cx - side / 2)), max(0, int(cy - side / 2))
        ax2, ay2 = min(w, int(cx + side / 2)), min(h, int(cy + side / 2))
        crop = img[ay1:ay2, ax1:ax2].copy()
        # draw the proposal box inside the crop
        cv2.rectangle(
            crop,
            (int(x1 - ax1), int(y1 - ay1)),
            (int(x2 - ax1), int(y2 - ay1)),
            (0, 220, 80) if r["kind"] == "add?" else (0, 160, 255),
            2,
        )
        crop_name = f"{i:05d}.jpg"
        cv2.imwrite(str(crops_dir / crop_name), crop, [cv2.IMWRITE_JPEG_QUALITY, 85])
        kind_cls = "kind-remove" if r["kind"] == "remove?" else ""
        cells.append(
            f'<div class="cell {kind_cls}" data-id="{i}" data-kind="{r["kind"]}" '
            f'data-image="{r["image"]}" data-box="{r["x1"]},{r["y1"]},{r["x2"]},{r["y2"]}">'
            f'<img src="crops/{crop_name}" loading="lazy">'
            f'<span class="tag">{r["kind"]} c={r["conf"]} v={r["voters"]}</span></div>'
        )

    html = HTML_TEMPLATE.replace("__CELLS__", "\n".join(cells))
    (args.out / "review.html").write_text(html, encoding="utf-8")
    print(f"{len(cells)} crops -> {args.out / 'review.html'}")


if __name__ == "__main__":
    main()
