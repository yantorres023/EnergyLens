# EnergyLens (working name)

**Why did my electricity bill change?** An offline Flutter app for households in Great Britain that recalculates electricity bills from the figures on them and splits the change between two bills into exact, pound-denominated reasons (period length, daily usage, unit price, standing charge, VAT, credits), then verifies one chosen action on the next bill.

Start with **[RELEASE_REPORT.md](RELEASE_REPORT.md)**.

| Area | Where |
|---|---|
| Research & decision | `docs/research/` (MARKET_COMPARISON, THESIS_COMPARISON, EVIDENCE_LEDGER, RED_TEAM, SOURCES, TARIFF_DATA, VALIDATION_DEBT) |
| Product | `docs/product/` (PRODUCT_STRATEGY, PRD, UX_SPEC, ANALYTICS, BRAND) |
| Engineering | `docs/engineering/` (TECHNICAL_PLAN, SECURITY) |
| Business | `docs/business/` (MONETIZATION, DISTRIBUTION) |
| App | `app/` (Flutter) |
| Store prep | `release/` · Legal drafts: `legal/` · Landing page: `landing/index.html` |

## Develop

```bash
cd app
flutter pub get
dart format --output=none --set-exit-if-changed lib test tool
flutter analyze
dart run tool/validate_tariffs.dart
TZ=Europe/London flutter test          # unit, DB, widget and golden tests
flutter run
```

CI (`.github/workflows/ci.yml`) runs the checks, builds Android APK/AAB and an unsigned iOS build.
