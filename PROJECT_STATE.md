# PROJECT_STATE

Last updated: 2026-09-25 (autonomous build session)

## Environment (as inspected at start)

| Item | State |
|---|---|
| Repository | Empty (no commits) on branch `claude/laughing-brown-kqxxxc` |
| Flutter | Not preinstalled → installed Flutter 3.47.5 stable (Dart 3.13.4) to `/opt/flutter-sdk` |
| Android SDK | **Unavailable**. `dl.google.com` is blocked by the session egress policy → Android builds delegated to GitHub Actions |
| Xcode / macOS | Unavailable (Linux container) → iOS build delegated to GitHub Actions `macos-latest` |
| SQLite | `libsqlite3.so` present → DB tests run locally through `sqflite_common_ffi` |
| Web research | `WebSearch` works. Direct page fetch (`WebFetch`/`curl`) of ofgem.gov.uk, gov.uk, citizensadvice.org.uk, reddit.com, openei.org **blocked** by egress policy. All figures come from search-result extracts of the named pages and are flagged `search_extract` / "verify directly" in data and docs |

## Phase status

| Phase | Status | Output |
|---|---|---|
| 1. Inspect environment | Done | this file |
| 2. Market research & comparison | Done | `docs/research/MARKET_COMPARISON.md` |
| 3. Product thesis comparison | Done | `docs/research/THESIS_COMPARISON.md` |
| 4. Evidence ledger | Done | `docs/research/EVIDENCE_LEDGER.md` |
| 5. Red team + decision | Done — **PIVOT (narrowed) → GO on wedge** | `docs/research/RED_TEAM.md` |
| 6. Product/UX/tech docs | Done | `docs/product/*`, `docs/engineering/*` |
| 7. Flutter MVP | Done | `app/` |
| 8. Tests / CI | 120 tests pass locally and in CI; format/analyze clean | `.github/workflows/ci.yml` |
| 9. Release prep | Done (unsigned) | `release/`, `legal/`, `landing/`, `RELEASE_REPORT.md` |

## Decision summary

* Market: **Great Britain (England, Scotland, Wales), household electricity on credit meters, standard variable (price-capped) or fixed tariffs, single-rate or Economy 7.**
* Thesis: generic "bill explainer" is weak (Ofgem: ~82% say bills are easy to understand). Surviving wedge: **"Why did my electricity bill change?"** — deterministic change decomposition + reconciliation check + "is my Direct Debit right?" + next-bill verification of one chosen action.
* Architecture: Flutter, local SQLite, no account, no backend, no paid AI, deterministic integer-arithmetic calculator, bundled versioned GB price-cap reference data used only as a labelled reference, never as the user's bill rate.

## Where to start

`RELEASE_REPORT.md` → HUMAN_ACTION_REQUIRED.
