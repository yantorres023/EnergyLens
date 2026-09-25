# Security and privacy review

## Data inventory

| Data | Stored? | Where | Notes |
|---|---|---|---|
| Name, address, account number, MPAN/MSN | **Never** | — | No fields exist; parser cannot extract them; tests assert absence |
| Pasted bill text | **Never** | Widget memory only | Cleared after parsing; capped at 50k chars |
| Bill figures (dates, kWh, rates, VAT, credits, totals, balance) | Yes | App SQLite DB | Needed for the product |
| Supplier name | Optional | DB | Free text; UI warns not to enter account numbers |
| Region, meter/tariff/payment type, DD amount | Optional | DB | Coarse |
| Usage log | Only if opted in | DB | Sanitised properties only |
| Bill images/PDFs | Not supported | — | Nothing to retain or delete |

## Threat model (V1)

| Threat | Mitigation | Residual |
|---|---|---|
| Network exfiltration | No network code, no SDKs; Android release manifest declares **no INTERNET permission** | Future features adding network must update this doc and the privacy policy |
| Cloud backup copying bills | Android `allowBackup=false`, `fullBackupContent=false`, data-extraction rules exclude all domains | iOS: app data is included in the user's device backups (encrypted iCloud/Finder backups). Documented in privacy policy. Consider `NSURLIsExcludedFromBackupKey` on the DB file in V1.1 |
| Lost/unlocked phone | Relies on OS sandbox + device encryption | DB is not encrypted at app level. Contents are low sensitivity (no identifiers); SQLCipher considered unnecessary for V1 |
| Deleted data recoverable from DB file | `PRAGMA secure_delete=ON`; `VACUUM` after delete-all; test proves marker text absent after delete-all | Flash wear-levelling may retain blocks — OS level |
| Malicious pasted text | Regex parsing only, no eval, length cap, values re-validated by form validators; values never used until user confirms | — |
| Wrong numbers → harmful decisions | Deterministic calculator, reconciliation with printed total, provenance labels, estimates labelled, no guarantees, no switching | User may still act on typos; mismatch dialog reduces this |
| Stale reference data | Staleness gate hides dependent estimates; CI warns 21 days ahead | Requires app updates each quarter |
| Tampered reference asset | Bundled in signed app; parsed & validated at startup; invalid → unused | — |
| Analytics leaking personal data | Opt-in, local, sanitiser drops strings with spaces, doubles, maps | — |

## Permissions

Android: none requested in the main manifest (debug/profile manifests add INTERNET for tooling only). iOS: no usage-description keys needed (no camera, photos, location, tracking). App Tracking Transparency not applicable.

## Secrets

No API keys. Android keystore only via CI secrets (`ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD`); `key.properties` and `*.jks` are git-ignored.

## Store privacy declarations (draft)

* Google Play Data safety: "No data collected", "No data shared" (data stays on device; the local log is not transmitted).
* Apple App Privacy: "Data Not Collected".

Both must be re-reviewed if any network feature is added.
