# Validation debt

Nothing in this project has been validated with real users. Each item below is a debt to be paid before scaling.

### V-00 Community evidence gap
* HYPOTHESIS: Reddit/MSE threads show the "why did my bill change" question is frequent and unresolved by supplier apps.
* TEST: Manually review 100 recent threads (r/UKPersonalFinance, r/OctopusEnergy, MSE Energy board) around the Oct 2026 bills; code each by cause and whether an answer quantified the change.
* METRIC: % threads whose question is "why did it change" and % answered with numbers.
* PASS: ≥ 30% change-questions, ≤ 30% quantified answers. FAIL: < 10% change-questions.
* CHEAPEST TEST: 3 hours of reading (blocked in the build environment).

### V-01 Can users correctly enter/confirm bill data?
* HYPOTHESIS: A GB bill payer can complete the form in < 3 minutes with ≤ 1 error.
* TEST: 5 unmoderated remote sessions with the APK/TestFlight and their own bill.
* METRIC: completion rate, time, reconciliation match rate.
* PASS: ≥ 4/5 complete, ≥ 3/5 reconcile. FAIL: ≤ 2/5 complete.
* CHEAPEST TEST: 5 friends-of-friends with their latest bill, screen-recorded.

### V-02 Do they understand the explanation?
* HYPOTHESIS: After viewing the comparison, users can state the main reason and its £ amount.
* TEST: Show the comparison; ask "Why did your bill change?"
* METRIC: correct main driver + amount (±£1).
* PASS: ≥ 70%. FAIL: < 50% (product failure).
* CHEAPEST TEST: Golden images as a clickable mock in a 5-person hallway test.

### V-03 Do recommendations feel credible?
* HYPOTHESIS: Actions tied to numbers feel more credible than generic tips.
* TEST: A/B the action sheet vs a generic tips list.
* METRIC: "I'd try this" rate; credibility rating.
* PASS: +20% relative. FAIL: no difference.
* CHEAPEST TEST: Two static mocks in a survey panel (n≈50).

### V-04 Will they add a second bill?
* HYPOTHESIS: ≥ 35% of users who add one bill add another within 60 days.
* TEST: Beta cohort.
* METRIC: `next_bill_added` within 60 days.
* PASS: ≥ 35%. FAIL: < 20% (episodic).
* CHEAPEST TEST: Ask beta users to add *two past bills* at install (most suppliers keep 12+ months of PDFs) — measures willingness without waiting.

### V-05 Does the product change behaviour?
* HYPOTHESIS: ≥ 25% of users with a comparison start an action; ≥ 50% of those complete it with a next bill.
* TEST: Beta cohort; `action_selected`, `savings_experiment_completed`.
* PASS/FAIL: per PRD gates.
* CHEAPEST TEST: Beta only; caveat — outcome is confounded by season.

### V-06 Will they pay?
* HYPOTHESIS: ≥ 8% of activated users tap a £3.99 one-time unlock.
* TEST: Fake door.
* PASS: ≥ 8%. FAIL: < 3%.
* CHEAPEST TEST: Landing page price test before building payments.

### V-07 Which tariff models are most confusing?
* HYPOTHESIS: Split-period bills (cap/VAT change mid-bill) and Economy 7 cause most mismatches and questions.
* TEST: Reconciliation rate and corrections by bill type in beta.
* METRIC: mismatch rate by `periods` and `e7`.
* PASS: Identify the top type to prioritise. FAIL: n/a.
* CHEAPEST TEST: Collect 20 anonymised real bills (figures only) from volunteers and run them through the calculator.

### V-08 Does the paste parser work on real supplier layouts?
* HYPOTHESIS: ≥ 70% of parsed fields are correct across the top 6 suppliers.
* TEST: Real copied text from Octopus, British Gas, EDF, E.ON Next, OVO, Scottish Power bills (with personal details removed) as test fixtures.
* PASS: ≥ 70% field accuracy. FAIL: < 50% → hide paste option.
* CHEAPEST TEST: Ask 6 volunteers for redacted text.

### V-09 Is the reference data correct?
* HYPOTHESIS: The four bundled cap rows match Ofgem's published tables.
* TEST: Human check against Ofgem pages (blocked in build environment).
* PASS: exact match → `verified_official`. FAIL: fix data.
* CHEAPEST TEST: 15 minutes.
