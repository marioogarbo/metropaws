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

## 5. Built v1.4.0+8 for both routes

Bumped `mobile/pubspec.yaml` from `1.3.1+7` to `1.4.0+8` — minor, not patch,
since this release carries plan upgrade/renewal and the Pack Discount admin
toggle. Both artifacts built from the same commit with
`--dart-define=ENV=prod`:

| Artifact | Path | Size |
| --- | --- | --- |
| AAB (Play) | `mobile/build/app/outputs/bundle/release/app-release.aab` | 54.3 MB |
| APK (direct) | `mobile/build/app/outputs/flutter-apk/app-release.apk` | 71.9 MB |

**Verified, not assumed.** Dart const-folds the env conditional, so non-prod
branches are physically absent from the AOT snapshot. Searching
`lib/arm64-v8a/libapp.so` in both artifacts: `metropaws-backend.onrender.com`
and `metropaws.ph` present; `metropaws-backend-dev.onrender.com`,
`localhost:8000`, and `staging-metropaws.vercel.app` all absent. This is a
better env check than reading build logs — reusable on any future build:

```bash
unzip -q -o <artifact> "*/lib/arm64-v8a/libapp.so"   # base/lib/... in an AAB
grep -a -c -F "metropaws-backend-dev.onrender.com" .../libapp.so   # want 0
```

Note `strings` is not installed in this Git Bash — use `grep -a`, or the check
silently reports everything as absent.

APK signing confirmed via `apksigner` (needs `JAVA_HOME` pointed at
`Android Studio/jbr`; `jarsigner` reports nothing because the APK is v2/v3
signed, not v1). V2 signer SHA-256 `719dd28b…195fb8` — the upload key, as
expected, so this APK still cannot replace a Play install.

Both routes now advertise 1.4.0 from **identical code**, which is what closes
the traceability gap — previously both said 1.3.1 while the APK was ahead. The
gap reopens the moment another APK ships ahead of Play.

## Open items

*(Superseded — see "Part 2" below. Kept for the record: at this point prod was
still missing every new field and nothing had been deployed.)*

---

# Part 2 — deployed and submitted (spilled into 2026-07-31)

## 6. Prod backend deployed

`python migrate.py` then `.\deploy.ps1 -Env prod`. Two failed attempts first:

1. Docker Desktop wasn't running (`open //./pipe/dockerDesktopLinuxEngine`)
2. `failed to authorize: ... Post "https://auth.docker.io/token": EOF` — the
   known IPv6 flakiness; a plain retry cleared it

Third attempt pushed and triggered `dep-d9lkoknqj5pc73994980`.

**Migrations needed an explicit target.** `database.py` calls a bare
`load_dotenv()`, and `migrate.py` has no env handling of its own — so
`python migrate.py` hits whatever `DATABASE_URL` is in `.env`, which is *not*
prod. Since `load_dotenv` defaults to `override=False`, a pre-set env var wins.
Reusable recipe:

```powershell
$line = Get-Content .env.prod | Where-Object { $_ -match '^DATABASE_URL=' } | Select-Object -First 1
$env:DATABASE_URL = ($line -replace '^DATABASE_URL=','').Trim().Trim('"').Trim("'")
python migrate.py
Remove-Item Env:\DATABASE_URL
```

Ran against prod **and** dev, both `Migration complete.` The ALTERs are
`ADD COLUMN IF NOT EXISTS` and the `CREATE TYPE` is wrapped in a
`duplicate_object` handler, so re-running is always safe.

Verified after: `eligibility`, `is_current`, `plan_status`, `plan_expires_at`,
`payout_target`, `provider_id` all present in prod's openapi. Live smoke tests:

```
GET /settings/pack-discount           {"enabled":true,"percent":15}
GET /members/reimbursement-providers  []
GET /settings/mobile-config           {"booking_enabled":false,
                                       "direct_provider_payment_enabled":false}
```

## 7. QA passed on the Play internal build

Tested by the client (Romy) on the internal track against **prod**. "Plans for
Koya" rendered Standard with a `Current plan` badge and Deluxe offered as an
upgrade — which proves prod is returning `is_current`/`eligibility` and the
whole upgrade/renewal UI works end-to-end.

**Not covered:** checkout and claim submission — the two paths that actually
depend on the columns added above (`payments.discount_php`,
`reimbursements.payout_target`). Still unobserved on 1.4.0.

He also hit the signature mismatch live: *"The app installed on your device
didn't come from Google Play... re-install from Google Play."* Exactly the
documented constraint, costing a real support conversation.

## 8. Promotion was blocked, then submitted

`Promote release → Production` was greyed out. Tooltip: **"Track already has a
draft release"** — an abandoned production draft. Fix was to build the release
directly in Production via `Create new release → Add from library → 8 (1.4.0)`,
which sidesteps the promote path entirely since the bundle is already uploaded.

Submitted 100% full rollout, `Managed publishing off` (so it auto-publishes on
approval), previous bundle `7 (1.3.1)` left in *Not Included*. Device support
review showed **zero devices lost** on every form factor, and +109 KB install
size for the whole feature set.

**Correction worth remembering:** Google does **not** review internal testing
releases — that track is instant and review-free. Review happens only on
promotion to Production. This was told to the client the wrong way round.

## 9. The Drive APK link has a warning-page problem

`APK_HREF` still resolves (the file was replaced in place, so the ID is
unchanged) but `uc?export=download` does **not** serve the binary. It returns
an HTML interstitial:

> Google Drive has detected issues with your download — This file is too large
> for Google to scan for viruses. **This file is executable and may harm your
> computer.** app-release.apk (72M)

So the direct route now costs a member four consecutive warnings: this page,
Android's "allow from this source", Play Protect, and then the signature
mismatch if they ever move to Play. `website/app/download/page.tsx` step 1
still claims the file "saves to your phone", which skips the interstitial
entirely — that copy is wrong.

**The APK route's justification expired tonight.** It existed because it ran
ahead of Play. Both are now 1.4.0 from the same commit, so it offers zero
features, a 72 MB download instead of 15.7 MB, and four warning screens. The
only remaining arguments for keeping it are the 1-country Play availability and
devices without Play Services.

## Open items

1. **Watch for review approval**, then confirm the public listing shows 1.4.0.
2. **Retire the APK route** (recommended) or fix the `/download` step-1 copy to
   mention the Drive warning page. Decision pending with the client.
3. **Confirm the Drive file is really 1.4.0** — the ID resolves and the size
   matches, but 1.3.1 was also ~72 MB, so size alone doesn't prove it. Check
   Drive's version history.
4. **Exercise checkout and a claim on 1.4.0** — the two migration-dependent
   paths nobody has run yet.
5. **Verify Mario's own account is off the internal tester list** — some were
   removed; that specific one is what caused the original `(Internal Beta)`
   symptom.
6. **Provider nomination** — the next feature. See
   [`../features/provider-nomination.md`](../features/provider-nomination.md).
7. **Confirm the 1-country production availability is intended.**
8. **Digital Asset Links** — optional; details in the distribution feature doc.
