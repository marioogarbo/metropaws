# What is in the app but not on Play

**Purpose:** the standing answer to "what changed since the last release?" Update
it as mobile work lands; **empty it when a build ships**, and record the shipped
version in [`android-distribution.md`](./android-distribution.md).

| | |
| --- | --- |
| Live on Play (production) | **1.7.0 (versionCode 14)**, submitted 2026-08-27 23:58, published 2026-08-28 |
| Internal testing track | **1.6.0 (versionCode 12)** — now BEHIND production, see the warning below |
| `pubspec.yaml` | `1.7.0+14` (bumped in `8270cff`) |
| Branches | all merged into `main`; `origin/main` is level |

**Nothing is unreleased.** 1.7.0+14 shipped every section this file used to
carry — monthly instalments, pet health records, light-only theme, navy chrome,
the auth redesign, the pet card and tier system, the wallet→benefit rename, and
the Add-a-Pet / claim-form rebuilds with the emergency-pool fix. Production went
from 1.4.1+9 straight to 1.7.0+14, so versionCodes 10 through 13 never reached a
member.

> **The internal testing track is now behind production, and that is a live
> trap.** It holds 12 (1.6.0); production has 14. Track priority is
> `internal > closed > open > production` and is **per Google account**, so
> anyone on the tester list is served **1.6.0** and will not receive 1.7.0 —
> including the emergency-pool fix — no matter how many times they check for
> updates. This file predicted exactly this failure mode before it happened.
> Either upload 14 to internal testing as well, or empty the tester list.
> There is no "halt rollout" for a testing track.

> **Read the Play Console, not this table, before assuming a version code is
> free.** On 2026-08-21 a rebuild was made at versionCode 12 on the strength of
> this file saying 12 was "built, NOT uploaded". It had been uploaded the night
> before, and Play rejected the bundle: "Version code 12 has already been used."
> This file lags whatever is done in the console by hand, so the console is the
> only authority on which codes are consumed.

---

## Unreleased changes

*(none — add sections here as mobile work lands)*

---

## Before building

1. **Bump `pubspec.yaml`.** `1.7.0+14` is the shipped version — Play rejects a
   duplicate `versionCode`. **Check the Play Console for which codes are
   consumed; this file lags it**, and that is exactly how a rebuild at an
   already-uploaded 12 got rejected on 2026-08-21.
2. **Deploy the prod backend first** if the release depends on a new endpoint.
   1.7.0 did not — it was mobile-only — but every release before it did.
3. **Verify the AAB before upload**, per
   [`../sessions/2026-08-14-per-member-direct-pay-and-release.md`](../sessions/2026-08-14-per-member-direct-pay-and-release.md):
   signed with `META-INF/UPLOAD.RSA`, `metropaws-backend.onrender.com` compiled
   in, and **neither the dev URL nor `localhost:8000` present**. Unzip the AAB
   and search **every** ABI slice of `base/lib/*/libapp.so`, not just
   `arm64-v8a`.

   **Do not use `strings` for this — it is not installed in this repo's Git Bash,
   and the check fails open.** `strings ... | grep -c` reports `0` for a missing
   binary exactly as it does for an absent URL, so all three must-be-ABSENT rows
   "pass" while the build is never actually read. Search the bytes instead:

   ```bash
   python -c "
   import pathlib
   d = pathlib.Path(r'<extracted>/base/lib/arm64-v8a/libapp.so').read_bytes()
   for u in ['metropaws-backend.onrender.com','metropaws-backend-dev.onrender.com','localhost:8000']:
       print(d.count(u.encode()), u)"
   ```

   The must-be-PRESENT rows are what make this honest: the prod host counted
   **4** and `metropaws.ph` **5** on 1.7.0+14 (the older note here said 4 for
   both — more document URLs have been added since). If a present-check reads
   `0`, the tooling is broken, not the build.
4. **Check the permissions in the built bundle**, not just the source manifest.
   `READ_MEDIA_IMAGES` / `READ_MEDIA_VIDEO` must be **absent** — a plugin can
   merge them back in, and requesting them without a core media use case is what
   caused the 2026-07-17 rejection:

   ```bash
   python -c "
   import pathlib, re
   m = pathlib.Path(r'<extracted>/base/manifest/AndroidManifest.xml').read_bytes()
   print(sorted(set(re.findall(rb'android\.permission\.[A-Z_]+', m))))"
   ```
5. Build with `--dart-define=ENV=prod`. Release builds default to prod even if
   it is forgotten, but do not rely on that.
6. **Re-verify the App access demo login against prod before submitting.**
   Rejections 2 *and* 3 were both "login credentials are incorrect"; the second
   time because the demo account stopped authenticating after a prod DB rebuild.
7. **Keep the prod backend warm during review.** ~34s cold start was observed on
   Render's free tier, which can time out the reviewer's first login even with
   correct credentials.
8. See [`android-distribution.md`](./android-distribution.md) and the
   `mobile-prod-build` memory for keystore and appbundle specifics.

## Monthly: prices settled, §5.5 wording still owed

**The pricing half is CLOSED (client decision, 2026-08-27).** Romy created the
subscription amounts; they stand as configured and the +8% / +20% asymmetry is
not to be raised again. Verified the same day against the live admin portal: the
annual fees and all six benefit pools match Manual Rev. 3C exactly. The monthly
prices appear in neither controlled document — a silence, not a contradiction,
and Manual Rev. 3C explicitly disclaims the website's monthly equivalents as
"for communication purposes only".

**§5.5 wording is document hygiene, not exposure.** MP-CON-001 still reads
"two (6)", "three (8)", "four (10)" for planned-service eligibility while its own
Emergency column reads an unambiguous 3 / 3 / 4. The numerals are the correct
reading and the system implements them. Crucially, **members accept the website
transcription, not the PDF** — `ApiConstants.agreementUrl` resolves to
`{webUrl}/terms-of-service`, which reads "six (6) / eight (8) / ten (10)" with
words and numerals agreeing. Client decision 2026-08-27: do not chase Romy.
See item 10 of
[`document-system-alignment.md`](./document-system-alignment.md).

**1.7.0 is the first production build in which a member can reach a monthly
plan**, so the vesting thresholds now bind on real accounts for the first time.
They are database values — any future ruling is a config edit, not a rebuild.
