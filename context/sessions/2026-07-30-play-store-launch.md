# 2026-07-30 — Play Store launch follow-up

Production launch landed 2026-07-24 (v1.3.1, versionCode 7). This session
handled the fallout: why the Play listing looked wrong on-device, whether the
two install routes can coexist, and wiring the website's dead Play Store
button.

## 1. "Play Store still says Internal Testing"

**Reported:** after uninstalling and switching Google accounts, the Play page
still showed `MetroPaws (Internal Beta)` with a tester banner and a Jul 17
date, not the Jul 24 production release.

**Cause:** not a release problem. Play resolves builds by track priority per
Google account — `internal > closed > open > production`. The account was on
the internal tester list, so Play served the internal build. Uninstalling
changes nothing; eligibility is account-based. Switching accounts appeared
not to help because Play serves the account selected *inside the Play Store
app*, and the store page is cached hard.

The `(Internal Beta)` title came from the store listing name at the time, not
from the app — `mobile/android/app/src/main/AndroidManifest.xml` has
`android:label="MetroPaws"`, and no "Internal Beta" string exists anywhere in
the repo.

**Fix:** empty the internal tester list (Testing → Internal testing →
Testers), clear the Play Store app cache, wait for propagation. Testing
tracks have no halt-rollout control — emptying the audience is the only off
switch. Internal testing also has no self-service "leave the program" link,
so removal must happen in Console.

**Still open:** the tester list had not been emptied when the session ended.

## 2. Signing keys — investigated because both install routes are live

Question was whether the Drive APK and the Play build can replace each other
on a device. **They cannot.** Both certificates captured, the mechanism
explained, and the re-verification command recorded in
[`../features/android-distribution.md`](../features/android-distribution.md).

Console navigation note: `App integrity` in the left nav is now just a
signpost — the settings moved to **Protected with Play**. The old deep link
`.../app/<appId>/keymanagement` still resolves straight to App signing and is
the fastest route.

## 3. Suspected dev-config build — false alarm

Briefly suspected the Play build had been compiled with `ENV=dev` and
unpublishing was considered. Checked before acting:
`mobile/lib/core/constants/api_constants.dart` defaults release builds to
`prod`, so this requires an explicit `--dart-define=ENV=dev` rather than a
forgotten flag. User confirmed the live config was used.

**Nothing was changed in Play Console.** App availability remains
`Published`, which is correct.

Worth keeping: the on-device check is the Account tab's bottom version
footer, which appends the env for any non-prod build. Faster and more
definitive than reading build logs.

## 4. Website — Play Store buttons went live

`PlayStoreComingSoon` was a `<div role="img">` with `cursor-not-allowed` —
genuinely unclickable, and the `/download` page still claimed the listing was
"in review" and that updates weren't automatic. All false since Jul 24.

Changed:

| File | Change |
| --- | --- |
| `website/lib/app-download.ts` | added `PLAY_STORE_URL`; kept APK constants |
| `website/components/play-store-icon.tsx` | new — extracted, was about to be duplicated three ways |
| `website/components/app-store-buttons.tsx` | Play badge is a real link; removed dead `AppStoreComingSoon` / `AppleIcon`; added the incompatibility caption |
| `website/app/download/page.tsx` | second CTA, "Two ways in — pick one" comparison, incompatibility callout, install steps rescoped to the APK only, all stale copy fixed, two new FAQs |
| `website/app/member/page.tsx` | emoji placeholder badges replaced with a real Play link; dropped the App Store badge (no iOS app) |

Button order is APK first, Play second — client's explicit call, since the
APK carries newer features.

Note on `website/app/member/page.tsx`: it `router.replace()`s on mount, so
nobody actually sees it. It's a redirect shim. Fixed anyway to remove the
fake buttons, but don't invest design effort there.

Verification: `npx tsc --noEmit` clean, `npm run build` succeeded (28/28
static pages), `npm run lint` reports nothing in the touched files. The
repo's ~50 pre-existing lint errors live in files this session didn't touch.

## Open items

1. **Empty the internal tester list** — until then the launch looks broken on
   any tester's device.
2. **Ship the newer build to Play** — bump past `1.3.1+7`, build the AAB with
   `--dart-define=ENV=prod`, promote internal → production, then retire the
   APK route. The population that can't migrate without uninstalling grows
   until this happens.
3. **Confirm the 1-country production availability is intended.**
4. **Give the APK its own version number.** `APK_VERSION` and the Play
   release both read `1.3.1`, so a member's bug report can't be traced to a
   build.
5. **Digital Asset Links** — optional; details in the feature doc.
