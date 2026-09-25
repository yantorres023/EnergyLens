# Tariff data

## Principle

EnergyLens **never** takes a user's bill rates from reference data. Bills are calculated only from the unit rate(s), standing charge and VAT the user enters (or confirms after paste) from *their own bill*. Bundled data is a labelled **reference** used for:

1. "For context: the Ofgem price cap" on the bill page (single-rate bills only).
2. The ESTIMATED price-cap change preview (standard variable tariff households only).
3. The ESTIMATED Economy 7 break-even (vs the GB-average single rate).

If the data is stale, invalid or missing, these three features are hidden and the app says why. Core calculation, comparison, actions and Direct Debit check are unaffected.

## File

`app/assets/data/gb_price_cap_electricity.json` — schema v1.

| Field | Meaning |
|---|---|
| `tariff_id` | Unique, stable (`gb-cap-elec-avg-dd-single-2026q4`) |
| `series_id` | Versions of the same thing over time; versions in a series must not overlap and are expected to be contiguous |
| `provider` / `source_authority` | "Ofgem default tariff cap (GB average)" / "Ofgem" |
| `region` | `GB_AVERAGE` (regional rows not yet added — see gaps) |
| `payment_method`, `meter_type` | `direct_debit`, `single_rate` |
| `currency` | `GBP` (validated) |
| `effective_from` / `effective_to` | Inclusive ISO dates |
| `standing_charge` | p/day **as published** (VAT-inclusive), decimal string (no floats) |
| `unit_rates[]` | `{register, rate}` p/kWh as published |
| `time_of_use_periods` | Reserved (empty) for future TOU tariffs |
| `vat_basis_points` | VAT included in the published figures: 500 = 5%, 0 = 0% |
| `fees` | Reserved |
| `source_url` | https, official page |
| `last_verified_at` | Date the row was last checked |
| `verification_status` | `verified_official` or `search_extract` |

Ex-VAT values are derived in code (`TariffVersion.unitRateExVatMilliPence`), never stored.

## Current contents (all `search_extract`)

| Period | Unit rate p/kWh | Standing p/day | VAT in figures | Source |
|---|---|---|---|---|
| 2026-01-01 → 2026-03-31 | 27.69 | 54.75 | 5% | S05 |
| 2026-04-01 → 2026-06-30 | 24.67 | 57.21 | 5% | S06 |
| 2026-07-01 → 2026-09-30 | 26.11 | 57.19 | 5% | S07 |
| 2026-10-01 → 2026-12-31 | 26.32 | 54.83 | 0% | S01, S03 |

`search_extract` means the numbers were read from search-engine extracts of the official Ofgem pages because direct access was blocked in the build environment. The app discloses this ("awaiting line-by-line verification"). **HUMAN_ACTION_REQUIRED:** verify against Ofgem's published tables and flip to `verified_official`.

## Integrity rules (enforced in `test/domain/tariff_data_test.dart` and `tool/validate_tariffs.dart`, run in CI)

* unique `tariff_id`
* `effective_to` ≥ `effective_from`; valid calendar dates
* no overlapping versions within a series; contiguity tested
* https `source_url`, non-empty `source_authority`, known `verification_status`
* currency GBP
* non-negative rates; plausibility bounds (unit ≤ 100 p/kWh, standing ≤ 200 p/day) to catch unit mistakes
* VAT 0–20%
* staleness: nothing covering today, or last verified > 120 days ago → stale → not used
* CI warns 21 days before data runs out

## Update procedure (quarterly)

1. Ofgem announces the next cap ~5 weeks before the quarter (late Feb, May, Aug, Nov).
2. Add a new version to the series with `verification_status: verified_official` after checking the official table.
3. `dart run tool/validate_tariffs.dart && flutter test`.
4. Ship an app update before the effective date.

## Gaps

* No regional (14 regions) or payment-method rows; no Economy 7 cap rows.
* No 2027 Q1 row yet (Ofgem publishes in late November 2026) → the app's reference becomes stale on 1 Jan 2027 without an update. This is intentional behaviour, not a bug.
* Remote data updates are not implemented (no backend by design). Future: signed JSON fetched from a static host, same validator, same staleness rules.
