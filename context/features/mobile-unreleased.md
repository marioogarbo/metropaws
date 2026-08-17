# What is in the app but not on Play

**Purpose:** the standing answer to "what changed since the last release?" Update
it as mobile work lands; **empty it when a build ships**, and record the shipped
version in [`android-distribution.md`](./android-distribution.md).

| | |
| --- | --- |
| Live on Play | **1.4.1 (versionCode 9)**, published 2026-08-14 |
| `pubspec.yaml` | still `1.4.1+9` — **must be bumped before any build** |
| Branches holding this work | `main` (monthly), `feature/pet-records` (pet records) |

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

**Hard dependency:** the monthly endpoints do not exist in production yet.
Shipping this build before the prod backend deploy gives every monthly action a
404. Order is: prod backend deploy → then the AAB.

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
   Play rejection.
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

**The pet-records half has no such blocker.** If monthly needs to wait, it can
ship on its own from `feature/pet-records` rebased onto the last pre-monthly
commit — worth considering, since it fixes a dead end that affects members today.
