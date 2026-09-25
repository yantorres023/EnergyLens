# Analytics

## Policy

V1 contains **no network code and no third-party SDKs**. Analytics is a *local, opt-in* event log in the on-device database (`events` table), off by default, viewable and clearable in Settings, and wiped by "Delete all my data". Turning it off also clears it. It exists so beta users can voluntarily share it with feedback, and so future telemetry (if ever added) has an agreed schema.

Properties are sanitised in `Analytics.log` (`app/lib/app/analytics.dart`): only booleans, integers and short `[A-Za-z0-9_]` enum strings survive. Amounts, dates, supplier names and free text are dropped by construction.

## Events (implemented)

| Event | When | Properties |
|---|---|---|
| `onboarding_completed` | Onboarding finished | `meter`, `tariff`, `payment` |
| `bill_added` | New bill saved | `source` (manual/pastedText), `periods`, `e7`, `reconciles` (matches/mismatch/noStatedTotal), `reading` |
| `bill_parsed` | Pasted bill confirmed | `fields_found` |
| `bill_corrected` | Saved bill had parser corrections | `fields_corrected` |
| `comparison_viewed` | Comparison screen opened | `effects`, `caveats` |
| `insight_viewed` | "What can I do?" opened | `action` |
| `action_selected` | Action started | `action` |
| `next_bill_added` | A bill saved when an earlier bill exists | — |
| `savings_experiment_completed` | Next bill verified an action | `action`, `outcome` |
| `what_if_calculated` | What-if run | `cheaper` |
| `direct_debit_checked` | DD check shown | `verdict`, `confidence` |
| `data_deleted` | Delete all (logged then wiped) | — |

## Metrics (HYPOTHESES)

* **Activation:** (≥ 2 bills AND `comparison_viewed`) OR (1 bill AND `insight_viewed`).
* **North star:** verified comparisons with a completed action experiment (`savings_experiment_completed`) per active household per month.
* **Parser health:** `bill_corrected.fields_corrected` ÷ `bill_parsed.fields_found`.
* **Trust:** share of `bill_added` with `reconciles=matches` among those with a printed total.
* **Retention:** `next_bill_added` within 60 days of first `bill_added`.

Beta gates and kill thresholds: `PRD.md` → Beta gates.
