# Data safety form - DRAFT answers (verified against the code on 2026-10-28; recheck against the final release build)

Basis: SDKs in `pubspec.yaml` are `google_mobile_ads` (AdMob + UMP consent), `in_app_purchase` (Play Billing), `flutter_local_notifications` (local only), `shared_preferences` (local only). No Firebase, no analytics, no crash SDK, no backend (`AnalyticsService` is a no-op). Play Games is a stub and `play_games.enabled: false` in `app.config.yaml`, so no player ID is collected in v1. Manifest permissions: INTERNET, POST_NOTIFICATIONS, RECEIVE_BOOT_COMPLETED, `com.google.android.gms.permission.AD_ID`.

| Question | Answer |
|----------|--------|
| Does the app collect or share user data? | Yes (collected and shared via the Google Mobile Ads SDK only) |
| Is all user data encrypted in transit? | Yes |
| Do you provide a way to request data deletion? | No account is created, nothing is stored on our servers; uninstall removes local data |
| Data type: Device or other IDs (Advertising ID) | Collected: Yes. Shared: Yes (Google AdMob). Optional: No (required for ads; consent requested where required). Purposes: Advertising or marketing; Fraud prevention, security and compliance |
| Data type: Approximate location (derived from IP by AdMob) | Collected: Yes. Shared: Yes (Google AdMob). Purposes: Advertising or marketing |
| Data type: App interactions / Diagnostics (ad interaction, performance as collected by the AdMob SDK) | Collected: Yes. Shared: Yes. Purposes: Advertising or marketing; Analytics (by AdMob) |
| Personal info, financial info, health, messages, photos, audio, files, contacts, calendar | Not collected |
| Purchases | Handled by Google Play Billing; no payment info collected by the app, so no financial data type is declared |
| Play Games sign-in / player ID | Not collected in v1 (stub, disabled). Update this form if sign-in is enabled |
| Notifications | Local only, no data leaves the device |
| Data processed ephemerally? | No |

## Other Play Console declarations
- **Contains ads: Yes**
- **Target audience: 13+ / general. Not children; do not opt into Families.** (Ads then do not need to be Families-certified.)
- Advertising ID declaration: Yes, used for advertising (manifest has the AD_ID permission).
- Privacy policy URL: host `store/google-play/privacy_policy.md` publicly and link it.
