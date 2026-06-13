import csv
from pathlib import Path

csv_path = Path("D:/old_PINE/runs/audit_dino/dino_audit_report.csv")

rows = []
with open(csv_path, "r") as f:
    reader = csv.DictReader(f)
    for row in reader:
        row["difference"] = int(row["difference"])
        row["gt_boxes"] = int(row["gt_boxes"])
        row["dino_boxes"] = int(row["dino_boxes"])
        rows.append(row)

total = len(rows)
big_pos = [r for r in rows if r["difference"] > 3]
big_neg = [r for r in rows if r["difference"] < -3]
under_1 = [r for r in rows if r["gt_boxes"] == 1 and r["dino_boxes"] > 3]

print(f"{'='*60}")
print(f"  ANNOTATION QUALITY ANALYSIS (GroundingDINO vs Labels)")
print(f"{'='*60}")
print(f"  Total samples analyzed:        {total}")
print(f"  Under-annotated (diff > +3):   {len(big_pos)} ({len(big_pos)/total*100:.1f}%)")
print(f"  Over-annotated (diff < -3):    {len(big_neg)} ({len(big_neg)/total*100:.1f}%)")
print(f"  GT=1 but DINO finds 4+:        {len(under_1)} ({len(under_1)/total*100:.1f}%)")
print(f"  Likely good (|diff| <= 3):     {total - len(big_pos) - len(big_neg)} ({(total-len(big_pos)-len(big_neg))/total*100:.1f}%)")
print()

print(f"  Top 20 UNDER-annotated (missing labels):")
print(f"  {'-'*55}")
for i, r in enumerate(sorted(big_pos, key=lambda x: x["difference"], reverse=True)[:20]):
    print(f"  {i+1:3d}. {r['filename']:<25s} GT={r['gt_boxes']:2d}  DINO={r['dino_boxes']:2d}  missing={r['difference']:+d}")

print()
print(f"  Top 20 OVER-annotated (possible false labels):")
print(f"  {'-'*55}")
for i, r in enumerate(sorted(big_neg, key=lambda x: x["difference"])[:20]):
    print(f"  {i+1:3d}. {r['filename']:<25s} GT={r['gt_boxes']:2d}  DINO={r['dino_boxes']:2d}  excess={r['difference']:+d}")
