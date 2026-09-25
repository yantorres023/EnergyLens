# Product strategy

Status: all user-behaviour statements are **HYPOTHESIS / UNVALIDATED_WITH_REAL_USERS**.

| | |
|---|---|
| **ICP** | GB household bill payer on a credit electricity meter (Direct Debit or pay-on-bill), standard variable or fixed tariff, single-rate or Economy 7, who reads their own bills and is cost-conscious but not an energy enthusiast. Over-represented: renters and first-time bill payers, people who just switched supplier, Economy 7 households with storage heaters, people who got a surprise bill or DD increase. |
| **TRIGGER** | A bill or DD notice that is noticeably different from the last one — especially around price-cap dates (1 Jan/Apr/Jul/Oct), the 1 Oct 2026 VAT cut and its scheduled end on 1 Apr 2027, after an estimated bill, a back-bill, or a DD increase. |
| **JTBD** | "When my electricity bill changes, help me understand exactly why — in pounds — and tell me whether there's anything I can do, so I can stop worrying or act." |
| **CORE PROMISE** | "See why your electricity bill changed — in pounds — and check if your next bill improves." (No savings promise.) |
| **AHA MOMENT** | The second bill is saved and the change card shows e.g. "£11.25 more: +£8.10 you used more per day, +£5.19 higher prices, +£3.18 one extra day, −£5.34 VAT cut". |
| **CORE LOOP** | Add bill → reconcile with printed total → compare with previous → see drivers → pick one action → next bill arrives → add → action verified → new comparison. |
| **ACTIVATION** | Candidate: two bills saved and comparison viewed, **or** one bill + an actionable insight opened. |
| **RETENTION** | Driven by bill cadence (monthly/quarterly). Supported by: active action waiting for next bill; quarterly cap changes; DD check. No push notifications in V1 (no backend); future: local reminders at the user's billing cadence. |
| **NORTH STAR (hypothesis)** | Verified bill comparisons with a completed action experiment per month. |
| **MONETIZATION** | Free V1 with no ads, no commission. See `docs/business/MONETIZATION.md` — lead hypothesis: one-time "household pack" unlock later, or consumer-advice partnerships. |
| **DISTRIBUTION** | Search around cap/VAT dates, short-form "why did my bill change" explainers, MSE forum/Reddit participation (non-spam), consumer-advice partners. See `docs/business/DISTRIBUTION.md`. |
| **RISKS** | Episodic need (A7); manual entry friction (A5); supplier apps copy the feature; low willingness to pay; reference data upkeep. |

## Positioning

"Your bill's second opinion." Independent, arithmetic-first, on-device. Not a comparison site, not a smart-meter dashboard.

## What we deliberately do not do (V1)

Tariff catalogue or "best deal" ranking; switching; smart-meter/DCC data; supplier logins; OCR; cloud accounts; appliance-level advice ("your fridge costs £X"); savings guarantees; gas (V1.1 candidate); prepayment meters; Northern Ireland.
