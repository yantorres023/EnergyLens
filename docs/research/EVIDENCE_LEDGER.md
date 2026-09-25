# Evidence ledger

Confidence: HIGH / MEDIUM / LOW. Status: SUPPORTED / MIXED / WEAKENED / UNTESTED. Source IDs → `SOURCES.md`. No human interviews were run; nothing here is UNVALIDATED_WITH_REAL_USERS unless stated otherwise — in fact **every user-behaviour assumption is UNVALIDATED_WITH_REAL_USERS**.

---

### A1. GB households experience frequent bill changes they did not cause
* SUPPORT: FACT — cap levels changed every quarter of 2026 (S05–S07, S01); VAT on electricity changes 1 Oct 2026 and possibly again 1 Apr 2027 (S03); TDCV change Jul 2026 changes headline numbers (S08).
* COUNTER-EVIDENCE: ~34% on fixed tariffs are insulated from rate changes (S10); many changes are small (Q4: +4% dual fuel).
* SOURCES: S01, S03, S05–S08, S10
* CONFIDENCE: HIGH
* STATUS: SUPPORTED
* FALSIFICATION TEST: If <30% of beta users' consecutive bills differ by >10% in total or >5% in rate, the "change" trigger is too rare.

### A2. Consumers struggle to understand their electricity bill
* SUPPORT: FACT — billing is the top dispute category (S11, S12).
* COUNTER-EVIDENCE: FACT — 82% satisfied with ease of understanding bills (S13). Disputes measure errors/disagreement, not comprehension.
* CONFIDENCE: MEDIUM that confusion exists for a minority; LOW that it's broad.
* STATUS: **WEAKENED** → reframed as A3.
* FALSIFICATION TEST: In beta, if <40% of users who add two bills view the change breakdown more than once, generic comprehension is not the need.

### A3. The unmet need is "why did it change?", spiking at change events
* SUPPORT: INFERENCE from A1 + A2: satisfaction with *understanding a bill* co-exists with record disputes → the pain concentrates at deviations (estimates, rate changes, DD changes).
* COUNTER-EVIDENCE: Supplier apps show usage graphs and bill history (S24); users may attribute changes to "prices went up" without needing quantification.
* CONFIDENCE: MEDIUM
* STATUS: UNTESTED (UNVALIDATED_WITH_REAL_USERS)
* FALSIFICATION TEST: Landing-page A/B: "Understand your bill" vs "Find out why your bill changed" — if change framing does not beat generic framing on sign-up rate by ≥20% relative, revisit.

### A4. A GB bill can be recomputed deterministically from a handful of fields
* SUPPORT: FACT — bill = standing charge × days + unit rate × kWh, plus VAT (S22); cap is set in those units (S01).
* COUNTER-EVIDENCE: Rate changes mid-period, rounding conventions per supplier, discounts, Warm Home Discount credits, back-bill corrections, and estimated-then-corrected readings.
* CONFIDENCE: HIGH for structure; MEDIUM for exact penny reconciliation.
* STATUS: SUPPORTED (by structure). Mitigation: rate periods, adjustment lines, reconciliation tolerance with explicit "doesn't match" state.
* FALSIFICATION TEST: If >20% of beta bills fail reconciliation by >£1 after user confirmation, the model is missing a common charge type.

### A5. Users will manually enter ~6–10 fields from a bill
* SUPPORT: HYPOTHESIS — the fields are printed on every bill; paste-text import reduces typing.
* COUNTER-EVIDENCE: Manual entry is a known drop-off point in finance apps (INFERENCE); bills are PDFs in supplier apps.
* CONFIDENCE: LOW
* STATUS: UNTESTED
* FALSIFICATION TEST: Bill-entry completion <50% of starts → invest in OCR or drop.

### A6. OCR of UK bills is reliable enough to trust
* SUPPORT: On-device OCR exists (e.g. ML Kit).
* COUNTER-EVIDENCE: ~20+ supplier layouts, multi-page PDFs, gas+electric on the same bill, split rate periods. INFERENCE: field-level misassignment is likely.
* CONFIDENCE: LOW
* STATUS: WEAKENED → V1 uses paste-text parsing with mandatory confirmation, not OCR.
* FALSIFICATION TEST: If paste-parse correction rate >30% of fields, parser is failing.

### A7. Quantified change attribution is valuable beyond one use
* SUPPORT: HYPOTHESIS — bills arrive monthly/quarterly; each is a new question.
* COUNTER-EVIDENCE: Users may only care when a bill surprises them.
* CONFIDENCE: LOW
* STATUS: UNTESTED
* FALSIFICATION TEST: Second-bill return rate <20% at 60 days → product is episodic; monetise per-use or stop.

### A8. Recommendations can save meaningful money
* SUPPORT: CALCULATION — at 26.32p/kWh, a 10% cut of 2,500 kWh/yr = 250 kWh ≈ £66/yr. Economy 7 shift or fixing below cap can be larger.
* COUNTER-EVIDENCE: Standing charge (54.83p/day ≈ £200/yr) is unavoidable (S22); Ofgem says low-standing-charge tariffs won't reduce most bills (S14). Savings are modest for typical users.
* CONFIDENCE: MEDIUM that savings are modest (tens of £/yr), not hundreds.
* STATUS: MIXED — copy must never promise savings.
* FALSIFICATION TEST: If median verified experiment improvement is < £5/bill, reposition from "save" to "understand & check".

### A9. Checking Direct Debit adequacy is a real need
* SUPPORT: FACT — 2022 DD increases averaged 62% (S21); back-bills average £200 (S12).
* COUNTER-EVIDENCE: 2022 was an extreme year; Ofgem tightened DD rules afterwards.
* CONFIDENCE: MEDIUM
* STATUS: UNTESTED
* FALSIFICATION TEST: <25% of users with DD open the DD check at least once.

### A10. Smart-meter data access is impractical for V1
* SUPPORT: INFERENCE — DCC access requires a DCC user or intermediary (Glowmarkt/Bright) (S20).
* COUNTER-EVIDENCE: Bright offers free access; a partnership could exist later.
* CONFIDENCE: HIGH (for V1)
* STATUS: SUPPORTED
* FALSIFICATION TEST: n/a (architecture decision); revisit if an open consumer data API appears.

### A11. Consumers will pay
* SUPPORT: HYPOTHESIS — small one-time unlock for power users.
* COUNTER-EVIDENCE: Free supplier apps, MSE, Citizens Advice; energy-stressed households are price sensitive.
* CONFIDENCE: LOW
* STATUS: UNTESTED
* FALSIFICATION TEST: Fake-door paywall: <3% tap "Unlock" among active users → free / partnership model.

### A12. Price-cap reference data can be kept current
* SUPPORT: FACT — published quarterly with ~5 weeks' notice (S01).
* COUNTER-EVIDENCE: Regional tables not extracted in this environment; publishing requires app update without a backend.
* CONFIDENCE: MEDIUM
* STATUS: MIXED — mitigated by staleness detection and using the user's own rates for calculation.
* FALSIFICATION TEST: If the bundled data is stale for >14 days after a cap change in two consecutive quarters, add remote data updates.
