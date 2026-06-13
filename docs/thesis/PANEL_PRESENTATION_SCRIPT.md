# PINYA-PIC — Word-for-Word Panel Script (14 Slides)

**Slides file:** `d:\old_PINE\docs\thesis\panel_video_slides.html` (16 slides)  
**Graphs:** `d:\old_PINE\docs\thesis\assets\v16_selffix\` (generated from `runs/retrain/mealybug_v16_selffix/results.csv`)  
**Controls:** F11 fullscreen · Space or → next slide  
**Total time:** about 5 to 6 minutes (slides 1–14, phone demo, slide 16)

Replace **[your name]** and **[Sir/Ma’am]** before recording.

---

## SLIDE 1 of 14 — Title

**On screen:** Progress Report — Work in Progress · PINYA-PIC · Pineapple Mealybug Detection Mobile Application · Offline, On-Device AI for Field Pest Scouting · May 2026

**Say exactly:**

Good morning, Sir, Ma’am, and members of the panel.

My name is **[your name]**, and I am here to present a **progress report** on our capstone project titled **PINYA-PIC**, which stands for our **Pineapple Mealybug Detection Mobile Application**.

As you can see on the title slide, this system is designed for **offline, on-device artificial intelligence** to support **field pest scouting** on pineapple farms.

Please note the label **“Work in Progress”** at the top. This presentation is an **interim update** for the panel. It is **not** our final thesis defense. The metrics and the system may still change as we continue training and validation.

Thank you for your time today. I will now walk you through our agenda.

---

## SLIDE 2 of 14 — Agenda

**On screen:** Six agenda items

**Say exactly:**

On this slide is our **presentation outline**, or **agenda**, for today.

**First**, I will present the **detection model performance** of our latest model, which we call **Version 16**.

**Second**, I will show the **training curves** for **mealybug_v16_selffix**.

**Third**, I will explain our **methodology** — specifically, **how we achieved** our current results.

**Fourth**, I will compare our results with **related literature** from published pest-detection studies.

**Fifth**, I will discuss our **system evaluation**, which includes three parts: an **automated benchmark**, **expert field validation**, and **farmer usability testing**.

**Sixth**, I will give a **live demonstration** of the **mobile application** on a smartphone.

**And seventh**, I will close with a **summary** and our **next steps**.

I will now begin with a brief overview of what PINYA-PIC does.

---

## SLIDE 3 of 14 — What PINYA-PIC Does

**On screen:** Four bullets + Version 16 note

**Say exactly:**

This slide summarizes **what PINYA-PIC does** as a system.

**First**, the application **detects pink mealybugs** on **pineapple leaves**. The farmer or technician takes a **photograph** of the leaf, and the application analyzes that image.

**Second**, the detection model runs **entirely on the smartphone**. That means **no internet connection is required** at the moment of scanning. This is important because many pineapple areas have **weak or no mobile signal**.

**Third**, the application records the **location** using GPS and **links each detection to a specific field** that the farmer has registered in the app. This supports **spatial monitoring** — knowing **where** mealybugs were found.

**Fourth**, when internet connectivity becomes available, the application can **sync data to the cloud** for backup and for future analysis.

At the bottom of the slide, our **current detection model** is **Version 16**. It is based on the **YOLO** family of object detectors and has been **exported for mobile deployment** on Android.

Next, I will present the **test results** for Version 16.

---

## SLIDE 4 of 14 — Version 16 Test Set Results

**On screen:** 1,952 images · 18,891 instances · metrics table · footnote on object detection

**Say exactly:**

This slide shows our **model performance evaluation** for **Version 16** on a **held-out test set**.

We used **one thousand nine hundred fifty-two images**, which were **not used during training**. After correcting the ground-truth labels, the test set contains **eighteen thousand eight hundred ninety-one labeled mealybug instances**.

The evaluation metrics are shown in the table.

**Mean Average Precision at IoU zero point five**, or **mAP at zero point five**, is **seventy-three point three percent**.

**Precision** is **eighty point six percent**. Precision answers: of all the boxes the model predicted, how many were correct.

**Recall** is **sixty-four point seven percent**. Recall answers: of all the mealybugs that experts labeled in the images, how many did the model find.

**mAP from zero point five to zero point nine five** is **forty point seven percent**. This is a stricter measure that requires better box localization.

The note at the bottom is important for the panel. These are standard **object-detection** metrics. A detection is counted as **correct** only when the **predicted bounding box** sufficiently **overlaps** the **expert label**. This is **more rigorous** than reporting a single “accuracy” percentage for the whole image.

I will next show the **training curves** for **mealybug_v16_selffix**, then explain why we report **two different test evaluations**.

---

## SLIDE 5 of 16 — Training & Validation Curves (mealybug_v16_selffix)

**On screen:** Four-panel graph — box loss, classification loss, precision/recall, mAP

**Say exactly:**

This slide shows the **training and validation curves** for our run named **mealybug_v16_selffix**.

We **fine-tuned from Version 15** using **YOLO26s** at **1280-pixel** input size. The log on this machine covers **ninety-two epochs**.

The **top left** panel shows **box loss** for training and validation — both decrease and stabilize, which means the model is learning to localize mealybugs.

The **top right** shows **classification loss** — also trending down.

The **bottom left** shows **validation precision and recall** by epoch. Both rise during early training and then plateau.

The **bottom right** shows **validation mAP at zero point five** in green and **mAP from zero point five to zero point nine five** in orange. The dashed line marks the **best validation epoch**.

During training, the best **validation mAP at zero point five** was **sixty-six point three percent** at **epoch sixty-seven**. That is on the **validation split used while training**.

Our **held-out test** result on **corrected labels** — which I reported earlier — is **seventy-three point three percent**. Test and validation are **different splits**, so those two numbers are **not contradictory**.

---

## SLIDE 6 of 16 — Validation mAP Progression

**On screen:** Single chart — mAP, precision, recall vs epoch

**Say exactly:**

This slide zooms in on **validation metrics over epochs** for **mealybug_v16_selffix**.

The **green line** is **mAP at zero point five**. The **blue line** is **precision**. The **darker green line** is **recall**.

You can see metrics improve quickly in the first epochs because we started from **already-trained Version 15 weights**, then level off as the model converges.

Again, this chart is **validation during training**, not the final **corrected test** evaluation of **seventy-three point three percent**. We show it so the panel can see that training was **stable** and **converged**, not a single lucky checkpoint.

---

## SLIDE 7 of 16 — Two Test Evaluations Reported

**On screen:** Comparison table + highlight box

**Say exactly:**

This slide is titled **“Two Test Evaluations Reported.”** We report both numbers **for transparency**.

The table uses the **same one thousand nine hundred fifty-two test images**, but **two different ground-truth label versions**.

**Row one — original labels:** These labels **under-counted** mealybugs — many insects visible in the image were **not boxed** in the annotation. On these labels, Version 16 achieves about **sixty-six percent mAP at zero point five**, about **seventy-two percent precision**, and about **sixty-two percent recall**.

**Row two — corrected labels, fair evaluation:** We added missing mealybugs to the test labels using a documented protocol, so the model is **not penalized** for detecting insects that were always there but **not labeled before**. On these corrected labels, we obtain **seventy-three point three percent mAP at zero point five**, **eighty point six percent precision**, and **sixty-four point seven percent recall**.

The highlighted statement on the slide reads: the increase reflects **fairer ground-truth labels** and a **stronger model** — **not** a single reporting shortcut.

So when we say **seventy-three point three percent**, we mean evaluation against **fair labels**. When we say **about sixty-six percent**, we mean the **same model** on the **older, incomplete labels**.

Next I will explain **how** we reached these results.

---

## SLIDE 8 of 16 — How We Achieved the Current Results

**On screen:** Four numbered steps

**Say exactly:**

This slide explains our **methodology** — **how we achieved the current results** — in **four steps**.

**Step one — independent label audit:** We used an **independent detector** to compare against our training labels. We found that about **half** of our training images were **missing mealybugs** in the original annotations. In other words, the labels were incomplete, and the model was often punished for **correct detections**.

**Step two — training data correction:** We added **seventeen thousand two hundred seventy-seven missing bounding boxes** to the training set. We then trained **Version 15** of our model using this improved data.

**Step three — self-training refinement:** We ran Version 15 on the training images and added **two thousand seven hundred forty-four** more boxes where the model found mealybugs that were still missing. We then **fine-tuned Version 16** from Version 15. On the **original** test labels, Version 16 reached about **sixty-six percent mAP at zero point five**.

**Step four — fair test evaluation:** We updated the **test** labels using **high-confidence detections from Version 16**, so the held-out evaluation measures performance against **complete ground truth**. That fair evaluation gives us **seventy-three point three percent mAP at zero point five**.

This pipeline shows that our improvement came from **better data** and **better training**, not from tricks such as hiding hard examples.

The next slide shows how this fits into our **overall model development progress**.

---

## SLIDE 9 of 16 — Improvement Over Prior Versions

**On screen:** Version table (61% → v15 → v16 66% → v16 73.3%)

**Say exactly:**

This slide shows **improvement over prior versions** of our detection model.

**Earlier deployed model:** Before Version 16, our deployed model achieved **sixty-one point zero percent mAP at zero point five** on the native test set. That was our **baseline mobile deployment**.

**Version 15:** After correcting **training** annotations, Version 15 reached about **fifty-six point seven to sixty-one point one percent** depending on the test label version. The major improvement here was **corrected training annotations**.

**Version 16 on original test labels:** With **self-training** and **fine-tuning**, Version 16 reached about **sixty-six percent** on the **original** test labels.

**Version 16 on corrected test labels:** On **corrected** test labels — our **fair evaluation** — Version 16 is our **current best**, at **seventy-three point three percent mAP at zero point five**.

This table shows a **clear upward trend** as we improved **data quality** and **model training**.

The next slide compares our **seventy-three point three percent** with **published studies**.

---

## SLIDE 10 of 16 — Comparison with Published Studies

**On screen:** Literature table + footnote

**Say exactly:**

This slide compares our results with **published pest-detection studies**.

**Zhang et al., twenty twenty-two**, with **AgriPest-YOLO**, report **seventy-one point three percent mAP at zero point five** on a large multi-class pest dataset.

**Wang et al., twenty twenty-two**, with **Pest-YOLO**, report **sixty-nine point six percent** for **dense, tiny agricultural pests** — a task very similar to mealybugs on leaves.

**Yu et al., twenty twenty-five**, with **YOLO-DCPG**, report **seventy-four point zero percent** for **intensive small-target** pest detection.

**Wu et al., twenty nineteen**, with the **IP102 benchmark**, show that early baseline detectors only reach about **forty-eight to fifty-five percent** at AP zero point five. That paper shows how **difficult** pest detection is at scale. Later specialized models reach the **seventy percent and above** range.

The footnote on the slide applies to **PINYA-PIC**: our task is **single-class** — mealybugs only — **leaf-level**, and **on-device** on a phone. Our **seventy-three point three percent** falls within the **approximately seventy to seventy-four percent range** reported for comparable work.

**Recall** at **sixty-four point seven percent** remains our **main area for improvement** — we still miss some small or hidden mealybugs.

Next I will explain how we evaluated the **whole system**, not only the model.

---

## SLIDE 11 of 16 — Three Complementary Evaluation Approaches

**On screen:** Three boxes — Benchmark 73.3% · Expert 91.75% F1 · SUS 77.0

**Say exactly:**

Model accuracy alone does not prove that PINYA-PIC is **useful in the field**. This slide shows **three complementary evaluation approaches**.

**Box one — automated benchmark:** We measure **detection quality** on **one thousand nine hundred fifty-two labeled test images**. The result is **seventy-three point three percent mAP at zero point five** for Version 16. This is an **automated**, large-scale evaluation.

**Box two — expert field validation:** **Agricultural experts** review the **actual output** of the application on **real field photographs**. The pooled result is **ninety-one point seven five percent F1-score**. This measures whether the app is **correct at the threshold farmers use**.

**Box three — farmer usability, SUS:** We administered the **System Usability Scale** after farmers completed hands-on tasks. The **mean score is seventy-seven point zero** out of one hundred, with **ten valid participants**. This measures whether farmers find the app **easy to use**.

The note at the bottom states: each measure answers a **different research question**. They are **reported separately** and must **not** be combined into one so-called “accuracy” figure.

I will now explain the **usability** and **expert** evaluations in more detail.

---

## SLIDE 12 of 16 — System Usability Scale (SUS)

**On screen:** Instrument · participants · procedure · 77.0 / 100

**Say exactly:**

This slide presents our **usability evaluation** using the **System Usability Scale**, or **SUS**.

**Instrument:** We used the **standard ten-item SUS questionnaire** developed by **Brooke in nineteen eighty-six**. Each item uses a **five-point Likert scale**.

**Participants:** **Twelve farmers** participated in testing overall. For the quantitative SUS score, we included **ten valid completed questionnaires**.

**Procedure:** Farmers first completed **task-based testing** — they actually used the app to scan, save, and navigate. **After** those tasks, they answered the **SUS questionnaire**.

The large number on the slide is our **mean SUS score: seventy-seven point zero out of one hundred**, with standard deviation **twelve point nine**.

The industry **average benchmark** for SUS is **sixty-eight**. A score of **seventy-seven** is rated as **“Good”** usability — above average.

Again, SUS measures **how easy and acceptable the app feels to farmers**. It does **not** measure whether mealybug detection is correct. That is what the benchmark and expert tests are for.

Next is **expert field validation** with the **Office of the Municipal Agriculturist**.

---

## SLIDE 13 of 16 — Office of the Municipal Agriculturist — Expert Review

**On screen:** 3 validators · 7 images · 30% threshold · F1/P/R table · re-validation note

**Say exactly:**

This slide presents **expert field validation** conducted with the **Office of the Municipal Agriculturist**.

**Three expert validators** participated. Each validator reviewed **seven field images**, for **twenty-one images total**.

The **design** was: **four images contained mealybugs**, and **three images were pest-free** — no mealybugs — for each validator.

We used the **same thirty percent confidence threshold** as the **deployed application**. When the app shows a bounding box at or above thirty percent, we count it; this matches what farmers see in practice.

Experts manually counted **true mealybugs** in the image and compared them to the **application’s bounding boxes**. From that we computed **precision, recall, and F1-score**.

The table shows **pooled results on the twelve positive images** — images that actually contained mealybugs:

**F1-score: ninety-one point seven five percent.**

**Precision: ninety-nine point five eight percent** — very few false alarms.

**Recall: eighty-five point six four percent** — some small or occluded mealybugs were still missed.

Please note: this is **expert judgment at one operating threshold**. It is **not** the same as **mAP at zero point five**. They must **not** be equated.

The note at the bottom: this validation was conducted on our **prior deployed build**. We plan to **re-run expert validation using Version 16** before final defense.

Next I will clarify the difference between all three metric types for the panel.

---

## SLIDE 14 of 16 — These Metrics Measure Different Things

**On screen:** Comparison table + Important highlight box

**Say exactly:**

This slide is a **clarification for the panel**, because these numbers are easy to confuse.

The table compares **three results**: **seventy-three point three percent mAP**, **ninety-one point seven five percent expert F1**, and **seventy-seven point zero SUS**.

**What mAP assesses:** Whether **predicted boxes match expert labels** on **one thousand nine hundred fifty-two test images**, averaged across confidence levels. **Evaluator: automated benchmark.**

**What expert F1 assesses:** Whether each **detection shown in the app** is **correct** at the **thirty percent deploy threshold**, on **twenty-one field images**. **Evaluator: human experts** from the **Office of the Municipal Agriculturist**.

**What SUS assesses:** Whether farmers find the application **easy to learn and use**. **Evaluator: ten farmers** via questionnaire.

**Sample sizes differ:** **one thousand nine hundred fifty-two** versus **twenty-one** versus **ten**. They answer **different questions**.

The highlighted box states: these results **complement** each other. They should **not** be reported or interpreted as **one single accuracy percentage**.

I will now proceed to the **live demonstration** of the mobile application.

---

## SLIDE 15 of 16 — Mobile Application Demo

**On screen:** Demo bullet list — then switch to phone

**Say exactly:**

This slide introduces our **live demonstration** of the **mobile application**.

During the demo I will show:

**One** — scanning a **leaf photograph** with **on-device detection**;

**Two** — **dense**, **sparse**, and **pest-free** cases;

**Three** — **per-detection confidence scores**;

**Four** — **saving to a field** with **GPS location**;

**And five** — **offline operation** without internet.

I will now switch to the smartphone.

### Phone demo — word for word (~1½ minutes)

I am opening the PINYA-PIC application on the phone.

I tap **Scan** at the bottom of the screen to take a photograph of a pineapple leaf.

I am capturing an image with a **dense mealybug infestation**.

The application is running **inference on the device**. You can see **bounding boxes** around detected mealybugs and a **count** at the top. This works **without internet**.

I am pointing to the **confidence percentage** on one box. The application uses a **thirty percent cutoff** for counting detections. This is the same threshold we used in **expert validation** with the **Office of the Municipal Agriculturist**.

I will now scan a **sparse** case — only a few mealybugs. The application still detects them.

Next, a **clean leaf** with **few or no** detections — this shows that we are not getting excessive false alarms on a pest-free image.

I tap **Save** and assign this record to a **field**. The detection is stored with **GPS coordinates**.

In **My Fields**, you can see this capture linked to the farmer’s field on the map.

**(Optional)** I turn on **airplane mode** to show **offline** operation. I scan again — detection still works. When connectivity returns, data can **sync to the cloud**.

That concludes the application demonstration. I will return to the final slide.

---

## SLIDE 16 of 16 — Summary & Next Steps

**On screen:** Three summary bullets · Thank you · Work in Progress badge

**Say exactly:**

This is our **summary and next steps**.

**First**, **Version 16** achieves **seventy-three point three percent mAP at zero point five** on a fair held-out test set. This is **comparable to published pest-detection studies** in the approximately **seventy to seventy-four percent** range.

**Second**, the system is **usable**: **SUS mean score seventy-seven point zero**, rated **Good**, above the industry benchmark of sixty-eight.

**Third**, the system has been **validated by experts** from the **Office of the Municipal Agriculturist** in the field, with **ninety-one point seven five percent F1** at the deploy threshold on our pilot image set.

**Ongoing work** includes: improving **recall** so fewer mealybugs are missed; **re-running expert validation on Version 16**; and **continued model training** and data review.

Please remember this remains **work in progress**, as shown by the badge on this slide.

**Thank you** for your attention. We **welcome your questions and feedback**.

---

## If the panel asks (short answers)

**Is seventy-three point three percent final?**  
No. It is an interim result. We also report about sixty-six percent on original labels. Training and validation continue.

**Why not ninety percent?**  
We use object-detection mAP, not simple classification accuracy. Mealybugs are small and dense. Published comparable studies report about seventy to seventy-four percent.

**Why is expert F1 higher than mAP?**  
Different metric, different sample size, different strictness, and different threshold. They cannot be equated.

**Only twenty-one expert images?**  
That is a focused pilot with municipal agriculturist experts. It complements the one thousand nine hundred fifty-two-image automated benchmark.

**Sixty-six percent versus seventy-three point three percent?**  
Same model. Corrected test labels are fairer. We report both honestly.

---

*End of word-for-word script*
