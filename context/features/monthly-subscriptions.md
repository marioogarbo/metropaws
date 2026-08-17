# Monthly subscriptions and vesting

**Status:** backend complete, on `main`, and **live on dev**
(`metropaws-backend-dev:20260817-103725`, 96 paths / 118 operations). **No mobile
UI**, so no member can reach it yet. Production has the **schema** (migrated
2026-08-17) but not these endpoints — its next deploy is the first this session
that will move the route surface, by exactly one path.
**Decided 2026-08-16** by Mario: monthly is wanted, for members who can't afford
the annual fee or aren't ready to commit.

Governed by Membership Agreement Rev. 5A §5.2–§5.10. Those sections are the spec
— read them at [`/terms-of-service`](../../website/app/terms-of-service/page.tsx)
before changing anything here.

## The rules, and where they live

| Rule | §  | Code |
| --- | --- | --- |
| First cleared instalment buys digital access only | 5.3 | `membership_status.status_for` |
| Benefits open after N consecutive cleared payments | 5.5 | `Plan.vesting_*` columns |
| Late payment may reset the qualifying period | 5.6 | `subscription_utils.is_in_default` + `record_cleared_payment` |
| No benefit for a service predating eligibility | 5.8 | `*_eligible_since` stamps |
| Annual members skip vesting entirely | 5.9 | the **absence** of a Subscription row |

Thresholds seeded from §5.5: Standard **6** planned / **3** emergency, De Luxe
**8** / **3**, Premium **10** / **4**.

**Emergency opens before planned services**, and that ordering is what resolves
the §5.5 contradiction — the table reads "After two (6) / three (8) / four (10)",
words disagreeing with numerals, while the emergency column is unambiguous at
3/3/4. Under the words, emergency would open later than or level with the far
larger planned benefit, making that column meaningless. The numerals are
therefore intended. Full argument in
[`document-system-alignment.md`](./document-system-alignment.md) item 10.

## Five decisions that will look arbitrary in a diff

**1. Subscriptions are per PET, not per member.** Plans are granted per pet and
`Payment` already carries `pet_id`, so a member may hold one pet annually and
another monthly. `pet_id` is unique, and `start_subscription` reuses the existing
row when a member cancels and returns — a second insert would violate the
constraint, and reusing avoids the duplicate-row class of bug that `PetService`
and `PlanService` both needed constraints to stop.

**2. An annual member has NO row.** That absence *is* §5.9. Nothing has to
special-case the annual path, and no migration had to backfill 23 existing
members.

**3. Thresholds are columns on `Plan`, not constants.** §5.5 allows them to
change "through an officially approved Plan Schedule", and a name-keyed lookup is
precisely what left the Emergency Wallet unreachable for months (see
`reimbursement_utils.EMERGENCY_CATEGORY_NAMES`).

**4. Default is DERIVED, never swept.** This backend has no scheduler and no
background workers — the architecture note in `backend/CLAUDE.md` is explicit —
so nothing could mark a subscription late on a timer. `is_in_default` reads it
from `next_due_on` the way `plan_term_utils` reads expiry from
`plan_activated_at`. Default is always current and there is no cron job to be
forgotten. Lateness is judged at the next payment, the only moment the answer can
change.

**5. Eligibility DATES are stored, not just a counter.** §5.8 refuses a service
obtained before the eligibility date "even if the Member later completes the
required monthly installments". A counter has no memory of *when*, and a §5.6
restart destroys the run that produced it — so the date is stamped at the moment
the threshold is crossed, and surrendered on restart.

## The money invariant

`_grant_plan` splits on `Payment.subscription_id`:

- **instalment one** → activates the plan (`grant_plan_to_pet`) and counts
- **every later instalment** → counts only

This is not a nicety. `grant_plan_to_pet` deletes and rebuilds the pet's
`PetService` rows and resets `plan_activated_at`, and `wallet_usage` windows on
that timestamp — so re-granting monthly would hand a subscriber a **fresh
allowance twelve times a year** while they paid for one. Pinned by
`tests/test_grant_plan_installments.py`.

Instalments still send a receipt (money changed hands) and award **no** PawPoints
(points mark joining or renewing, not paying an instalment of something that
already exists).

The link is a foreign key rather than an amount comparison on purpose:
price-matching is the same fragile trick that broke the Emergency Wallet.

## Collection: member-initiated, by necessity and by luck

There is no scheduler to bill on a timer, and PayMongo has no saved card to bill
while only QR Ph is active (see
[`paymongo-payment-methods-blocker`](./credential-exposure-2026-08.md) context and
the register). Both problems disappear if the member pays from the app —
`POST /payments/installment` — which is how utilities and tuition are already
paid here.

That reframes reminders as an **enhancement, not a prerequisite**. The trigger
question (Render cron service / external scheduler hitting a protected endpoint /
admin "send this month's invoices" action) is still open, but nothing is blocked
on it.

`POST /payments/checkout` with `cadence: "monthly"` opens the arrangement.
`cadence` defaults to `"annual"`, so the app already on Play is unaffected. No
Pack Discount applies to instalments — it is 15% off an *annual* plan as a
joining incentive, and per-instalment it would discount the same year twelve
times over.

## Not built

- **The entire mobile UI.** No monthly option at signup, no vesting display, no
  "pay next instalment" action. This is the bulk of what remains and it is its
  own release cycle — AAB plus Play review. `WalletPetOut` already serves
  everything the app needs: `membership_status`, `membership_status_label`,
  `subscription_next_due_on`, `subscription_payments_made`.
- **Reminders** before an instalment falls due, and after it lapses.
- **§5.6 admin restore** — the discretionary "restore to last approved
  good-standing status" half of the policy. Only the automatic reset is built.
- **Cancellation** — no endpoint sets `cancelled_at`; the status exists and is
  honoured everywhere, but nothing can reach it yet.

## Open with the client

**Premium's monthly price.** ₱900/mo is **+8%** over annual, where Standard
(₱3,600 vs ₱2,999) and De Luxe (₱7,200 vs ₱5,999) are both exactly **+20%**. If a
uniform convenience premium was intended, Premium should be ~₱1,000. It is the
plan where under-pricing costs most.

**The public site already advertises monthly** — [`PricingSection.tsx`](../../website/app/components/PricingSection.tsx)
has an annual/monthly toggle whose sub-line reads "₱2,999 billed annually" under
a "₱300/mo" headline. Both cannot be true, and ₱2,999 ÷ 12 is ₱250. That copy
needs fixing when monthly launches.

## Verified state at the time of writing (2026-08-17)

Read-only audit of production: every payment ever taken is at an **annual**
price, no payment matches a monthly price, and **no member has ever paid twice**.
`price_monthly` had existed on `Plan` since seed but reached **no payment path at
all** — monthly was displayed, never sellable.
