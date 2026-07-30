# Android distribution — two routes, mutually incompatible

**Status:** active constraint as of 2026-07-30
**Owns:** `website/lib/app-download.ts`, `website/components/app-store-buttons.tsx`, `website/app/download/page.tsx`

MetroPaws Android (`com.metropaws.mobile`) is installable two ways, and a
device can only ever hold one of them.

| Route | Serves | Signed by |
| --- | --- | --- |
| Google Play | the reviewed release (v1.3.1, versionCode 7, live 2026-07-24) | Google's app signing key |
| Direct APK | a newer local build, hosted on Google Drive | the upload keystore |

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

The intended end state is Play-only: bump past `1.3.1+7`, build the AAB with
`--dart-define=ENV=prod`, promote internal → production, then retire the APK
path and delete `APK_HREF` / `APK_VERSION` from
`website/lib/app-download.ts`. Every day both routes stay live adds members
who can't move to Play without uninstalling.

Best practice worth restating, because it was briefly misunderstood with the
client: you do **not** wait for a "final and complete" version before
publishing to Play. Play is the update channel. Updates to an
already-approved app clear review in roughly a day and then reach every
member automatically.

## How the website presents it

`AppStoreButtons` (hero, homepage) renders the APK badge first, then Google
Play — deliberate order, client's call. Both are real links; the Play badge
targets the plain HTTPS listing URL, which Android intercepts and deep-links
into the Play Store app. **Never use `market://`** — it adds nothing on
Android and breaks on desktop.

The incompatibility is surfaced in three places, because a member who taps
the wrong button second hits a dead end:

1. Homepage hero caption — "Pick one — the two versions can't replace each other"
2. `/download` hero — bordered callout below the two CTAs
3. `/download` FAQ — "Can I switch between the two later?"

Anything that reduces those warnings needs to account for the fact that the
failure mode is silent from the website's side: Android reports it, we don't.

## Related external state

Facts that live in Play Console, not in this repo:

- **Production is published to 1 country / region.** The Play link silently
  returns "item not found" everywhere else. Confirm this matches intent
  before any wider marketing push.
- **Internal testing track holds versionCode 7** and is still enabled. An
  account on the tester list is served the internal build over production,
  forever, regardless of install state — track priority is
  `internal > closed > open > production` and is per-Google-account.
  Testing tracks have no "halt rollout"; the only way to switch one off is
  to empty its tester list.
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
