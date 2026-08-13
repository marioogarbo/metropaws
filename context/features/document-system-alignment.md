# Documents vs system — the alignment backlog

**Status:** open, no work scheduled. Raised 2026-08-13 when Membership Agreement
Rev. 5A and Member Manual Rev. 3C went live (see
[`member-documents.md`](./member-documents.md)).
**Owns:** nothing yet — this is a register, not an implementation.

## The rule Mario set

> "What's in the user manual and agreements is the real deal. If we need to
> update the system to match what's in the manual or agreement, we need to
> update it ASAP."

The documents are the contract. The system is the implementation. Where they
disagree, **the document wins by default** and the system moves.

**But a gap has two legal fixes, not one.** Rev. 5A is published, so every
promise in it is enforceable against MetroPaws whether or not the code does it.
For each gap below the question is which is cheaper and more honest:

- **Build it** — the document describes what the business actually wants.
- **Amend the document** — the document describes an intention the business is
  not ready to operate. Shipping a promise you can't keep is the worse outcome.

Amending is not a cop-out. Several items below describe an operating model that
does not exist yet in any form, and quietly running the old one under the new
contract is the exposure this register exists to track.

## What already matches

The money is right. Plan fees and benefit pools agree exactly across the manual,
the seed data and the site:

| Plan | Manual §4 / §2 | [`backend/seed.py`](../../backend/seed.py) |
| --- | --- | --- |
| Standard | ₱2,999/yr · ₱2,000 wellness + ₱300 emergency | `price: 2999` · `200_000` / `30_000` centavos |
| Deluxe | ₱5,999/yr · ₱4,000 + ₱900 | `price: 5999` · `400_000` / `90_000` |
| Premium | ₱9,999/yr · ₱7,000 + ₱1,500 | `price: 9999` · `700_000` / `150_000` |

Nothing in the website hardcodes a price — it all comes from the backend, so
there is no third copy to drift.

---

## 1. The settlement model is inverted — the big one

**Agreement §6, §11, §12. Manual §6.**

| | Agreement Rev. 5A | System today |
| --- | --- | --- |
| Normal path | Member requests authorization **before** service → MetroPaws verifies the provider → issues a reference number or QR → provider delivers → **MetroPaws pays the provider directly** | Member pays the provider, submits a receipt, admin reviews, **MetroPaws reimburses the member** |
| Reimbursement | **Exception only** (§12): urgent care, system outage, provider refusal, geographic limits, or written management approval | The only path there is |

The agreement's own Revision Basis line is "Replacement of Wellness Wallet and
routine reimbursement with advance Service Authorization and direct Provider
Settlement". The system is the thing being replaced.

**Correction (2026-08-13, after Romy asked how the app deducts when MetroPaws
pays the provider): more of this is built than first recorded.** There is no
entity *named* Service Authorization, but `Reimbursement` with
`payout_target = provider` is one in all but name — its own docstring calls it
"a pre-authorization request to pay a verified ReimbursementProvider directly
for an upcoming scheduled service". The flow that exists:

| Rev. 5A §6 stage | Built? | Where |
| --- | --- | --- |
| Service Request | ✅ member files with a **future** appointment date | `POST /reimbursements`, `payout_target=provider` |
| Eligibility Review | ✅ pool, plan year, category, duplicate-receipt checks | [`reimbursement_utils.py`](../../backend/reimbursement_utils.py) |
| Provider Verification | ⚠️ admin vets the provider once, on creation — not per request | `/admin/providers` → `ReimbursementProvider` |
| Authorization | ⚠️ approval sets an approved amount, but issues **no reference number or QR** and no explicit validity window | `PUT /admin/reimbursements/{id}/review` |
| Service Completion | ❌ no provider-side confirmation | — |
| Provider Settlement | ✅ offline, recorded by admin | `PUT /admin/reimbursements/{id}/mark-paid` |

So the gap is narrower than "not built": it is **switched off, unnamed, and
missing the artifact**. `direct_provider_payment_enabled` defaults to false
([`backend/routers/settings.py:27`](../../backend/routers/settings.py)) and was
verified false in production on 2026-08-13 via the public
`GET /settings/mobile-config`. Admin toggle: `/admin/settings` →
"Direct-to-Provider Payments".

Real remaining gaps on this item: no authorization reference/QR, no validity
expiry, no provider acceptance step, no service-completion confirmation, and
emergency categories are excluded from direct pay by design
(`is_direct_pay_eligible_category`) even though §13 contemplates them.

`Booking` (models.py:203) is a different concept — an appointment with a
`ClinicPartner`, behind its own `booking_enabled` flag, also false in production.

**Exposure:** a member who reads §6, does not obtain authorization, and gets
told to pay and claim, is being run under a process the contract calls the
exception. And §12's "no reimbursement is guaranteed merely because the Member
paid a provider" now sits over a product whose only path is to pay and claim.

**Cheaper fix:** given the correction above, turning the flag on gets most of
§6 operating today. The decision to make with Romy is whether direct-to-provider
becomes the *default* path (which is what §6 says) or stays an option alongside
reimbursement — and whether the missing authorization artifact (reference/QR,
expiry, provider acceptance) is worth building or worth striking from §6.

### The operational trap — no retro-recording

`_validate_service_date(allow_future=True)` **rejects a past appointment date**
for a provider-target request
([`backend/routers/reimbursements.py:68`](../../backend/routers/reimbursements.py)),
and the window is today → +60 days (`PROVIDER_MAX_FUTURE_DAYS`). There is also
no admin-side create endpoint — `POST /reimbursements` requires
`require_member`, so only the member can file, from the app.

**Consequence: if MetroPaws pays a provider before the member files, the benefit
cannot be deducted.** The request can't be back-dated and an admin can't create
it. The only remaining route is a member-payout claim, which would pay the
member for money MetroPaws already spent. Sequence is therefore mandatory:
member files → admin approves → MetroPaws pays → admin marks paid.

Deduction happens at **`approved`**, not at `paid` — `USED_STATUSES =
(approved, paid)` in [`reimbursement_utils.py`](../../backend/reimbursement_utils.py).
Marking paid afterwards does not deduct twice.

### Open decision — the future-date rule on direct-pay requests

Raised by Mario, 2026-08-13: *"I think we should offer or remove the must future
date."* Agreed that emergency stays pay-then-reimburse — that part is working as
intended and is not in question.

Today's rule for `payout_target=provider`: date must fall in **today → +60 days**.
Same-day already works; it is *past* dates that are rejected. The rule exists
because this object was designed as a pre-authorization, and Rev. 5A §6/§7 do
require authorization *before* the visit — so simply deleting the rule pushes the
product further from the agreement, not closer, and lets members bypass advance
notice entirely.

But the trap above is real: a service that already happened, which MetroPaws
agreed to settle directly with the provider, currently cannot be recorded by
anyone. Three ways out:

| Option | Effect | Cost |
| --- | --- | --- |
| **A. Drop the past-date rejection** for provider-target | Members can file after the fact | One line. But advance authorization becomes unenforceable, contradicting §6/§7, and the member-facing flow stops meaning "pre-authorization" |
| **B. Admin-only retro path** — an admin endpoint that records a direct provider settlement for a past date | Back-office correction, member flow unchanged | New endpoint + admin UI. Maps cleanly onto §12's "written management-approved circumstance" |
| **C. Grace window** — allow provider-target a few days into the past | Covers the common "filed the day after" case | One constant. Still erodes §6, just less |

**Recommendation: B.** Retro-recording a settlement is a staff correction, not a
member self-service action, and §12 already provides the contractual language for
it. It also closes the "no admin-side create endpoint" half of the trap, which A
and C leave open — under A, a member who never files still leaves the benefit
undeducted with no staff remedy.

Whichever is chosen, note the knock-on: `_validate_service_date` currently
enforces direction by a single `allow_future` boolean. A third case (admin,
either direction) wants that replaced with something clearer than a flag
parameter — see the repo's clean-functions guidance on flag arguments.

Not built. Decide with Romy alongside the authorization-artifact question above.

## 2. Vesting is contractual but unenforced

**Agreement §5.4, §5.5, §5.8.**

Monthly subscribers get digital access after the first cleared payment, and full
planned-service eligibility only after **6 (Standard) / 8 (Deluxe) / 10
(Premium)** consecutive cleared monthly payments. Emergency support needs 3/3/4.
§5.8 forbids paying for anything obtained before the eligibility date.

`grep -ri "vesting\|consecutive" backend` returns nothing outside `.venv`. There
is no consecutive-payment counter, no eligibility date, no gate on claim
submission. A monthly member can submit a claim on day one.

**Note this cuts both ways.** The thresholds were just raised from 2/3/4 to
6/8/10 — that is a longer wait, and it is now published. If the business does
not intend to hold monthly members out for ten months, §5.5 is the thing to fix,
not the code.

**Cheaper fix:** almost certainly amend, unless the business genuinely wants
vesting. If it does, this is the highest-value gap to build — §5.4 says the
whole point is to stop people enrolling purely to claim immediately.

## 3. Advance notice is not collected or enforced

**Agreement §7. Manual §6, §7.**

The agreement sets minimum notice — 1 business day for routine consultation, 2
for vaccination/deworming, 2 for grooming — and says a request does not confirm
an appointment, authorizations expire, and reschedules may need revalidation.

None of this exists. There is no intended-service-date field anywhere, so
nothing can be measured against a notice window. Follows item 1: without a
Service Request there is nothing to attach notice to.

## 4. Member status labels don't exist

**Agreement §5.7.**

The agreement tells members the app may show: Pending Onboarding, Digital Access
Active, Vesting in Progress, Fully Service-Eligible, Authorization Restricted,
Suspended, Expired, Under Review — and makes the member responsible for checking
that status before getting a service.

`Member` ([`backend/models.py:33`](../../backend/models.py)) has **no status
column**. Membership state is derived from `Payment` rows and
[`plan_term_utils.py`](../../backend/plan_term_utils.py). Nothing surfaces
anything resembling that vocabulary.

Making a member responsible for reading a status the product never shows is a
weak position. Either surface real status or drop the list from §5.7.

## 5. "Wallet" terminology is retired in the documents and everywhere in the code

Manual Rev. 3C's closing note is explicit: it *"replaces Wallet terminology with
Benefit terminology"*. Agreement §2 goes further — a benefit limit is "not cash,
stored value, a deposit account, legal tender or an amount withdrawable by the
Member", which is precisely what the word *wallet* implies.

**388 occurrences of "wallet"** across backend, website and mobile. Not just
internals — member-facing plan features in
[`backend/seed.py`](../../backend/seed.py) read "₱2,000 Preventive Wellness
Wallet", "₱300 Emergency Wallet", and the tagline *"Your wallet goes where your
pet needs it most."*

This is the **cheapest high-value item in the register** and the one most likely
to be noticed: a member reads "Wellness Benefit" in the manual and sees "Wallet"
in the app on the same day. Two distinct pieces of work:

- **Member-facing strings** — seed features, taglines, app and website copy.
  Low risk, do this first.
- **Column names** (`reimbursement_wallet_centavos`, `emergency_wallet_centavos`)
  — a migration touching pricing logic. Only worth doing alongside item 1, if at
  all. Internal names carry no legal weight.

## 6. PawPoints — 4 of 9 earning activities are missing

**Manual §9.** The manual publishes a 9-row earning table. `POINTS_BY_TIER` in
[`backend/paw_points_utils.py:5`](../../backend/paw_points_utils.py) implements
5, and `PawPointsActivityType`
([`backend/models.py:429`](../../backend/models.py)) matches.

| Manual activity | Standard / Deluxe / Premium | In code |
| --- | --- | --- |
| Membership Activation | 100 / 200 / 300 | ✅ `membership_activation` |
| Complete Pet Profile | 50 / 75 / 100 | ✅ `pet_profile_completed` |
| Authorized Vet Service | 20 / 30 / 40 | ✅ `service_deployed_vet` |
| Authorized Grooming Service | 15 / 25 / 35 | ✅ `service_deployed_grooming` |
| Membership Renewal | 150 / 300 / 500 | ✅ `membership_renewal` |
| Wellness Reminder Completed | 10 / 15 / 20 | ❌ |
| Successful Referral | 200 / 250 / 300 | ❌ |
| Event Attendance | 75 / 100 / 150 | ❌ |
| Pet Birthday Bonus | 25 / 50 / 75 | ❌ |

Where implemented the values match exactly. Referral and birthday bonus are
self-contained and could ship without item 1; reminder-completed depends on
wellness reminders existing.

The manual also prints a 7-tier rewards catalogue (250 → 5,000 pts). The
`PawPointsReward` table is admin-managed and **not seeded**, so the live
catalogue is whatever an admin entered — verify it against the manual before the
manual is handed to a member. The manual hedges these as "Sample", which helps.

## 7. The Digital Pet Passport stores a photo, not a record

**Manual §5. Agreement §14.** Raised by Romy on 2026-08-13: *"panu iuupload yung
mga records ng pets ng members, say vaccination and others?"*

The manual publishes a Pet Passport feature table promising a Vaccination Record
that "tracks vaccination history and upcoming due dates", plus grooming and
consultation records and reminder support.

What exists on `Pet` ([`backend/models.py:72`](../../backend/models.py)) is a
single `vax_card_url` — **one image of the vaccination card**. No vaccine name,
no date administered, no next-due date, therefore no reminders. Eight identity
photo slots are modelled in detail; the medical record is one file field.

| Manual promises | Reality |
| --- | --- |
| Vaccination Record with history + due dates | one `vax_card` image per pet |
| Grooming / Consultation Record | `ServiceLog` — admin-only, free-text notes + service type |
| Reminder Support | nothing |

### Nobody can upload a vaccination card after registration

Confirmed 2026-08-13, Mario's report. **The member can only attach the card
during pet registration. If they skip that step, there is no way back in.**

The gap is UI-only — every other layer works:

| Layer | State |
| --- | --- |
| Backend `PUT /pets/{id}` | ✅ accepts `vax_card` ([`pets.py:164,220`](../../backend/routers/pets.py)) |
| `ApiService.uploadVaxCard` | ✅ exists ([`api_service.dart:678`](../../mobile/lib/core/services/api_service.dart)) — **dead code, zero callers** |
| Registration (`add_pet_screen`) | ✅ `_pickVax` at line 229, skippable |
| Pet profile (`pet_profile_screen`) | ❌ `_VaxSection` (line 579) is a `StatelessWidget` that only *views* |

Worse, the empty state reads *"Contact your clinic to upload your vaccination
record"* ([`pet_profile_screen.dart:~620`](../../mobile/lib/features/member/screens/pet_profile_screen.dart)).
Clinics **cannot** upload — the clinic scanner only reads `vax_card_url` to show
a "💉 Vax ✓" badge. The copy sends members down a path that does not exist.

**Staff cannot upload either.** `PUT /admin/members/{member_id}/pets/{pet_id}`
([`admin.py:647`](../../backend/routers/admin.py)) takes a JSON `PetUpdate` body,
no file. So a member who skipped the step has no route at all: not the app, not
the clinic, not support.

**Deliberately not built — Mario, 2026-08-13.** Deferred to focus on claims.

When picked up, it is small: make `_VaxSection` stateful and mirror
`_PhotoCompletionSection` (line 918), which already solves this exact problem for
identity photo slots 4–8 — pick, size-check, upload, hand the refreshed `Pet`
back through `onPetUpdated`. Reuse `uploadPetPhotoSlot`, which is generic over
the field name and already returns `Pet`; `uploadVaxCard` returns `void` and
should be deleted or made to delegate. Fix the empty-state copy at the same time.
Match registration and stay images-only (`ImagePicker.pickImage`) even though the
backend also allows PDF, unless a file picker is worth adding.

The larger gap remains: still a single image, not a record. A `PetRecord` table
(pet, type, date, next-due, file, notes) plus an admin upload endpoint is what
the manual's table actually describes.

## 8. Wellness Score is promised and does not exist

**Agreement §14.** Names a "Wellness Score" and constrains it — it "reflects
verified engagement only and does not guarantee health". `grep -ri
"wellness_score" backend` returns nothing. Either build it or strike the mention;
a defined term with no referent is loose drafting in a live contract.

## 9. Schedule C — the app requirements we published against ourselves

Schedule C is internal and deliberately **not** on the public page (see
[`member-documents.md`](./member-documents.md)), but it is the document's own
checklist for the app, and it is a fair summary of what item 1 would require:

- Display the authorization requirement before booking confirmation.
- Record agreement version, Plan Schedule version, timestamp, Member ID and
  acceptance verification. *(Partly done — `agreement_version` and
  `agreement_accepted_at` are on `Member`; there is no Plan Schedule version.)*
- Show the approved MetroPaws amount and estimated Member share before service.
- Show authorization status, expiry, provider acceptance and a cancel button.
- Prevent the provider being represented as paid until settlement confirmation.
- Present reimbursement only inside an approved exception workflow.

§22 also says the platform should record "device or IP information where
available" at acceptance. It does not.

## 10. §5.5 — the site is one edit ahead of the PDF

Carried from [`member-documents.md`](./member-documents.md): the published page
reads six / eight / ten; MP-CON-001 as supplied reads "two (6)", "three (8)",
"four (10)". Romy owes a reissued PDF, or confirmation that the words were right
and the site is wrong. Deliberately not chased yet — Mario's call on 2026-08-13.

---

## Suggested order when this gets picked up

1. **Decide item 1 with Romy.** Authorization-first or reimbursement-first? Every
   other item's cost depends on the answer, and it decides whether §6/§12 get
   built or amended.
2. **Item 5, member-facing strings only.** Cheap, visible, no dependency.
3. **Item 2.** Confirm whether vesting is real. If not, amend §5.5 — which is
   the same conversation as item 10, so raise them together.
4. **Item 6**, referral + birthday bonus. Self-contained.
5. **Item 7** (pet records) is independent of item 1 and Romy has already asked
   for it — scope it alongside item 5.
6. Items 3, 4, 8, 9 follow item 1 and are not worth scoping before it.

## Source documents

`C:\Users\mario\Downloads\` as supplied by Romy on 2026-08-12:

- `MetroPaws_Member_Manual_Rev3C_Authorization_Wellness_Benefit_Edition.pdf`
  (1,452,321 bytes) — also published at `website/public/docs/member-manual.pdf`
- `MP-CON-001_..._Rev5A_..._Edition_1.pdf` (251,752 bytes) — transcribed into
  [`website/app/terms-of-service/page.tsx`](../../website/app/terms-of-service/page.tsx).
  Note the `_1` suffix: the copy **without** it is the superseded July version,
  238,337 bytes.
