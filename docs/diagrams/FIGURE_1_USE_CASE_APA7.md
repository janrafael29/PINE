# Figure 1 — Use Case Diagram (APA 7)

Use this block in Chapter III (System Design). Replace `1` with your chapter figure number if needed.

---

**Figure 1**  
*Use Case Diagram of the PINYA-PIC Mealybug Collecting Mobile Application With Decision Middleware*

![Figure 1. Use case diagram of PINYA-PIC](use_case_diagram_thesis.png)

*Note.* The diagram shows three actors aligned with the implemented system: **Farmer** (mobile data collector), **DA Staff** (review and expert advice), and **Full Admin** (approves DA staff access). Farmer use cases cover field management, image capture, on-device mealybug detection, and map views. DA Staff use cases cover outbreak visualization and farmer report review; the mobile app uses the same shell as farmers but the center navigation opens the review queue instead of the camera. **Approve Sign-Up Request** corresponds to approving DA/OMAG access requests in the app (`DaAccessRequestsScreen`) and PineSight web console. Dashed *include* links mark mandatory sub-steps (e.g., capture includes on-device detection). Dashed *extend* links mark optional branches (e.g., delete field extends view field). PineSight web administration is documented separately in Figure 1b (mobile vs. web admin). Source: `docs/diagrams/use_case_diagram_thesis.puml`.

---

## How to export the figure image

1. Open `docs/diagrams/use_case_diagram_thesis.puml` in [PlantUML Online](https://www.plantuml.com/plantuml/uml) (recommended for classic oval use cases).
2. Export as **PNG** (300 dpi or higher for print) or **SVG**.
3. Save as `docs/diagrams/use_case_diagram_thesis.png` and update the image path above if your thesis folder differs.

Alternative (Mermaid, less oval-like): paste `docs/diagrams/use_case_diagram_thesis.mmd` into [Mermaid Live](https://mermaid.live).

---

## APA 7 checklist for this figure

| Element | Format |
|--------|--------|
| Figure number | Bold: **Figure 1** |
| Figure title | Italic, title case, on line below number |
| Image | Centered in thesis; no extra border required |
| Note | Italic *Note.* prefix; explain actors, abbreviations, and deviations from a logical overview |
| In-text citation | First mention: `(see Figure 1)` — no period before closing parenthesis when entire citation is parenthetical |

### Sample in-text sentences (APA 7)

> Figure 1 presents the use case model for PINYA-PIC. Farmers interact with field and capture use cases, whereas DA Staff review positive detections and publish expert advice.

> As shown in Figure 1, approving a sign-up request is a Full Admin responsibility and extends review of DA access requests.

---

## Mapping from original thesis diagram to current system

| Original label | Current implementation |
|----------------|------------------------|
| User | Farmer |
| Superuser | DA Staff |
| Admin | Full Admin |
| Remove Field Boundary | **Removed** — use *Edit Field Boundary* |
| Create Feedback (under staff) | **Removed** — farmers *Submit Feedback* separately |
| Approve sign up request | Approve / reject DA staff access (`access_request` table) |

---

*Last updated: 13 June 2026.*
