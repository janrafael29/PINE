#!/usr/bin/env python3
"""Combine docs/diagrams/*.mmd into PINYA_PIC_ALL_DIAGRAMS.md"""
from pathlib import Path

DIAG = Path(__file__).resolve().parents[1] / "docs" / "diagrams"
OUT = DIAG / "PINYA_PIC_ALL_DIAGRAMS.md"

HEADER = """# PINYA-PIC — Complete Diagram Pack (single shareable file)

**Date:** 13 June 2026  
**Project:** PINYA-PIC / PineSight — mealybug detection collector (mobile + admin web)  
**Format:** Mermaid blocks — paste into [Mermaid Live](https://mermaid.live), VS Code preview, GitHub, or export PNG for thesis.

---

## How to use this file

1. Share this **one `.md` file** with advisers or panel members.
2. Each section has a **Mermaid code block** — copy into Mermaid Live to export PNG/SVG.
3. For classic **UML use case ovals**, use [`use_case_diagram.puml`](use_case_diagram.puml) with PlantUML.
4. **B-series** IDs (B1–B12) map to Chapter III figure labels in [`PINYA_PIC_thesis_flowcharts.md`](PINYA_PIC_thesis_flowcharts.md).

---

## Chapter III disclaimer (paste verbatim)

> The diagrams presented are logical representations of the system workflows and architecture. Certain optional branches, asynchronous operations, and error-handling paths are described in detail in Sections 3.3–3.4 and are not fully expanded in the diagrams to maintain clarity.

---

## Table of contents

| # | Section |
|---|---------|
| B0 | [Use case diagram](#b0--use-case-diagram-june-2026) |
| B0t | [Thesis-style use case (APA 7)](#figure-1--use-case-diagram-apa-7) |
| B1 | [Diagnose tab data flow](#b1--diagnose-tab-data-loading) |
| B2 | [Seven-day chart pipeline](#b2--seven-day-chart-pipeline) |
| B3 | [App launch and auth](#b3--application-launch-and-auth) |
| B4 | [Capture and detection](#b4--image-capture-and-detection) |
| B5 | [Cloud sync queue](#b5--cloud-synchronization) |
| B6 | [Domain model / ERD](#b6--domain-model-erd) |
| B7 | [Component architecture](#b7--component-architecture) |
| B8 | [Three-layer architecture](#b8--three-layer-architecture) |
| B9 | [Field management](#b9--field-management) |
| B10 | [Feedback](#b10--feedback) |
| B11 | [Profile and preferences](#b11--profile) |
| B12 | [Deployment topology](#b12--deployment) |
| B13 | [Staff review and expert advice](#b13--staff-review-loop) |

---

"""

B1 = """## B1 — Diagnose tab data loading

```mermaid
flowchart TD
  A[MainDashboardScreen _DiagnoseTab] --> B{currentUserJwtStaff?}
  B -->|Yes DA or Admin| C[StaffAnalyticsTab]
  C --> C1[detectionsRealtimeStream org-wide]
  C1 --> C2[StaffAnalyticsCalculator.fromDetections]
  C2 --> C3[StaffAnalyticsPanel donut bar trend charts]
  B -->|No Farmer| D[watch capturedPhotosRevision]
  D --> E[FutureBuilder getCapturedPhotos SQLite]
  D --> F[StreamBuilder detectionsRealtimeStream]
  E --> G[DashboardStatsCalculator.fromCapturedPhotos]
  F --> H[fromDetectionMaps if stream has data]
  G --> I[farmerWeeklyStats prefer local if has data]
  H --> I
  I --> J[Stat cards + monotonic pest chart]
```

"""

B2 = """## B2 — Seven-day chart pipeline

```mermaid
flowchart TD
  A[DashboardStats.dailyCounts last 7 days] --> B[Group by calendar day]
  B --> C[_RealLineChartPainter compute maxY]
  C --> D[Draw grid Y labels 0 at bottom]
  D --> E[buildMonotonicSmoothLinePath]
  E --> F[buildMonotonicSmoothAreaFill]
  F --> G[X axis EN or FIL day labels]
  G --> H[Peak marker dot + value badge]
  H --> I[Render in Diagnose tab PineCard]
```

"""

B8 = """## B8 — Three-layer architecture

```mermaid
flowchart TD
  UI[UI Flutter + PineSight Admin] --> SV[Service layer]
  SV --> LS[Local SQLite + images]
  SV --> CL[Supabase Auth Postgres Storage Realtime]
  SV --> IE[TFLite best.tflite 1280px on-device]
  LS --> OUT[Results to UI]
  CL --> OUT
  IE --> OUT
```

"""

FOOTER = """
---

## Positive vs negative routing (panel rule)

| Detection result | count / has_mealybugs | Map & heatmap | Staff pending queue |
|------------------|----------------------|---------------|---------------------|
| **Positive** | count > 0 | Yes | Yes until advice saved |
| **Negative** | count = 0 | No | No |

---

*Last updated 13 June 2026. Source: `docs/diagrams/*.mmd`. Regenerate: `python scripts/combine_diagrams_md.py`*
"""

SECTIONS = [
    ("B0 — Use case diagram (June 2026)", "use_case_diagram.mmd"),
    ("B0b — Mobile admin vs web admin", "use_case_admin_mobile_web.mmd"),
    ("B3 — Application launch and auth", "auth_flow.mmd"),
    ("B4 — Image capture and detection", "detection_flow.mmd"),
    ("B5 — Cloud synchronization", "sync_flow.mmd"),
    ("B6 — Domain model (ERD)", "erd.mmd"),
    ("B7 — Component architecture", "component_architecture.mmd"),
    ("B9 — Field management", "field_management_flow.mmd"),
    ("B10 — Feedback", "feedback_flow.mmd"),
    ("B11 — Profile", "profile_flow.mmd"),
    ("B12 — Deployment", "deployment.mmd"),
    ("B13 — Staff review loop", "staff_review_flow.mmd"),
    ("Dashboard diagnose detail", "dashboard_flow.mmd"),
    ("Chart rendering detail", "chart_flow.mmd"),
    ("Service dependencies", "service_dependency.mmd"),
    ("Sequence: detection", "sequence_detection.mmd"),
    ("Sequence: sync", "sequence_sync.mmd"),
]


def section(title: str, filename: str) -> str:
    path = DIAG / filename
    if not path.exists():
        return f"\n## {title}\n\n*Missing source: {filename}*\n\n"
    body = path.read_text(encoding="utf-8").strip()
    return f"\n## {title}\n\n```mermaid\n{body}\n```\n\n"


def main() -> None:
    out = HEADER
    out += section("B0 — Use case diagram (June 2026)", "use_case_diagram.mmd")
    out += section("B0b — Mobile admin vs web admin", "use_case_admin_mobile_web.mmd")
    thesis_mmd = (DIAG / "use_case_diagram_thesis.mmd").read_text(encoding="utf-8").strip()
    out += (
        "## Figure 1 — Use case diagram (APA 7)\n\n"
        "**Figure 1**  \n"
        "*Use Case Diagram of the PINYA-PIC Mealybug Collecting Mobile Application With Decision Middleware*\n\n"
        "> Classic UML ovals: [`use_case_diagram_thesis.puml`](use_case_diagram_thesis.puml) + full APA block: [`FIGURE_1_USE_CASE_APA7.md`](FIGURE_1_USE_CASE_APA7.md)\n\n"
        f"```mermaid\n{thesis_mmd}\n```\n\n"
        "*Note.* Farmer (left), DA Staff (right), and Full Admin (bottom) match the thesis layout. "
        "Approve Sign-Up Request = DA staff access approval. "
        "Include/extend links reflect the June 2026 codebase.\n\n"
    )
    out += B1 + B2
    for title, fn in SECTIONS[2:]:
        out += section(title, fn)
        if fn == "component_architecture.mmd":
            out += B8
    out += FOOTER
    OUT.write_text(out, encoding="utf-8")
    print(f"Wrote {OUT} ({OUT.stat().st_size} bytes)")


if __name__ == "__main__":
    main()
