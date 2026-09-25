# Google Play checklist

| Item | Value / status |
|---|---|
| Package | `uk.energylens.energylens` (provisional — finalise with brand; immutable after first upload) |
| Build | CI artifact `android-release` → `app-release.aab` |
| Signing | Play App Signing + upload key. Provide CI secrets `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD` (see SIGNING.md). Without them the AAB is debug-signed and **will be rejected** |
| Version | `pubspec.yaml` `version: 0.1.0+1` |
| targetSdk | Flutter default for 3.47 (meets Play's current target API requirement — verify at upload) |
| Permissions | None in release manifest (no INTERNET) |
| Data safety | No data collected; no data shared; data not encrypted in transit (n/a – no transit); users can request deletion (in-app delete) |
| Ads | No |
| Content rating | IARC questionnaire: utility/finance, no user content → Everyone |
| Target audience | 18+ |
| Financial features declaration | Answer: app does not provide financial products/services (bill explainer). Re-check wording |
| Store listing | ../STORE_LISTING.md |
| Privacy policy URL | Required — host legal/PRIVACY_POLICY.md |
| Testing | Closed testing track first (Play requires 12+ testers for 14 days for new personal developer accounts) |
