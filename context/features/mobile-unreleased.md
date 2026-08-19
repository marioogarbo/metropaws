# What is in the app but not on Play

**Purpose:** the standing answer to "what changed since the last release?" Update
it as mobile work lands; **empty it when a build ships**, and record the shipped
version in [`android-distribution.md`](./android-distribution.md).

| | |
| --- | --- |
| Live on Play (production) | **1.4.1 (versionCode 9)**, published 2026-08-14 |
| Internal testing track | **1.5.0 (versionCode 10)**, uploaded 2026-08-19 11:55 |
| `pubspec.yaml` | `1.5.0+10` (bumped in `c69d5f2`) |
| Branches holding this work | all merged into `main` — verified 2026-08-19 with `git branch --merged main` |

**Status 2026-08-19: everything below is built, verified, and sitting on the
internal testing track. It is not on production**, so this file stays full.
Empty it when 10 is promoted, not before. The one thing gating promotion is the
monthly pricing question at the foot of this file — the prices are already live
in the prod database, and this build is the first that lets a member reach them.

Do not trust an older reading of this table: the branch row previously named
`feature/pet-records` as separate, and section 1 previously said the monthly
endpoints were missing from production. Both were stale by 2026-08-19.

---

## Unreleased changes

### 1. Monthly instalment memberships — the large one

A plan can be paid monthly, not just annually. Governed by Agreement Rev. 5A
§5.2–§5.10; design in [`monthly-subscriptions.md`](./monthly-subscriptions.md).

- **Plan selection** and **Add-a-Pet** both offer a yearly / monthly toggle,
  shown only when a plan has a monthly price.
- Confirm sheet quotes the instalment, and states that the first payment buys
  app access rather than benefits.
- **Benefits tab** shows the §5.7 membership status, payments made, next due
  date, and a **Pay next instalment** action.
- Claims are gated while a subscriber is vesting, explained **before** the form
  is filled rather than refused after.
- Unvested pools are shown muted and marked "not available yet" on the Benefits
  card, the Home pet card, and the Submit form.

**Hard dependency — CLEARED 2026-08-19.** This previously read "the monthly
endpoints do not exist in production yet". They do now, verified by reading
`https://metropaws-backend.onrender.com/openapi.json` directly: `/payments/installment`
and `/payments/quotes` are present, and so are `cadence`, `price_monthly`,
`membership_status`, `subscription_next_due_on`, `subscription_payments_made`
and the vesting fields. `GET /plans` returns real monthly prices on all three
plans. The upgrade/renewal work is live in the same deploy — `PlanQuoteOut`
carries `eligible` / `eligibility` / `is_current`. No 404 surface remains.

### 2. Pet health records

- A member can **add a vaccination card after registration** — previously
  impossible from anywhere, by anyone.
- **Replace card** for when it goes out of date.
- The empty state no longer tells members to "contact your clinic", which they
  cannot do.
- **Care notes** moved from Pet Details into Health Records, with an Add path
  when empty.

No backend change required; `PUT /pets/{id}` already accepted this.

### 3. Light mode only, and a reworked Home header and nav

- **The app is light only.** `main.dart` pins `ThemeMode.light` whatever the
  device says, and the Appearance picker is gone from Account. `buildDarkTheme()`
  and `ThemeCubit` stay wired but unreached, so it is two edits to restore.
- **The plan tier badge is gone from the Home header.** It showed the HIGHEST
  tier across a member's pets, so one Premium pet made a mixed household read as
  Premium — and a monthly subscriber with no benefits yet read as though they
  held the whole plan. Tier stays on each pet card, where it is accurate.
- **PawPoints** is now the coin, the balance, and "pts", with the balance grouped
  (1,800). The wordmark was naming what the icon already said.
- **The bottom nav is a floating capsule** with the page running underneath it,
  a raised centre Claim action, and an oval active indicator.
- **Pet health records**: vaccination card add/replace, and care notes moved out
  of Pet Details.

Members on the current build will notice the theme and the navigation
immediately, so these are worth a line in the Play release notes even though
neither is a feature.

### 4. Navy app chrome, a restructured Home, and narrow-screen support

Added 2026-08-18. Detail and the measured contrast figures are in
[`../sessions/2026-08-18-navy-chrome-and-narrow-screens.md`](../sessions/2026-08-18-navy-chrome-and-narrow-screens.md).

- **The app chrome is navy** — app bar, Home header block, and the nav capsule —
  with the cream content field between them. Six screens were already overriding
  the app bar to navy by hand, so this mostly makes the theme agree with what the
  app was doing. Every screen looks different; worth a release note.
- **Home is restructured.** Greeting, name, Founding badge and PawPoints merge
  into one navy header. "Add another pet" moves out of the page footer (where it
  sat under the pagination dots as the quietest thing on screen) into a "Your
  pets" section header — that is the entry point the Pack Discount depends on.
- **The Home pet card states the plan.** It previously showed none, which left
  "Upgrade plan" asking members to upgrade from an unnamed thing. Tier badge
  only; **no expiry date**, by client decision.
- **Narrow screens down to 320dp.** Not exotic: that is a normal 360dp phone at
  Samsung's largest Screen zoom. Fixed six defects that only appeared on a real
  device, including the PawPoints **balance** truncating to "1,8…" and every form
  in the app clipping its validation messages to one line.

Nothing here needs a backend change and nothing here is gated on the monthly
deploy, so this half can ship whenever a build goes out.

---

## Before building

1. **Bump `pubspec.yaml`.** `1.4.1+9` is the shipped version — Play rejects a
   duplicate `versionCode`. Monthly is a feature release, so `1.5.0+10`.
2. **Deploy the prod backend first** (see the dependency above).
3. **Verify the AAB before upload**, per
   [`../sessions/2026-08-14-per-member-direct-pay-and-release.md`](../sessions/2026-08-14-per-member-direct-pay-and-release.md):
   signed with `META-INF/UPLOAD.RSA`, `metropaws-backend.onrender.com` compiled
   in, and **neither the dev URL nor `localhost:8000` present**. A build that
   fell back to localhost is what caused the "login credentials are incorrect"
   Play rejection. Unzip the AAB and search **every** ABI slice of
   `base/lib/*/libapp.so`, not just `arm64-v8a`.

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

   The must-be-PRESENT rows are what make this honest: prod host and
   `metropaws.ph` should both count **4**. If a present-check reads `0`, the
   tooling is broken, not the build.
4. Build with `--dart-define=ENV=prod`. Release builds default to prod even if
   it is forgotten, but do not rely on that.
5. See [`mobile-prod-build`](./android-distribution.md) and the memory of the
   same name for keystore and appbundle specifics.

## Not resolved, and it gates the monthly half

Romy has not answered on the monthly **prices** (₱300 / ₱600 / ₱900 appear in no
document) or on Premium being **+8%** over annual where the other two plans are
**+20%**. The vesting thresholds are data, so a change is a config edit rather
than a rebuild — but the copy and the member's experience of the waiting period
depend on the answer.

**The pet-records half has no such blocker** — but as of 2026-08-19 the split is
no longer free. Everything is merged into `main` and built together as
1.5.0+10, so shipping pet records alone now means a fresh branch off the last
pre-monthly commit, a new versionCode, and a second upload. The cheaper lever is
the prices themselves: they are rows in the prod database, so correcting them
needs no build at all. Prefer fixing the number over splitting the release.
