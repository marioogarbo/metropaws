# 2026-08-27 — Add a Pet and the claim form, rebuilt; and half a money fix found

Rebuilt the two longest forms in the app — **Add a Pet** and the
**Reimbursement Submit** tab — against published mobile-form research and
Android's edge-to-edge rules. Everything below was rendered on a real device
(Galaxy S947B, Android 16, gesture navigation, 384dp) against the **local dev
backend** over `adb reverse tcp:8000`. Nothing here is on Play.

Commits: `4cf65a0` (Add a Pet), `b5c01e1` (claim form). Both on `main` and
pushed; `origin/main` is level.

---

## The keeper: a money fix that was only applied to one side

On **2026-08-16**, `4ae5db9` ("backend: route emergency claims to the emergency
wallet") widened `EMERGENCY_CATEGORY_NAMES` to
`{"emergency", "emergency stabilization"}`, because the seeded category is
literally **"Emergency Stabilization"** and matched neither pool's name before.
That closed the alignment-register item recorded in
[`2026-08-15-emergency-pool-and-preactivation-claims.md`](./2026-08-15-emergency-pool-and-preactivation-claims.md).

**The app has its own copy of the same rule, and nobody updated it.** Verified
by `git log -S`: `reimbursement_screen.dart` matched
`trim().toLowerCase() == 'emergency'` before that commit and still did on
2026-08-27 — **eleven days** in which the server routed an emergency claim to
the Emergency Wallet while the app showed, and validated against, Preventive
Wellness.

What a member saw on the Submit form, reproduced on device before the fix:

| | App (before) | Server |
| --- | --- | --- |
| Pool named | Preventive Wellness Benefit | Emergency Wallet |
| Balance shown | **₱3,301.00** | **₱900.00** available |
| Amount validation | against ₱3,301.00 | against ₱900.00 |
| Direct-to-provider pay | offered | refused for emergencies |

So the app would accept a ₱2,000 emergency claim the server cannot fund, and
would offer a payout path the server rejects.

Fixed in `b5c01e1`: `_kEmergencyCategoryNames` now mirrors the backend set, with
both call sites going through `_isEmergencyCategoryName`. Confirmed on device —
choosing "Emergency Stabilization" now shows *Emergency Benefit · ₱900.00 left*.

**No money moved wrongly.** The 2026-08-15 read-only audit found no emergency
claim has ever been filed in either database, and that remains the reason this
was cosmetic-in-practice rather than expensive.

**Why it hid:** the register tracked the *behaviour* ("emergency claims draw on
the preventive pool"), and the backend fix made that statement true again, so
the item was closed. Nothing tracked that the rule exists in two languages. The
app is not a thin client here — it independently decides which balance to show
and what to validate against, so any rule the server owns and the app mirrors
can diverge silently in exactly this way.

**Still open, and it will recur.** Both sides still match on a *name string*.
Renaming that category in the admin UI breaks both again. The backend file
already names the durable fix — an admin-editable `ServiceType.is_emergency`
flag — and until that exists the two lists must be edited together. Deliberately
not built today; see "Not done" below.

---

## Also found

- **`errorMaxLines` defaults to 1 in Material**, so
  `"Insufficient Emergency Benefit balance — ₱900.00 left"` rendered as
  `"…balance — ₱90…"`, hiding the figure the member needs to act on. Set to `3`
  in **both** input decoration themes in `theme.dart` — app-wide, every form.
- **A `Form`-level `autovalidateMode` reddens every field the first time any one
  changes.** Flutter marks the whole form interacted, not the field. On Add a
  Pet, choosing "Dog" lit up the name, breed and both date fields before the
  member had reached them. Validation timing belongs on each field.
- **The Android back gesture bypassed the Add-a-Pet step machine entirely** —
  three photos and ten fields in, one swipe discarded everything, unasked.
- **31 February was reachable** in the old Add-a-Pet birth dropdowns, and so was
  a future birth date; both were sent to the backend as-is.
- `payment_result_screen.dart` and `subscription_screen.dart` are **dead code** —
  nothing imports `subscription_screen`, and `payment_result_screen` is imported
  only by it. The live post-checkout surfaces are `_DoneStep` in
  `add_pet_screen.dart` and `_SuccessBody`/`_FailureBody` in
  `plan_selection_screen.dart`.
- `mobile/.impeccable.md` **does not exist**, though `mobile/CLAUDE.md` twice
  says in MUST language to read it before any UI work. The tokens it is cited
  for are already inline in `CLAUDE.md`.

---

## The date picker: four designs, three rejected

Worth recording because the research points the wrong way for this control, and
the next agent will find the same papers.

1. **Three dropdowns** (original) — 12 + 31 + 37 items scrolled inside a popup
   pinned to a field too narrow to print "Birth month" in full.
2. **Three typed numeric boxes** — what the published guidance recommends for a
   *human* date of birth. Built and verified on device, then **rejected by the
   client**. The finding is about long option lists and ambiguous single fields;
   neither describes a 12-item list of month *names*. It forced a March → 3
   mapping on a membership with mixed digital comfort, and needed an echo to
   paper over ambiguity the names never had. GOV.UK hit this from the other
   side: their numeric month box had to be taught to accept "March"/"Mar".
3. **A grid-picker sheet per part** — fixed the scrolling, but meant **three
   separate modal trips to state one date**, with no way to see month, day and
   year together.
4. **A three-column wheel** (shipped, client's choice from a reference image) —
   one field, one sheet, all three columns visible and adjustable together.

The wheel's usual objection — that a birth year is an endless spin — is aimed at
human dates with a ~118-year range. A pet's runs to 37 and clusters in the last
fifteen.

Two details that are load-bearing rather than decorative:

- **"Not sure" is the first entry on the day wheel**, not a checkbox beside it.
  The exact day is optional (`birth_day` is nullable because pets are adopted
  and rescued), and a wheel otherwise forces a value in every column.
- **Only the month wheel loops.** Every column opening on its first item left
  the top half of the sheet blank, which reads as a rendering fault. Month is
  cyclic so it wraps and opens on the current month; day and year keep their
  boundaries, where the empty space is meaningful — nothing precedes "Not sure",
  nothing is newer than this year, and a looping year would put 1990 after 2026.

The **age echo** survived all four designs, because it does a job no control
can: 2013 is as valid a year as 2023, and only "about 13 years old" gives a
mis-entry away.

---

## What the forms look like now

**Add a Pet** — Details → Photos → Plan → Done (was Details → Health Card →
Plan, with ten fields *and* three photos on step 1 and one optional upload alone
on step 2).

- Primary action pinned in a footer that claims the gesture-bar inset.
  Edge-to-edge is enforced from Android 15 and cannot be opted out of from 16.
- `PopScope` routes the system back gesture through the step machine, and still
  returns `true` when the pet already exists server-side after a partial failure.
- Photos are a checklist with per-slot guidance and a help sheet; camera offered
  alongside gallery (system photo picker, so no media permission — the
  2026-07-17 rejection rule still holds).
- The pay hand-off names the pet, the plan and the total, and the button reads
  "Pay ₱2,999". Monthly states that benefits vest later **before** the money
  moves (Agreement §5.7).
- The success half shows the pet's own photo. It used to promise **"session
  credits"** — a benefit the app no longer runs; the plan funds the Benefit
  Wallet.

**Reimbursement Submit** — five beats: what happened → how it gets paid → the
visit → how much → proof.

- One `_BenefitCard` states the pool, replacing a `bodySmall` line under the pet
  field **plus three separately hand-styled banners** scattered down the form,
  so the balance and the reason it can't be spent were never in view together.
- `blockedReason` is computed once and feeds both the card and the pinned
  footer, so the disabled button and the text above it cannot disagree.
- The two claim paths are cards, not a dropdown — they change who gets paid,
  what counts as proof, and whether the date may be in the future.
- The submit footer sits in the **tab's own Column**, not
  `Scaffold.bottomNavigationBar`, which would show it on My Claims too.

---

## Verified on device, not from the analyser

`flutter analyze` read clean on the changed files at every step and caught none
of these. Each needed the app rendered:

- one tap on "Pet type" reddening the entire Add-a-Pet form
- "Birth mon…", "Vaccination…" and "Mon…" truncating in three separate layouts
- `"…balance — ₱90…"` clipped by `errorMaxLines`
- the wheel sheet opening with its top half blank
- "Date of birth" printing twice, as group heading and floating label
- the app bar reading "All done!" over a body that said "One step left"

Consistent with the 2026-08-18 and 2026-08-19 sessions: static analysis has now
missed the defects that mattered three sessions running.

---

## Not done

- **`ServiceType.is_emergency`** — the durable fix for the name match. Backend +
  admin + app; deferred by the client ("let's talk about that later"). The
  mirrored list is correct for the current category names, so nothing is broken
  while it waits.
- **`_ResubmitSheet`** — the second form on the reimbursement screen (full-edit
  resubmit for a `needs_info` claim) still carries the old patterns. It will
  drift from the Submit form now.
- **The subscription success screen** was never rendered here — it needs a
  completed payment and there is no dev mock-pay route. The client checked it
  separately and reported it acceptable.
- Test pets left on the **local dev** database: "Mochi" (Standard, registered,
  unpaid) and possibly "Kobe".


---

# 2026-08-28 — 1.7.0 published, and the Play listing art rebuilt

The session ran past midnight. `1.7.0+14` was submitted 2026-08-27 23:58 and
published 2026-08-28; the listing art was rebuilt the same night.

## The release

Production went **1.4.1+9 → 1.7.0+14** in one jump, so versionCodes 10–13 never
reached a member and the release notes had to cover §1–§8 of
[`mobile-unreleased.md`](../features/mobile-unreleased.md), not one section.
Play's release-notes field caps at 500 characters; the shipped note is 423.

**The internal testing track is now behind production** — it holds 12 (1.6.0)
while production has 14. Track priority is `internal > production` **per Google
account**, so every tester is pinned to 1.6.0 and will not receive 1.7.0,
including the emergency-pool fix, however often they check. The symptom is
silent: their Play page reads "up to date".
[`android-distribution.md`](../features/android-distribution.md) predicted this
exact failure mode before it happened; it is now marked as sprung.

## The listing art

The published screenshots were raw app captures at **432x930 with an alpha
channel** — undersized against Play's 1080x1920, non-compliant (Play rejects
alpha), and showing pre-redesign UI: "Wallet" in the nav, a plan badge removed
from the Home header, the old pet card. `website/public/app-*.png` are the same
files and are still stale.

Rebuilt as one lifestyle hero, four framed product shots, and a 1024x500 feature
graphic. Tooling committed at [`tools/store-art/`](../../tools/store-art/), which
holds the full method; only the decisions are recorded here.

**The scene is AI-generated; the phone screen never is.** Play requires
screenshots to represent the actual app, and a generated UI is invented text in a
layout that is not ours. Gemini renders the room with a flat green chroma screen;
the real capture is keyed in afterwards, using the render's own rounded corners
as the alpha.

**Two scenes were needed and they do not swap.** The first attempt put the phone
screen at **12.5% of frame width** — about 135px once scaled to 1080, which makes
the app unreadable and defeats the point of a screenshot. A regeneration asking
for the phone as *"the closest object to the lens"* filling *"roughly one third
of the total image height"* landed at 25.3% and reads. The close shot makes the
hero; a wider room shot makes the banner, because cropping the close-up to
landscape cuts the phone mid-screen and collides its own UI with the headline.
Both were tried the wrong way round first. **A model responds to a proportion,
not to "large".**

## Demo data curated on dev — why "Alex" changed

The captures came from the **dev Supabase** (`APP_ENV` defaults to `dev`; there is
no local throwaway database, so this is shared state). Changed through the API,
not by writing to the database:

- Alex's breed `None` → **Poodle**. "Golden Retriever" ellipsised to "Golden
  Retriev…" on the Home card, and the photo is a cream poodle regardless — the
  old website screenshot labelled the same dog "Poodle".
- Alex given a birth date; the Digital Pawprint read **"0 yrs"** without one.
- Gelly's breed set the same way.
- **Mochi deleted** — a test pet created earlier in this session. "Kobe" was never
  created at all, which confirms the pet row is not written until Activate.

## The Digital Pawprint screenshot contains a live QR token

The pawprint screen renders a scannable `qr_token`. The published screenshot
therefore carries a working QR of whatever account it was shot from. **These came
from dev, so the token does not resolve against production** — but re-shooting
the listing against prod would put a real member's token in a public store
listing. `tools/store-art/captures/` and `scenes/` are gitignored for the same
reason: a capture also holds the member's name, pet names and balances, and this
repository is public.

## Two defects that kept a screen out of the listing

- **`plan_selection_screen.dart` does not format prices.** It interpolates raw
  integers in six places, so the screen where a member commits to ₱9,999 renders
  **"₱5999"** and **"₱9999"** with no thousands separators, unlike everywhere
  else in the app. The screen was dropped from the listing rather than fixed and
  shot, because the screenshot would then show behaviour the published 1.7.0 does
  not have. That also costs the listing its "pay monthly" story, which is this
  release's headline feature. **Client decision 2026-08-28: leave it.**
- **Plan feature strings still read "Wallet"** — visible as "₱4,000 Preventive
  Wellness Wallet" on that same screen. Not a new finding: item 5 of
  [`document-system-alignment.md`](../features/document-system-alignment.md)
  already names these exact `seed.py` strings. This is confirmation they are
  still live in a shipped build. **Client decision 2026-08-28: leave it.**

## Still open

- The store **descriptions have not been touched since 1.4.1** — no mention of
  monthly instalments, pet health records, or the wallet→benefit rename.
- `website/public/app-*.png` remain stale, undersized and RGBA.
- Tablet screenshot slots are empty; the track covers "Phones, Tablets, Chrome
  OS, Android XR". Optional, but the app has no distinct tablet layout.
- A debug build is installed on the test device. It must be uninstalled before
  the Play build can be installed — Play App Signing means the two cannot replace
  each other.
