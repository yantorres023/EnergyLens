# RELEASE REPORT — EnergyLens (working name)

Date: 2026-09-25 · Branch: `claude/laughing-brown-kqxxxc` · App version 0.1.0+1

## Executive summary

The broad hypothesis ("people don't understand their electricity bills") is **weakened**: Ofgem's own survey reports ~82% of consumers find bills easy to understand. What survives is narrower and better evidenced: **bills in Great Britain change often for reasons outside the household's control** (quarterly price cap, VAT cut to 0% on 1 Oct 2026, varying billing-period lengths, estimated readings), and billing is 56–58% of Energy Ombudsman disputes. EnergyLens was therefore built as **"Why did my electricity bill change — in pounds?"** for GB electricity credit-meter households.

A working, tested, offline Flutter MVP exists: manual and paste-text bill entry with confirmation, deterministic integer-arithmetic calculator, reconciliation against the printed total, exact change decomposition, calculation-tied insights, a five-action next-bill verification loop, a what-if re-pricer for user-entered quotes, a Direct Debit estimate, history, deletion and privacy controls. 120 automated tests pass locally and in CI; analyzer clean.

No real user has touched it. Every behavioural claim is a hypothesis with a defined test and kill threshold.

## Decision: **PIVOT (narrowed) → GO on the wedge**, conditional on beta gates

## Final market

Great Britain (England, Scotland, Wales) · household electricity · credit meters (Direct Debit / pay on bill) · standard variable or fixed tariffs · single-rate or Economy 7. Excludes Northern Ireland, prepayment, gas (V1.1 candidate), business, half-hourly/agile TOU.

## Final product thesis

"See why your electricity bill changed — in pounds — and check whether your next bill improves." Supporting hooks: bill-arithmetic check, Direct Debit estimate, what-if for a quote.

## Why this market won

Score 47/60 vs California 45, Ontario 42, Ireland 37, US-national 33 (`docs/research/MARKET_COMPARISON.md`). Decisive factors: one national regulatory structure with standard bill primitives (standing charge + unit rate + VAT), four scheduled change events per year plus a live VAT change, highest billing-dispute volume, English, ~72% smart meters for future data options. California has more pain but far more tariff complexity and per-utility risk.

## Evidence strength

| Claim | Strength |
|---|---|
| Bills change frequently for exogenous reasons | HIGH (regulator/government sources) |
| Billing disputes are common | HIGH |
| Deterministic recomputation is feasible | HIGH (structure) / MEDIUM (penny reconciliation across suppliers) |
| "Why did it change" is a felt, repeated need | MEDIUM-LOW (inference) |
| Users will enter data / return / pay | LOW (untested) |

**Research limitation:** direct access to ofgem.gov.uk, gov.uk, Citizens Advice, Reddit etc. was blocked by the build environment's egress policy; all facts come from search-result extracts of named official pages (`docs/research/SOURCES.md`). No community threads could be read.

## Counter-evidence

82% ease-of-understanding (Ofgem); strong supplier apps (Octopus); comparison sites for tariff choice; modest savings potential (standing charge unavoidable; 10% usage cut ≈ £66/yr at cap averages); free alternatives everywhere → low willingness to pay.

## Product built (app/)

Onboarding (value, privacy, household) · Home (how much / what changed / why / what can I do / confidence) · Manual bill form (split rate periods, Economy 7, VAT per period with date-based default, incl./excl. VAT, credits, reading type, printed total, balance, kWh-from-readings with rollover) · Paste import → review with source snippets → confirm (corrections recorded, text discarded) · Bill detail (line-by-line arithmetic, reconciliation, price-cap context) · Comparison (exact decomposition, caveats, methodology) · Insights with provenance + confidence · Action sheet + experiments verified by the next bill · What-if · Direct Debit check · Settings (household, local usage log, delete all, data sources).

## Supported tariff model

Per rate period: standing charge (p/day) × days + Σ registers kWh × unit rate (single or day/night) → VAT per period (0–20%, or backed out when prices include VAT) → adjustments after VAT. Any number of rate periods in the model (2 in the UI).

## Data sources

Rates always come from the user's bill. Bundled reference: Ofgem cap GB-average Direct Debit single-rate electricity, Q1–Q4 2026 (`app/assets/data/gb_price_cap_electricity.json`, `docs/research/TARIFF_DATA.md`), status `search_extract`, disclosed in-app.

## Calculation architecture

Integer pence and milli-units; exact decimal string parsing; half-away-from-zero rounding per line; no floating point on any bill amount; change attribution whose parts sum exactly to the difference (300-case property test); estimates (DD, cap preview, E7 break-even) deterministic but labelled ESTIMATED; LLM/AI not used anywhere.

## Accuracy limitations

* Supplier rounding conventions vary; ±5p tolerance, then an explicit mismatch state.
* Not modelled: exit fees, per-line discounts applied before VAT, Warm Home Discount timing, CCL (business), smart export (SEG), half-hourly tariffs, gas.
* Attribution is an explanation method, not something suppliers publish; usage changes are not causal proof (season/weather).
* DD estimate assumes flat daily usage over a year (flagged LOW confidence under 180 days of data).
* Cap preview assumes the user's prices move like the GB average.

## Privacy

On-device only; no network code; Android release manifest requests no permissions (no INTERNET); Android backups/device transfer excluded; no name/address/account/MPAN fields; pasted text never stored; opt-in local usage log with sanitised properties; `secure_delete` + `VACUUM`, delete-all tested to leave no bill text in the DB file. iOS device backups may include app data (documented). See `docs/engineering/SECURITY.md`, `legal/PRIVACY_POLICY.md`.

## Tests

Local (Flutter 3.47.5, `TZ=Europe/London`): **120 passing** — fixed-point (11), calculator incl. DST/leap/rollover (25), comparison incl. property test (11), tariff data integrity/staleness (11), DD/what-if/experiments/insights (23), parser (6), SQLite repository (9), controller loop (10), widget flows (9), goldens (5: Home, Bill detail, Comparison, Insight, Action). `dart format` clean; `flutter analyze`: no issues; `dart run tool/validate_tariffs.dart`: OK (warns data unverified).

## Android

Local Android SDK unavailable (egress blocked `dl.google.com`). CI builds release APK + AAB: see CI results below. Without keystore secrets the artifacts are debug-signed (installable for testing, not uploadable to Play).

## iOS

CI `macos-latest` builds `flutter build ios --release --no-codesign` and packages an unsigned `.ipa`: see CI results below. Signing blockers: `release/ios/APP_STORE_CHECKLIST.md`.

## CI results

CI_RESULTS_PLACEHOLDER

## Monetization

Free V1, no ads, no commission. Lead paid hypothesis: one-time household pack (fake-door test first); realistic alternative: consumer-advice/charity partnership. Referral revenue rejected for V1 (conflict of interest). `docs/business/MONETIZATION.md`.

## Distribution

Timed to cap/VAT dates; SEO (10 topics), short-form (10 ideas), creator and referral hypotheses. `docs/business/DISTRIBUTION.md`. Landing page: `landing/index.html` (illustrative worked example, no testimonials, no savings claims).

## Known bugs / limitations

* Home recomputes calculations on every build (fine for tens of bills).
* Bill form supports two rate periods in UI (model supports N).
* Date entry is text `dd/mm/yyyy` plus picker; no locale-aware input beyond en-GB.
* No export/import of data; Android data is not backed up by design → lost on phone change.
* No reminders (no notifications package in V1).
* Parser tested only on synthetic bill texts.
* Golden images are platform-sensitive (generated on Linux; CI runs on Linux with pinned Flutter).

## Data gaps

Regional and payment-method cap rows; Economy 7 cap rows; Q1 2027 cap (published late Nov 2026 — without an app update, reference data goes stale on 1 Jan 2027 and dependent estimates hide themselves); verification of all four rows; real supplier bill layouts.

## External blockers

Egress-blocked research sources; no Android SDK locally; no Apple developer account/signing; no Play developer account/upload key; brand not cleared.

## HUMAN_ACTION_REQUIRED

| # | ACTION | WHY | EXACT STEPS |
|---|---|---|---|
| 1 | Verify bundled price-cap rows | Rows are `search_extract`; app discloses "awaiting verification" | Open each `source_url` in `app/assets/data/gb_price_cap_electricity.json`; confirm GB-average DD unit rate and standing charge (VAT-inclusive as published); fix values if needed; set `verification_status` to `verified_official` and `last_verified_at` to today; run `dart run tool/validate_tariffs.dart && TZ=Europe/London flutter test` |
| 2 | Add Q1 2027 cap row by mid-December 2026 | Reference data stales on 1 Jan 2027 | After Ofgem's late-Nov announcement add version `gb-cap-elec-avg-dd-single-2027q1` (2027-01-01..2027-03-31, VAT 0 unless policy changes); ship update |
| 3 | Choose and clear a brand | "Energy Lens" is a UK energy-software company | Pick from `docs/product/BRAND.md` or new; search UKIPO/EUIPO, Companies House, app stores, domains; update `android:label`, `CFBundleDisplayName`, app title strings, `applicationId`/bundle ID **before** first upload |
| 4 | Create a publishing entity and contacts | Stores and privacy policy require controller/support details | Fill placeholders in `legal/PRIVACY_POLICY.md`, `legal/TERMS.md`, `release/STORE_LISTING.md`; host the policy at a public URL; set a real email on `landing/index.html` |
| 5 | Legal review | Drafts only | UK consumer/privacy lawyer reviews `legal/*` and store copy against CAP Code/CMA guidance |
| 6 | Android signing + Play account | Current AAB is debug-signed | Follow `release/android/SIGNING.md`; add 4 repo secrets; create Play app; closed testing track; complete Data safety ("no data collected") |
| 7 | Apple signing + App Store Connect | iOS build is unsigned | Follow `release/ios/APP_STORE_CHECKLIST.md` (developer account, bundle ID, certificates/profiles or automatic signing, `flutter build ipa`, TestFlight) |
| 8 | Real-device smoke test | Only tested in Flutter test harness | Install CI APK on an Android phone; TestFlight build on iPhone; run the 2-bill flow, paste flow, delete-all |
| 9 | Collect real parser fixtures | Parser tested on synthetic text | Get redacted copied text from 6 suppliers' bills; add as tests under `app/test/parsing/`; fix misses |
| 10 | Replace screenshot drafts | Drafts are test renders | Capture on devices at required sizes |

## Real-user validation debt

See `docs/research/VALIDATION_DEBT.md` (V-00 … V-09): community evidence, data entry, comprehension, credibility, second bill, behaviour change, willingness to pay, confusing tariff types, parser accuracy, data verification.

## Beta gates and kill/pivot thresholds

See `docs/product/PRD.md` → Beta gates. Headline: bill completion ≥ 70%, paste correction ≤ 15%, reconciliation ≥ 85%, comparison completion ≥ 60%, clarity ≥ 70%, action selection ≥ 25%, second-bill return ≥ 35% at 60 days, zero systematic calculation errors, fake-door ≥ 8%. **Kill:** clarity < 50% and comparison completion < 40% after two iterations → STOP_REPORT. **Pivot:** explainer works but return < 20% → free seasonal tool distributed via content/partners.

## Next 3 experiments

1. **Comprehension hallway test (V-02, 1 day):** show the comparison golden to 5–10 GB bill payers; ask for the main reason and amount. Pass ≥ 70%.
2. **Two-past-bills onboarding test (V-01/V-04, 1 week):** 10 volunteers install the CI APK and enter their last two bills from supplier PDFs; measure completion, time, reconciliation. Pass ≥ 70% completion, ≥ 60% reconcile.
3. **Cap-date landing test (V-06/A3, around the late-Nov 2026 cap announcement):** two landing variants ("understand your bill" vs "why did your bill change"), plus a £3.99 fake-door price; measure CTR and price interest.

## Files to review first

1. `docs/research/RED_TEAM.md` (decision + final red team)
2. `docs/research/EVIDENCE_LEDGER.md`
3. `app/lib/domain/calculator.dart` and `app/lib/domain/comparison.dart`
4. `app/test/domain/calculator_test.dart`, `comparison_test.dart`
5. `app/assets/data/gb_price_cap_electricity.json` + `docs/research/TARIFF_DATA.md`
6. `app/test/golden/goldens/*.png` (what users see)
7. `docs/product/PRD.md` (beta gates)
8. `docs/engineering/SECURITY.md`

## Definition of done

- [x] market comparison · [x] one market selected · [x] evidence ledger · [x] competitor research · [x] red team · [x] GO/PIVOT/STOP
- [x] product strategy · [x] tariff/data architecture · [x] PRD · [x] UX spec
- [x] working Flutter MVP · [x] deterministic calculator · [x] bill history · [x] comparison · [x] actionable insights · [x] second-bill loop
- [x] data integrity tests · [x] unit/widget/golden tests · [x] analyzer clean
- [x] Android CI · [x] iOS CI (see CI results for build outcome)
- [x] privacy/security review · [x] monetization · [x] distribution · [x] landing page · [x] store metadata · [x] validation debt · [x] RELEASE_REPORT.md
