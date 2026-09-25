# UX spec

Principle: the user should never need energy terminology. Every screen answers, in order: **HOW MUCH? → WHAT CHANGED? → WHY? → WHAT CAN I DO? → HOW CONFIDENT IS THIS?**

## Information architecture

```
Onboarding (3 steps) ─► Home
Home
 ├─ Latest bill card ─────────► Bill detail ─► Edit / Delete / What if?
 ├─ Change vs previous card ──► Comparison ("What changed")
 ├─ Insights (top 3) ─► "What can I do?" sheet ─► Start action
 ├─ Trying now (active actions)
 ├─ Direct Debit card ────────► Direct Debit check
 ├─ Your bills (history) ─────► Bill detail
 ├─ Past actions (results)
 └─ FAB "Add bill" ─► Type in figures | Paste text ─► Review parsed ─► Save
Settings (gear): household, privacy, usage log, delete all, data sources, about
```

## Screens

**Onboarding.** (1) What it does + who it's for + independence/no-guarantee note. (2) Privacy: on-device, no identifiers, pasted text discarded; usage-log switch, *off by default*. (3) Household choices as chips, "Not sure" allowed; optional DD amount; optional region.

**Home** (golden: `app/test/golden/goldens/home.png`). Latest bill total in large type, period, days, kWh/day, provenance chip, reconciliation chip. Change card: "£11.25 more" and the top 3 drivers with signed amounts. If only one bill: prompt to add the previous one. Insights (max 3). Active actions. DD card if paying by DD. Stale-data banner if applicable. History.

**Add bill (manual).** One scrolling form in bill order: dates → Economy 7 switch → "Prices changed during this bill" switch → kWh/rate/standing/VAT → "prices include VAT" switch → reading type → credits → optional printed total and balance → supplier name. Helpers: calendar pickers, kWh-from-readings dialog (with rollover), inline field help ("Price per kWh in pence, e.g. 26.32"). VAT defaults to 0% for periods starting 1 Oct 2026–31 Mar 2027, else 5% (user can change). Validation catches pounds-for-pence slips, impossible dates, negatives. Mismatch with printed total → dialog: "Check again" / "Save anyway".

**Paste import.** Instructions, privacy note, text box, "Find the figures". Then the same form titled "Check what we found", with a banner, parser notes (e.g. "found 2 different unit rates… add a second rate period"), and each prefilled field showing a "From pasted text" chip and the quoted source snippet. Nothing is calculated until the user taps "Confirm and save".

**Bill detail** (golden: `bill_detail.png`). Total, days, kWh, £/day, chips (Calculated; Meter reading/Estimate). Reconciliation banner. "How your bill adds up": each line with its arithmetic (31 days × 54.83p). Comparison summary. Insights. "For context: the Ofgem price cap" (single-rate, fresh data only). "What if I had a different tariff?".

**Comparison** (golden: `comparison.png`). Headline "£11.25 more than last time", %, two bill cards (total, dates, days, kWh/day, £/day). "Why": each effect with a plain label including the before/after figures, a signed amount, a diverging bar (red = added, green = saved), one-sentence explanation. "These add up to +£11.25" with Calculated chip. "Keep in mind" caveats. "How we worked this out".

**Insight card** (golden: `insight.png`). Title with the number, body, provenance chip, confidence text, "What can I do?" when there's a linked action.

**Action sheet** (golden: `action.png`). Title, how-to, "How we'll check", links to What if?/DD check where relevant, "I'll try this".

**What if?** Inputs for the quote (single or day/night, incl./excl. VAT), result card with both totals and a one-sentence comparison, caveat about one-bill seasonality, and the no-commission statement.

**Direct Debit check.** Editable monthly amount, verdict ("Looks about right" / "May be too low" / "May be higher than needed"), Estimate chip, both monthly figures, the formula in words, a confidence banner, and "your supplier sets your DD; ask them to review".

## Copy rules

* Numbers first, then meaning. Pounds with pence. kWh with one decimal per day.
* Never "save", "guaranteed", "always", "official calculator". Use "added/saved compared with your previous bill" only for historic calculated effects.
* Every estimate says "estimate" and why.
* No blame: "not proof that anything went wrong".

## Accessibility

Material 3 components, semantic headers on section titles, provenance chips expose "Source: …" semantics, colour is never the only signal (signed amounts and words accompany red/green), system text scaling respected (no fixed heights on text), dark theme supported.
