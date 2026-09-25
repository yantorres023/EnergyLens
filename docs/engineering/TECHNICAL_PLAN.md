# Technical plan

## Stack

Flutter 3.47.5 / Dart 3.13 · Material 3 · `sqflite` (device) / `sqflite_common_ffi` (tests) · no backend, no network, no paid APIs, no AI.

## Layout

```
app/
  lib/
    domain/        pure Dart, no Flutter imports — all arithmetic lives here
      fixed_point.dart     integer pence / milli-units, rounding, exact decimal parsing
      dates.dart           UTC calendar dates, inclusive day counts (DST-safe)
      models.dart          Household, Bill, RatePeriod, RegisterUsage, Adjustment,
                           UserCorrection, SavingsExperiment, AppSettings, Provenance
      calculator.dart      BillCalculator, reconciliation, warnings, MeterConsumption
      comparison.dart      BillComparison (exact change decomposition)
      insights.dart        InsightEngine
      experiments.dart     action catalogue, ExperimentEngine (next-bill verification)
      what_if.dart         re-price a bill at user-entered rates
      direct_debit.dart    DD adequacy estimate
      tariff_reference.dart versioned reference dataset, validation, staleness
    parsing/bill_text_parser.dart   offline heuristic parser for pasted text
    data/          Repository interface, InMemoryRepository, SqliteRepository
    app/           AppController (ChangeNotifier), local Analytics
    ui/            screens and widgets; copy.dart holds all explanatory text
  assets/data/gb_price_cap_electricity.json
  tool/validate_tariffs.dart
  test/            unit, db, controller, widget flows, goldens
```

## Data model

`Household` (no identifiers) 1—* `Bill` 1—* `RatePeriod` 1—* `RegisterUsage`; `Bill` *— `Adjustment`, `UserCorrection`, `fieldProvenance`; `SavingsExperiment` references baseline/result bill ids; `AppSettings`; `events`. The brief's `BillingPeriod` = `RatePeriod`, `Charge` = computed `CalcLine`, `ConsumptionReading` = `MeterConsumption` + `readingType`, `Tariff`/`TariffVersion` = `TariffDataset`/`TariffVersion`, `ParsedField` = parser output (not persisted), `Action` = `ActionDefinition` catalogue.

Storage: SQLite tables `settings`, `households`, `bills`, `experiments`, `events`; JSON document per row plus indexed columns. Schema versioned (`SqliteRepository.schemaVersion`, `_migrate`). `PRAGMA secure_delete = ON`; delete-all runs `VACUUM`.

## Calculation architecture

* Inputs are exact decimals parsed from strings into integers: kWh ×1000, pence ×1000. No `double` on any path that produces a bill amount.
* Line amount = round_half_away_from_zero(qty_milli × rate_milli / 10⁶) pence.
* VAT per rate period on the rounded lines (or backed out when prices include VAT, with exact residual allocation).
* Adjustments applied after VAT.
* Reconciliation: |calculated − printed| ≤ 5p ⇒ matches.
* Comparison: algebraic decomposition (see `comparison.dart` doc comment) whose effects sum exactly to the integer difference; residual rounding goes to the largest effect. Doubles are used only inside the attribution split, never for totals. A 300-case property test checks exact summation.
* Projections (DD, cap preview, E7 break-even) are deterministic but labelled ESTIMATED.

## Parsing

IMPORT (paste) → PARSE (regex heuristics; ignores projections like "annual consumption") → SHOW (prefilled form + snippet + chip) → CONFIRM/CORRECT → CALCULATE. The parser has no fields for identifiers; pasted text is truncated at 50k chars, held only in widget memory, cleared after parsing. OCR was rejected for V1 (A6).

## Performance

No media is stored or decoded; bills are small JSON rows. Parsing is linear in text length and capped. Home recomputes calculations on build — trivial for tens of bills; memoise if histories exceed ~200 bills.

## Testing

`TZ=Europe/London flutter test`: fixed-point, calculator known-answer tests, comparison (incl. property test), tariff data integrity & staleness, DD, what-if, experiments, insights, parser, SQLite repository (round trip, cascade delete, delete-all leaves no text in file, reopen), controller loop, widget flows (onboarding, 2-bill comparison, action loop, validation, mismatch dialog, paste→correct, what-if, DD, deletion), goldens (Home, Bill detail, Comparison, Insight, Action) rendered with Roboto.

## CI (`.github/workflows/ci.yml`)

1. ubuntu: format check, analyze, tariff validation, tests (+ goldens).
2. ubuntu: Android `flutter build apk --release` and `appbundle` (release-signed when keystore secrets exist; otherwise debug-signed and not uploadable).
3. macos: `flutter build ios --release --no-codesign`, zipped unsigned `.ipa` artifact.

## Future architecture (not built)

* Remote reference-data updates: static signed JSON + same validator + same staleness gate; app keeps bundled fallback.
* Gas (dual fuel): add `fuel` to `Bill`; calculator unchanged.
* Local reminders at the user's bill cadence (`flutter_local_notifications`).
* Optional AI explanation of unusual charge lines — never used for arithmetic; output treated like parsed text (untrusted, user-confirmed).
