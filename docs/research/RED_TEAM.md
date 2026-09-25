# Red team: assume EnergyLens is a bad idea

Each attack is argued as strongly as the evidence allows, then judged.

| # | Attack | Strongest case | Evidence | Verdict |
|---|---|---|---|---|
| 1 | Utility apps already explain bills | Octopus/OVO/EDF apps show bills, usage graphs, balance; Octopus is the largest supplier | S24 | **Partly true.** They show *what*; none found that quantifies *why the total changed* into days/usage/rate/standing/VAT. Also 20+ suppliers — a supplier-agnostic view helps switchers and multi-account households. Risk remains that Octopus ships this. |
| 2 | Bills are too fragmented | Supplier layouts differ | INFERENCE | **False for GB at the field level.** All bills carry the same primitives (S22). Layout fragmentation hurts OCR, not the calculator → manual/paste entry with confirmation. |
| 3 | OCR will fail | Multi-supplier layouts, gas+elec, split periods | A6 | **Likely true.** V1 does not use OCR. Paste-text parser + mandatory confirm step. |
| 4 | Calculations are too risky | A wrong number destroys trust; supplier rounding differs | A4 | **Manageable.** Integer fixed-point arithmetic, reconciliation against the bill's own total with an explicit mismatch state, provenance labels, no rates invented by the app. |
| 5 | Users don't care after one analysis | Episodic need | A7 | **Most serious risk.** Mitigation: per-bill change question, action experiment tied to next bill, DD check, quarterly cap-change reminder. Kill threshold defined (second-bill return <20%). |
| 6 | Smart-meter access unavailable | DCC requires accreditation | A10 | **True** → not used. |
| 7 | Data changes constantly | Quarterly caps, VAT changes | A12 | **True, and it's the opportunity.** Calculator uses the user's bill rates; bundled cap data is reference-only with staleness guard. |
| 8 | Recommendations won't save meaningful money | Standing charge unavoidable; 10% usage cut ≈ £66/yr | A8 | **Largely true.** Positioning must be "understand and check", not "save £££". Savings shown only as calculated what-ifs, never promised. |
| 9 | Consumers won't pay | Free alternatives | A11 | **Probably true for subscriptions.** Monetisation is the weakest part; V1 ships free with no paywall; see `MONETIZATION.md`. |
| 10 | Comparison sites already solve it | MSE/Uswitch compare tariffs | S19 | **True for "which tariff is cheapest".** Not true for "why did *my* bill change" or "is this quote better *for my actual usage*". EnergyLens does not compete on catalogue and takes no commission in V1. |
| 11 | "82% understand their bill" kills the thesis | Ofgem survey | S13 | **Kills the generic explainer.** Survives only as a change/verification tool for a minority at change moments. Addressable market is therefore smaller than "all bill payers". |
| 12 | Regulatory: giving tariff advice | Ofgem Confidence Code governs comparison sites | INFERENCE | Low for V1 — no ranking, no switching, no commission. Must not look like a price comparison service. |

## Decision

**PIVOT (narrowed) → GO on the narrowed wedge.**

* STOP is not justified: the calculator is feasible, deterministic, cheap to build and to test, and there is a concrete trigger (1 Oct 2026 VAT removal + cap change; next change 1 Jan 2027).
* The broad thesis "understand your electricity bill" is rejected (S13).
* Surviving product: **"Why did my electricity bill change — and is my Direct Debit right?"** for GB electricity credit-meter households, with a next-bill action check.
* GO is conditional on the beta gates in `docs/product/PRD.md` §Beta gates. If second-bill return and comparison completion fail, STOP per `VALIDATION_DEBT.md`.

---

# Final red team: "If this launches tomorrow, the 10 most likely ways it fails"

| # | Failure | Class | Likelihood | Mitigation done | Remaining |
|---|---|---|---|---|---|
| 1 | Users try once, never add a second bill | PRODUCT / MARKET | High | Onboarding and empty state ask for *two* bills (past PDFs are available); action loop; DD check as second hook | Reminders need notifications (V1.1); kill gate defined |
| 2 | Manual entry is too much work | UX | High | Paste import with review; kWh-from-readings; unit-slip validation; VAT defaults by date | OCR deferred; measure completion gate |
| 3 | Numbers don't match the bill → trust lost | TRUST / CALCULATION | Medium | Integer arithmetic; ±5p reconciliation; blocking mismatch dialog; split rate periods; incl./excl. VAT switch; credits after VAT | Unmodelled charges (e.g. per-period rounding quirks, exit fees) — collect in beta |
| 4 | Reference cap data wrong or stale | DATA | Medium | Reference-only; validator + staleness gate; CI warning; "awaiting verification" disclosed | Human verification of all 4 rows before launch; quarterly update process |
| 5 | Parser mis-reads a supplier layout | TECHNICAL | High | Parsed values never used before confirmation; snippets shown; corrections recorded; projections ignored | Real supplier fixtures needed (V-08) |
| 6 | Explanation is correct but not understood | UX | Medium | Plain labels with before/after figures; one-sentence explanations; methodology section | Test V-02 |
| 7 | Brand conflict forces a rename after launch | REGULATORY / DISTRIBUTION | Medium-high | Documented conflict; release blocked on clearance | Choose and clear a name |
| 8 | Perceived as a comparison site / tariff advice | REGULATORY / TRUST | Low-medium | No catalogue, no ranking, no links, no commission; What-if uses user-entered quotes only | Keep it that way unless the Confidence Code route is taken deliberately |
| 9 | Nobody finds it outside cap dates | DISTRIBUTION | High | Content calendar tied to cap/VAT dates; SEO list | Execution by a human |
| 10 | No revenue path | MONETIZATION | High | Free, zero running cost (no servers); fake-door + partnership plan | Accept as a free tool if gates fail |

Also considered: data loss on phone change (Android backups disabled by design → documented trade-off; export feature is a V1.1 candidate), iOS signing (blocked on Apple account), and Northern Ireland users misapplying GB VAT (onboarding and listing say GB only).
