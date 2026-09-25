# Monetization

All options are HYPOTHESES; willingness to pay is UNVALIDATED_WITH_REAL_USERS (evidence ledger A11: LOW confidence).

## Options

| Model | Fit | Evidence / reasoning | Conflict-of-interest risk | Verdict |
|---|---|---|---|---|
| Free, no ads | Trust, adoption | Free alternatives everywhere (supplier apps, MSE, Citizens Advice) | None | **V1** |
| One-time purchase (e.g. £2.99–£4.99 "household pack": unlimited history, gas, export, reminders) | Episodic use suits a one-off | Subscriptions for an every-1–3-months tool are hard to justify (A7) | None | **Lead paid hypothesis**; fake-door test first |
| Annual plan (£9.99–£14.99) | Only if retention proves monthly engagement | Needs ≥ 35% second-bill return (PRD gate) | None | Only after gates pass |
| Premium analysis (one-off £0.99 "full year review") | Moment-based | Could pair with cap/VAT dates | None | Test alongside one-time |
| Utility partnerships (white-label explainer) | B2B2C | Suppliers are measured on complaints (billing 56–58% of disputes, S11); an explainer could reduce contacts | Medium — must stay independent in consumer app | Explore after beta data |
| Consumer-advice / charity partnerships (grant-funded free tool) | Mission fit | Citizens Advice, fuel-poverty charities help with billing daily (S12) | Low | Explore — may be the most realistic |
| Comparison/referral revenue | Market standard (S19) | MSE shares referral fees as cashback; other sites hide non-paying tariffs | **High**: incentive to push switching; Ofgem Confidence Code implications | **Rejected for V1.** If ever added: whole-of-market, disclosed on every screen, never influences explanations or insights, never shown as a recommendation |
| Ads | — | Undermines trust; would need network + tracking | High | Rejected |

## Recommendation

1. Ship free with no network code (current build).
2. In beta, add a **fake-door** "Unlock household pack" tile (no charge, explains it's a test) and measure tap rate (gate: ≥ 8% of activated users continue; < 3% ⇒ free/partnership only).
3. In parallel, pitch a grant-funded or partner-distributed free version to consumer-advice organisations, using beta explanation-clarity data.

## Commission transparency rule (binding if referrals are ever introduced)

"EnergyLens earns £X if you switch through this link. This does not change the explanation of your bill." — shown adjacent to any link, plus a whole-of-market default and a non-affiliate path.
