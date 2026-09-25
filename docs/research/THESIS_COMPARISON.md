# Product thesis comparison (GB market)

Scored 1–5. "Feasibility" = can a small team ship a correct V1 without utility login, paid APIs or smart-meter credentials.

| Thesis | Pain evidence | Feasibility | Differentiation vs supplier apps/comparison sites | Repeat use | Accuracy risk | Verdict |
|---|---|---|---|---|---|---|
| A. Bill explainer | Weak-medium: 82% say bills are easy to understand (S13) | 5 | Low — every bill already lists lines; supplier apps show bills | 1 (one-off) | Low | **Not alone.** Becomes a supporting layer |
| B. Bill change detector ("why did it change?") | Medium-strong: billing = 56–58% of ombudsman disputes (S11); 4 cap changes/yr + VAT change (S01–S07) | 5 — deterministic decomposition | Medium-high — suppliers show *what* you owe, rarely a quantified *why* (INFERENCE from S24) | 3–4 (every bill) | Low-medium | **Core wedge** |
| C. Tariff optimiser | Medium — switching market exists; MSE/Uswitch dominate (S19) | 3 (needs full tariff catalogue for "best deal"); 5 for "what-if this quote" | Low for catalogue; medium for "check a quote against *my* real usage" | 1–2 | High for catalogue | **Only as user-entered what-if** |
| D. Action tracker | Hypothesis — no evidence users want to track actions | 5 | High — nobody closes the loop to the next bill | 3 (per bill) | Medium (confounders: weather, days) | **Include, marked HYPOTHESIS** |
| E. Smart-meter companion | Medium — 72% smart (S09) | 2 — DCC access requires being a DCC user or relying on Glowmarkt/Bright; heavy compliance | Low — Bright already free (S20) | 5 | Medium | **Rejected for V1** |
| Wedge B2. "Is my Direct Debit right?" | Medium — DD complaints historic (S21), back-bills ~£200 (S12) | 5 — deterministic from observed kWh/day and rates | Medium — suppliers set DD; independent check is rare | 2–4 (quarterly) | Medium (it is a projection → ESTIMATED) | **Include as second hook** |

## Decision

Build **B (change detector)** with **A** as supporting explanation, **D** as the retention loop, **B2** (Direct Debit check) as a second trigger, and **C** only as a *user-entered* what-if (no catalogue, no referral links).

Pivot policy check: this stays within ENERGY BILL + CONSUMER UNDERSTANDING + COST + TARIFF + ACTION. Two adjacent wedges considered: B2 (Direct Debit check) and a "price-cap change preview". The preview is folded into B as an estimate labelled with the GB-average caveat.
