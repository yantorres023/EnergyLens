# Market comparison

Labels used throughout: **FACT** (from a cited source), **CALCULATION** (derived arithmetically from facts), **INFERENCE** (reasoned from facts, not directly stated), **HYPOTHESIS** (untested belief), **UNVALIDATED_WITH_REAL_USERS** (no user has confirmed this).

Source IDs (S01…) refer to `SOURCES.md`. Research constraint: direct page fetches were blocked in the build environment; numbers are from search-result extracts of the cited pages and must be re-verified by a human before launch (see `RELEASE_REPORT.md` → HUMAN_ACTION_REQUIRED).

## Scoring (1 = poor for EnergyLens, 5 = good)

| Criterion | Great Britain | USA (California/PG&E) | USA (national) | Canada (Ontario) | Ireland | Germany/Spain |
|---|---|---|---|---|---|---|
| Price pressure / salience | 5 | 5 | 3 | 3 | 4 | 4 |
| Tariff complexity (pain) | 3 | 5 | 4 | 3 | 3 | 4 |
| Tariff **standardisation** (feasibility) | 5 | 3 | 1 | 4 | 3 | 2 |
| Smart-meter penetration | 4 | 5 | 3 | 5 | 3 | 1 (DE) / 5 (ES) |
| Data accessibility without login | 4 | 3 | 2 | 4 | 2 | 2 |
| Bill standardisation | 4 | 3 | 1 | 3 | 3 | 2 |
| Competition (inverse) | 2 | 2 | 2 | 3 | 3 | 3 |
| Change-event frequency (triggers) | 5 | 3 | 2 | 3 | 2 | 2 |
| Public official datasets | 4 | 4 | 4 | 4 | 3 | 3 |
| Monetisation | 3 | 4 | 3 | 2 | 2 | 3 |
| Localisation cost (for an English-first team) | 5 | 5 | 5 | 4 (EN/FR) | 5 | 1 |
| Regulatory risk (inverse) | 3 | 3 | 3 | 4 | 4 | 3 |
| **Total (/60)** | **47** | **45** | **33** | **42** | **37** | **30 / 34** |

Scores are INFERENCE from the evidence below, not measurement.

## Great Britain — selected

* FACT (S01, S02): Ofgem price cap for 1 Oct–31 Dec 2026: £1,723/yr typical dual fuel (+4%). Average Direct Debit electricity 26.32 p/kWh and 54.83 p/day, **with no VAT on electricity from 1 Oct 2026 to 31 Mar 2027**.
* FACT (S03, S04): VAT on domestic electricity in GB cut from 5% to 0% for 1 Oct 2026–31 Mar 2027; gas stays 5%; Northern Ireland stays 5%. Decision on extension at Autumn Budget.
* FACT (S05–S07): average cap values changed every quarter in 2026: Jan–Mar 27.69p/54.75p, Apr–Jun 24.67p/57.21p, Jul–Sep 26.11p/57.19p (all incl. 5% VAT), Oct–Dec 26.32p/54.83p (0% VAT).
* FACT (S08): Ofgem typical domestic consumption values changed from 1 Jul 2026: electricity 2,700 → 2,500 kWh; Economy 7 3,400 kWh.
* FACT (S09): ~72% of GB meters smart/advanced at end Q2 2026; 92% of smart meters operating in smart mode.
* FACT (S10): ~34–35% of electricity customers on fixed tariffs (Mar 2026) → ~65% exposed to quarterly cap changes.
* FACT (S11): Billing is 56% (2025) and 58% (H1 2026) of Energy Ombudsman disputes; complaints up 16%.
* FACT (S12): Citizens Advice — billing is the most common energy issue; back-bills average ~£200 and affect up to 2.1m households/yr; 6% of smart-meter consumers still receive estimated bills.
* FACT (S13): Ofgem consumer satisfaction survey — 82% (Jan 2026) satisfied with ease of understanding bills. **Counter-evidence.**
* FACT (S14): Ofgem lower-standing-charge tariff pilot from June 2026 (EDF, E.ON, Octopus, British Gas); Ofgem says it is unlikely to reduce bills overall because unit rates are higher.
* INFERENCE: Every bill in GB decomposes into the same primitives — days × standing charge + kWh × unit rate(s) ± adjustments + VAT. That makes a deterministic, supplier-agnostic calculator feasible without supplier integrations.
* INFERENCE: In Q4 2026 the ex-VAT electricity price *rose* (≈24.87p → 26.32p unit rate) while the VAT removal pulled the customer-visible price roughly flat. Bills spanning 1 October will show split lines, VAT disappearing, and a changed standing charge — a textbook "why did my bill change?" moment.
  * CALCULATION: 26.11 / 1.05 = 24.867 p/kWh ex-VAT (Jul–Sep) vs 26.32 p/kWh (Oct–Dec, no VAT) → +5.8% ex-VAT. Standing: 57.19/1.05 = 54.467 → 54.83 p/day (+0.7% ex-VAT, −4.1% customer-visible).

**Why GB wins:** one national regulatory structure with four scheduled change events per year, a live VAT change, very high billing-dispute volume, English-language, bills with standard primitives. Weakness: strong supplier apps (Octopus), comparison sites, MSE; low stated confusion.

## USA — California (PG&E) runner-up

* FACT (S15): PG&E introduced a Base Services Charge (~$24/month; lower for CARE/FERA) from March 2026, lowering per-kWh prices by ~5–7¢; E-TOU-C peak 4–9pm daily.
* INFERENCE: Highest per-kWh pain and TOU complexity in the US, but tariffs include baseline allowances, climate zones, CARE/FERA, CCA generation vs PG&E delivery split, NEM variants. A correct calculator is a large ongoing data project; errors are more likely. Single-utility focus also means strong utility-app competition (PG&E has usage/rate comparison tools).

## USA — national

* FACT (S16): OpenEI Utility Rate Database covers >3,700 US utilities; OpenEI updates ~150 utilities (70% of load) annually.
* INFERENCE: Fragmentation makes "any US bill" infeasible for a deterministic V1; this is exactly the prohibited global/universal app.

## Canada — Ontario

* FACT (S17): OEB sets RPP prices (TOU, ULO, Tiered) province-wide; Nov 2025–Apr 2026 schedule; Ontario Electricity Rebate rose from 13.1% to 23.5% from 1 Nov 2025.
* INFERENCE: Commodity is standardised, but delivery/regulatory charges vary by ~60 local distribution companies; two price changes per year (fewer triggers); smaller market; French localisation needed for national expansion. Strong second market.

## Ireland / Germany / Spain

* INFERENCE: Ireland — smaller market, unregulated retail prices, PSO levy changes; Germany — low smart-meter penetration, annual Abschlag (similar to UK DD) pain, German localisation; Spain — PVPC regulated hourly tariff has good data (REE) but hourly pricing is complex and Spanish localisation needed. Deferred.

## Final market definition

| Field | Value |
|---|---|
| COUNTRY | United Kingdom — **Great Britain only** (England, Scotland, Wales). Northern Ireland excluded (different market, VAT stays 5%) |
| REGION | All 14 GB electricity regions; region only used for reference context (rates are taken from the user's own bill) |
| CUSTOMER | Household bill payer on a credit meter (Direct Debit, on receipt of bill, or standard credit) who receives electricity bills/statements; SVT or fixed; single-rate or Economy 7 |
| TARIFF MODEL | Standing charge (p/day) + unit rate (p/kWh), or two-register day/night (Economy 7) + VAT (0% or 5%) ± credits/adjustments; rate changes mid-period supported as rate periods |
| WHY THIS MARKET | Standard bill primitives, quarterly regulated changes, live VAT change, highest billing-complaint volume among candidates, English |
| AVAILABLE OFFICIAL DATA | Ofgem price cap levels (quarterly, by region and payment method), Ofgem TDCVs, DESNZ smart-meter statistics, HMRC VAT guidance |
| COMPETITORS | Supplier apps (Octopus, OVO, EDF, British Gas, E.ON), Bright (Hildebrand/Glowmarkt), MSE & Uswitch calculators/comparisons, Loop (acquired by Procode Dec 2024) |
| CURRENT ALTERNATIVES | Calling supplier, MSE forum, Reddit (r/UKPersonalFinance, r/OctopusEnergy), spreadsheets, Citizens Advice |
| DISTRIBUTION | Search around price-cap dates and "why has my electricity bill gone up", money creators, MSE forum/Reddit, consumer-advice partners |
| RISKS | Low stated confusion; supplier apps improving; episodic usage; parsing variety across ~20 suppliers; data verification blocked in this environment |

Excluded: prepayment meters (different payment mechanics), dual-fuel gas lines (V1 electricity only — gas is a clear V1.1 candidate), business customers, solar export/SEG, EV/heat-pump TOU tariffs like Agile (half-hourly; requires smart data).
