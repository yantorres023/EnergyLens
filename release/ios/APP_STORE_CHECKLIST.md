# App Store checklist

| Item | Value / status |
|---|---|
| Bundle ID | `uk.energylens.energylens` (provisional) |
| Display name | EnergyLens (Info.plist `CFBundleDisplayName`) |
| Build | CI artifact `ios-unsigned` → `EnergyLens-unsigned.ipa` (**unsigned, not installable/uploadable**) |
| Privacy | App Privacy: "Data Not Collected". No tracking. No usage-description keys needed |
| Export compliance | `ITSAppUsesNonExemptEncryption = NO` set in Info.plist (no non-exempt encryption) |
| Age rating | 4+ |
| Category | Finance / Utilities |
| Screenshots | 6.9" and 6.5" iPhone required; drafts in release/screenshots |

## Signing blockers (HUMAN_ACTION_REQUIRED)

1. Apple Developer Program membership (£79/yr) under the publishing entity.
2. Register the bundle ID; create an App Store Connect app record.
3. Create a distribution certificate + App Store provisioning profile, or use Xcode automatic signing with the team ID set in `ios/Runner.xcodeproj` (`DEVELOPMENT_TEAM`).
4. Either archive locally on a Mac (`flutter build ipa`) or add CI secrets (certificate .p12 + password, provisioning profile, App Store Connect API key) and a signed `flutter build ipa --export-options-plist=...` step, then upload with `xcrun altool`/Transporter.
5. TestFlight external testing requires Beta App Review.
