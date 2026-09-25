# PRD — EnergyLens V1 (GB electricity)

## Problem

GB electricity bills change every quarter for ~65% of households (price cap), VAT on electricity fell from 5% to 0% on 1 Oct 2026, billing periods vary in length, and estimated readings are common. Billing is 56–58% of Energy Ombudsman disputes. Bills show *what* is owed, not *why* the total differs from last time. (Evidence: `docs/research/EVIDENCE_LEDGER.md`.)

## Goal

For a GB household with two electricity bills, explain the change in pounds with components that add up exactly, check the bill's arithmetic, and let the user verify one chosen action on the next bill.

## Non-goals

See `PRODUCT_STRATEGY.md` → "What we deliberately do not do".

## Users

ICP in `PRODUCT_STRATEGY.md`.

## Requirements (V1 — implemented)

| ID | Requirement | Status |
|---|---|---|
| R1 | Onboarding: value, privacy, household (meter type, tariff kind, payment, optional DD, optional region). No personal identifiers. | Done |
| R2 | Manual bill entry: period, kWh (or from meter readings incl. rollover), unit rate(s), standing charge, VAT 5%/0% per rate period, prices incl./excl. VAT, reading type, credits/charges, optional printed total, balance, supplier name | Done |
| R3 | Bills crossing a price change: two rate periods, each with own VAT | Done (UI: 2 periods; model: N) |
| R4 | Economy 7 (day/night registers) | Done |
| R5 | Paste-text import → parse → review with source snippets → confirm/correct → save. Corrections recorded. Pasted text never stored | Done |
| R6 | Deterministic calculator (integer pence/milli-units, half-away-from-zero rounding) | Done |
| R7 | Reconciliation vs printed total (±5p), with blocking confirm dialog on mismatch | Done |
| R8 | Comparison with previous bill: effects (period length, daily usage, unit price, standing charge, VAT rate, adjustments) that sum exactly to the difference; caveats | Done |
| R9 | Insights tied to calculations with provenance + confidence; no savings guarantees | Done |
| R10 | Actions with next-bill verification (5 types) | Done |
| R11 | What-if: re-price a bill at a user-entered quote | Done |
| R12 | Direct Debit check (ESTIMATE) | Done |
| R13 | Bill history, detail, edit, delete | Done |
| R14 | Settings: household, local usage log opt-in/view/clear, delete all data, data-source status | Done |
| R15 | Versioned price-cap reference with staleness guard | Done |

## Every number carries a provenance

MEASURED (meter reading on bill), PARSED (from pasted text, confirmed), USER-ENTERED, CALCULATED, ESTIMATED. Estimates are only: Direct Debit check, cap-change preview, E7 break-even vs GB average, and any usage based on an estimated reading.

## Beta gates (experimental thresholds — HYPOTHESES to be tuned)

Measured on a closed beta of ≥ 100 GB households over ≥ 2 billing cycles (≈ 90 days), using the opt-in local log exported voluntarily plus a short in-app survey (future).

| Gate | Metric | Continue | Investigate | Kill / pivot |
|---|---|---|---|---|
| Bill completion | bills saved ÷ bill forms opened | ≥ 70% | 50–70% | < 50% → entry too hard; invest in OCR or drop |
| Correction rate (paste) | corrected fields ÷ parsed fields | ≤ 15% | 15–30% | > 30% → parser failing; manual-first |
| Reconciliation | bills that match printed total (where given) | ≥ 85% | 70–85% | < 70% → model missing charge types |
| Comparison completion | users with ≥ 2 bills who view comparison | ≥ 60% | 40–60% | < 40% → change story not compelling |
| Explanation clarity | "I understand why my bill changed" (survey, 5-pt ≥ 4) | ≥ 70% | 50–70% | < 50% → **product failure** of core promise |
| Action selection | users with comparison who start an action | ≥ 25% | 10–25% | < 10% → drop action loop, keep explainer |
| Second-bill return | users who add a bill ≥ 25 days after first session | ≥ 35% at 60 days | 20–35% | < 20% → episodic; one-off tool, no subscription |
| Calculation error reports | confirmed calculator bugs per 100 bills | 0 | ≤ 1 | any systematic error → stop beta until fixed |
| Willingness to pay | fake-door "unlock" tap rate among activated users | ≥ 8% | 3–8% | < 3% → free/partnership model only |

**Kill rule:** if explanation clarity < 50% **and** comparison completion < 40% after two iterations, STOP (write `STOP_REPORT.md`). **Pivot rule:** if the explainer works but return < 20%, pivot to a free seasonal tool (cap-date and VAT-change moments) distributed via content/partners.

## Release criteria (V1 store build)

Format/analyze/tests green; tariff data verified (`verified_official`); legal docs reviewed by a human; brand cleared; signing configured; store listings reviewed for claims.
