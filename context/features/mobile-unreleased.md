# What is in the app but not on Play

**Purpose:** the standing answer to "what changed since the last release?" Update
it as mobile work lands; **empty it when a build ships**, and record the shipped
version in [`android-distribution.md`](./android-distribution.md).

| | |
| --- | --- |
| Live on Play (production) | **1.4.1 (versionCode 9)**, published 2026-08-14 |
| Internal testing track | **1.6.0 (versionCode 12)**, uploaded 2026-08-20 23:58, released to testers 2026-08-21 10:01. (1.5.0+10 went up 2026-08-19 11:55 and is now Inactive.) **This build carries §1–§6 but NOT §7** — the rename landed after it was built |
| Built and verified, NOT uploaded | **1.6.1 (versionCode 13)**, built 2026-08-21 — the first bundle containing §7. Supersedes 11 and 12 |
| `pubspec.yaml` | `1.6.1+13` (bumped in `c189138`) |
| Branches holding this work | all merged into `main`. §6 fast-forwarded in on 2026-08-21 as `f6cda00` and was pushed with the release commit; `origin/main` is level |

**Production is still on 1.4.1+9.** Internal testing has **12 (1.6.0)**, which is
§1–§6. **13 (1.6.1)** is built and adds §7. Promoting to production ships §1–§7
together, so the release notes and the QA surface are the whole list below, not
one section.

> **Read the Play Console, not this table, before assuming a version code is
> free.** On 2026-08-21 a rebuild was made at versionCode 12 on the strength of
> this file saying 12 was "built, NOT uploaded". It had been uploaded the night
> before, and Play rejected the bundle: "Version code 12 has already been used."
> This file lags whatever is done in the console by hand, so the console is the
> only authority on which codes are consumed.

**Status 2026-08-19: sections 1–4 are built, verified, and sitting on the
internal testing track. They are not on production**, so this file stays full.
Empty sections 1–4 when 10 is promoted, not before — **but not §5**, which
landed after 10 was uploaded and is in **1.5.1+11, built and verified on
2026-08-20 but never uploaded** (see below). The one thing gating promotion is the
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

### 5. Pet-friendly auth screens — NOT in versionCode 10

**This section is in no uploaded build.** It landed after 1.5.0+10 went to
internal testing at 11:55 on 2026-08-19, so promoting 10 does not ship it, and
this section must survive the emptying of the four above. It *is* in the
**1.5.1+11** bundle built and verified on 2026-08-20, which has not been
uploaded. Session records:
[`2026-08-19-auth-screen-redesign.md`](../sessions/2026-08-19-auth-screen-redesign.md)
and
[`2026-08-20-paw-trail-pinned-focus-and-1-5-1.md`](../sessions/2026-08-20-paw-trail-pinned-focus-and-1-5-1.md).

Login, register (email gate + step 1) and forgot-password rebuilt as one
surface: photo header with a rounded foot, brand lockup and a screen-specific
line; a paw-track trail behind the cream form; warm pet-voiced copy; a 36sp
heading that steps down to 28sp on narrow or text-scaled screens; the form
centred while it fits; and the header collapsing to a band while the keyboard is
up, which is the difference between a reachable Sign In button and one the
member has to go looking for.

**Two of these are fixes to live defects, not new design:**

- Secondary auth links were `AppColors.gold` on cream — **~2.7:1**, failing
  since those screens were written. They are navy now.
- The auth screens showed **dark** status-bar icons over the photograph, because
  an AppBar-less screen inherits whatever the previous one set. An
  `AnnotatedRegion` in the strip pins them light.

New shared widgets: `core/widgets/mp_paw_backdrop.dart` (`MpPawBackdrop` +
`MpCentredScroll`) and `MpFieldIcon` in `mp_text_field.dart`. All three screens
now take their header height from one rule, `MpBrandPhotoStrip.heightFor` — they
previously used two different multipliers while showing the *same* photograph.

Verified on a physical SM S947B including a simulated 320dp width; the
forgot-password success state and register step 1 were not verified as rendered
(step 1 needs the local backend). `flutter analyze` is unchanged at 21
pre-existing issues.

**Decided 2026-08-20 — pinned to the screen**, on the client's report that the
background "adjusted aswell to make way for the keyboard". The cause was not the
keyboard inset but the **header collapsing above the trail** (233dp → 108dp on
the test device), which moves the top of the box the trail is anchored to — a
125dp slide. `MpPawBackdrop` now takes a `keyboardInset` and pushes the trail
back down by however far its box top rose. Measured at **0.1px** of movement on
device while the header moved 125dp.

**Two further changes on 2026-08-20:**

- **A tap outside a field now drops focus.** Android and iOS deliberately keep
  focus when the outside tap is a *touch* — framework policy in
  `_EditableTextTapOutsideAction`, not a defect here — so the keyboard sat over
  the form until the member submitted or pressed Back. One `onTapOutside` in the
  shared `mp_text_field.dart` covers all 33 call sites; text fields share one
  `TapRegion` group, so field-to-field taps and the password eye are not
  "outside".
- **The circular badges are gone** from forgot-password (both states) and from
  the registration success screen (the gold shield and its particle burst), by
  client request. The success copy's fade had been gated behind the emblem
  landing, so removing it left ~385ms of blank cream; the reveal now starts on
  the first frame.

`mobile/test/auth_keyboard_test.dart` is the **first test file in this project**
and guards both fixes. Each was confirmed to fail on the unfixed code before
being trusted.

**Unverified as rendered:** the **registration success** screen — the one screen
whose layout and animation timing changed. Reaching it needs a completed
registration against the local backend, so it is in `main` and in the 1.5.1+11
bundle without ever having been seen.

### 6. The Home pet card, and a rebuilt tier colour system — NOT in 10 or 11

Added 2026-08-21 (`f6cda00`), shipped in **1.6.0+12** (and in 13). Session record:
[`../sessions/2026-08-21-pet-card-tier-redesign.md`](../sessions/2026-08-21-pet-card-tier-redesign.md).

**Three defects, not a restyle:**

- **The two top tiers were the same card.** De Luxe and Premium shared one
  surface (`0xFF111219`) and differed only in ink hue — **1.00:1** apart, so they
  were indistinguishable while swiping the Home carousel.
- **The prestige order was inverted.** Premium (₱9,999, the top tier per
  `scripts/seed.py`) wore cool silver while De Luxe (₱5,999) got the brand gold.
- **The Standard card had no shadow at all** against the cream scaffold — 1.07:1
  of separation, i.e. none.

`TierStyle` is now the single source for every colour a tier surface paints,
across a three-material ramp (linen → brushed navy → obsidian). Tier-to-tier
separation is **1.71:1**; every pair is measured against both gradient ends.
Gold went from seven elements on one card to the Premium skin alone.

The wallet meter gained a hierarchy — the plan's main pool takes a 20sp
ExtraBold balance, the other a compact row — and the two pools are ranked by
size and layout only. **Opacity is not available for ranking:** a dimmed
secondary fill measured 2.03:1 against its own track, under the 3:1 UI floor, so
a full Emergency bar read as spent. That was caught on a real device.

**Two corrections to long-standing repo claims:**

- `gold` on `navy` is **4.60:1, not 2.9:1** — `CLAUDE.md` carried the wrong
  figure for months. The real failures are gold on white (2.72:1) and on
  `surface` (2.54:1).
- The bundled Montserrat subsets carry 232 codepoints and **none of them is `₱`
  (U+20B1)**, so every peso figure in the app renders that glyph through the
  platform fallback. It has shipped that way for months; it is merely more
  visible now the balance is 20sp. Fixing it means re-subsetting font binaries —
  **not done, deliberately.**

**Verified by golden render only** — three tiers at 320dp and 393dp, and each
meter state per tier. **Not verified on hardware.** The last two rounds of
feedback on the card's corner emboss came from a real device precisely because
renders missed them, so treat device QA on Home as outstanding.

### 7. "Wallet" became "Benefit" throughout the app

First shipped in **1.6.1+13** — NOT in the 12 that testers currently have.
Added 2026-08-21 (`30882b4`, plus `49e8d2f` on the backend) at the client's
request: rename the bottom **Wallet** tab to **Benefit**, and drop the word
"wallet" from the app.

**This closes the gap recorded on 2026-08-07**, when the website renamed the two
annual pools to "benefit" and the app did not follow — so site and app disagreed
on the very word the rename existed to settle. Wording matches the site exactly
rather than inventing a third term: **"Preventive Wellness Benefit"** and
**"Emergency Benefit"**.

- Bottom nav: **Wallet → Benefit**, and the icon moved with the word.
  `account_balance_wallet` is a literal picture of a wallet, which is the thing
  the rename exists to stop showing; it is now `health_and_safety`, matching the
  category icon the backend already uses.
- Benefits hub: page heading → **Benefits**; the per-pet section → **Benefit
  balances**.
- Home pet card: the `BENEFIT WALLET` eyebrow → `BENEFITS`, plus the meter's
  semantics label and the no-plan copy.
- Claim form pool labels, and the hub card's semantics label.

**The backend had to change too, and it is not deployed.** The app renders
`400` details verbatim, so the first over-claim would have said "Insufficient
wallet balance — ₱X left in Ye-jin's Preventive Wellness Wallet" and undone the
rename. `49e8d2f` fixes `wallet_name` on the submit and resubmit paths, the
"Insufficient benefit balance" wording, and the launch email. **DEPLOYED to
prod 2026-08-21** as `dep-da61nogjo6nc73e31ts0` (confirmed `live`, the two prior
deploys now `deactivated`). The changed strings live only in 400 details, so they
are unverified end to end: seeing them needs a deliberate over-claim on a test
account.

Note the ordering this created — prod now answers "Insufficient benefit balance"
while Play production still serves 1.4.1+9, whose own UI says "Wallet". Harmless,
and it resolves when 13 ships.

**DB-backed copy was already correct** — verified by reading prod `GET /plans`:
no plan feature says "wallet", so plan cards were already showing "Preventive
Wellness Benefit". That was the trap the 2026-08-07 session warned about, and it
happened not to bite here.

Left with the word deliberately: code identifiers, file names, API paths
(`/members/me/wallet`), JSON fields (`wallet_centavos`), and the admin-facing
`wallet_name` in `admin/reimbursements.py` — matching the precedent the site set
when it kept its own admin internals.

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
