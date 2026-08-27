# Android distribution — two routes, mutually incompatible

**Status:** the second route is **retired** (2026-08-03, `284bb31` + `dcf2a28`).
The website offers Play only, `/download` is deleted and 307s to the listing, and
`website/lib/app-download.ts` holds no APK constants. **The constraint below is
not historical, though** — it still binds every member who installed the direct
APK before that date and has not switched, and they are invisible to Play's
update numbers.
**Owns:** `website/lib/app-download.ts`, `website/components/app-store-buttons.tsx`
(`website/app/download/page.tsx` no longer exists)

MetroPaws Android (`com.metropaws.mobile`) was installable two ways, and a
device can only ever hold one of them.

| Route | Serves | Signed by |
| --- | --- | --- |
| Google Play | the reviewed release (**v1.7.0, versionCode 14, published 2026-08-28**; previously 1.4.1+9 from 2026-08-14) | Google's app signing key |
| Direct APK | **retired 2026-08-03.** Last published 1.4.0; still installed on an unknown number of devices | the upload keystore |

**Play is now ahead of the APK, which inverts the original premise.** This file
was written when local builds ran ahead of the Play listing. Since 2026-08-03 the
reverse holds: a member still on the 1.4.0 APK cannot take any Play update —
1.4.1, nor 1.7.0 now that it is published — and gets no prompt saying so. They must
uninstall and reinstall from Play, losing nothing but their session.

**Decision (Mario, 2026-08-19): the APK route is closed and nothing will be done
about the members left on it.** Google Play is the only channel now. No outreach,
no in-app notice, no attempt to count the installs. Keep the rest of this file as
the explanation for any "App not installed" report that surfaces later — it is
reference, not a backlog item.

## The core constraint

**Installing one over the other fails with "App not installed."** Members
must uninstall what they have before switching. This is a signature
mismatch, not a bug, and there is no configuration that fixes it.

Verified 2026-07-30 from both ends — Play Console `.../keymanagement`, and
`keytool` against the keystore referenced by `mobile/android/key.properties`
(alias `upload`):

```
App signing key  F9:65:ED:B9:6C:B3:12:E3:E6:73:2D:3E:4C:F3:21:B8:
                 B4:CC:33:61:7B:4B:CF:1C:77:22:25:A8:F8:C2:B9:40
Upload key       71:9D:D2:8B:07:CC:05:1F:7E:60:30:8E:81:7F:73:B2:
                 1D:EF:A9:72:84:E1:B1:95:62:34:1B:94:8A:19:5F:B8
```

**Why it can't be fixed:** Play App Signing keeps Google's signing key
server-side and re-signs every upload, so a locally built APK can never
match the Play signature. Re-hosting a Play-derived artifact isn't a
workaround either — `Prevent unofficial installs` is ON under Protected
with Play → Automatic protection, which injects anti-tamper code into
whatever Play distributes.

To re-verify the fingerprints:

```bash
keytool -list -v -keystore <storeFile from key.properties> -alias upload
# compare SHA256 against Play Console → Protected with Play → App signing
# (direct link: .../app/<appId>/keymanagement)
```

## Why both routes exist

The APK build runs ahead of the Play release. Shipping to Play costs a
review cycle, so newer features land in the APK first and the Play listing
lags. **This is a release-cadence gap, not an intended architecture.**

**This end state was reached on 2026-08-03.** The plan read: bump past
`1.3.1+7`, build the AAB with `--dart-define=ENV=prod`, promote internal →
production, then retire the APK path and delete `APK_HREF` / `APK_VERSION` from
`website/lib/app-download.ts`. All of it is done — the constants are gone and the
release cadence is Play-only. What the plan did not resolve is the population
already holding an APK; nothing reaches them automatically, so a switch has to be
asked for.

Best practice worth restating, because it was briefly misunderstood with the
client: you do **not** wait for a "final and complete" version before
publishing to Play. Play is the update channel. Updates to an
already-approved app clear review in roughly a day and then reach every
member automatically.

## How the website presents it

**Rewritten 2026-08-19 — the previous description of this section was obsolete.**
`AppStoreButtons` now renders exactly two badges: Google Play (a real link to the
plain HTTPS listing, which Android intercepts and deep-links into the Play Store
app) and a deliberately inert App Store badge showing `IOS_STATUS_LABEL`, since
there is no iOS listing to point at. **Never use `market://`** — it adds nothing
on Android and breaks on desktop.

The three incompatibility warnings this file used to list are **all gone**, along
with the APK badge and the `/download` page that carried two of them. That was
correct once the site stopped offering the APK — a warning about choosing between
two routes is confusing when only one is on offer.

**The gap that leaves:** a member already holding the retired APK gets no signal
from anywhere. The site no longer mentions the incompatibility, Play cannot see
them, and Android reports the failure only at install time as a bare "App not
installed". If the APK population turns out to matter, reaching them needs an
email or an in-app notice, not a website change.

## Related external state

Facts that live in Play Console, not in this repo:

- **Production is published to 1 country / region.** The Play link silently
  returns "item not found" everywhere else. Confirm this matches intent
  before any wider marketing push.
- **Internal testing track holds versionCode 12 (1.6.0) and production now
  holds 14 — the trap this entry warned about has sprung (2026-08-28).** An
  account on the tester list is served the internal build over production,
  forever, regardless of install state — track priority is
  `internal > closed > open > production` and is per-Google-account. So every
  tester is pinned to **1.6.0** and will not receive 1.7.0, including the
  emergency-pool fix, however often they check for updates. Testing tracks have
  no "halt rollout"; the only way to switch one off is to empty its tester list.
  **Fix it by uploading 14 to internal testing as well, or by emptying the
  tester list.** Note the symptom is silent: a tester sees "up to date".
- **Env is baked in at build time.** `mobile/lib/core/constants/api_constants.dart`
  defaults release builds to `prod`, so a forgotten `--dart-define` is safe.
  To confirm what a shipped build points at: Account tab → bottom version
  footer. A non-prod build appends the env (`· dev`, `· local`); prod shows
  no suffix.
- **Digital Asset Links (not yet wired).** Play Console → App signing offers
  an `assetlinks.json` snippet for Android App Links, which would make
  `metropaws.ph` URLs open in the app. As generated it lists only the
  `F9:65:…` app signing fingerprint, so it would cover Play installs only —
  add `71:9D:…` to the same `sha256_cert_fingerprints` array to cover the
  APK build too. Would live at `website/public/.well-known/assetlinks.json`.
