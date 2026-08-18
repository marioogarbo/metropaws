# Monthly subscriptions and vesting

**Status:** backend and mobile both built and **merged to `main`**, and
**exercised end to end on a real device** 2026-08-17 — a monthly Deluxe was
bought, charged ₱600, and activated. Production has the **schema** (migrated
2026-08-17) but neither the endpoints nor the app; dev has the backend as of
`metropaws-backend-dev:20260817-103725`, which predates the fixes below.

**Verified 2026-08-19** by diffing prod's live OpenAPI against `main`:
`POST /payments/installment` is the one non-PawPoints route on `main` that
production does not serve. So **the next prod deploy — for any reason — ships
monthly instalments server-side**, onto a schema that already supports them. The
Play APK still lacks the mobile half, so no member reaches it through the app;
check whether the website's pricing toggle offers monthly to web visitors before
assuming nothing is user-visible.
**Decided 2026-08-16** by Mario: monthly is wanted, for members who can't afford
the annual fee or aren't ready to commit.

Governed by Membership Agreement Rev. 5A §5.2–§5.10. Those sections are the spec
— read them at [`/terms-of-service`](../../website/app/terms-of-service/page.tsx)
before changing anything here.

## Nothing here was invented

Every rule traces to a clause of Rev. 5A. Worth stating because the direction
is the opposite of how it tends to get read: the agreement **already promised**
vesting and the system did not do it. This work closed a gap between a
published contract and the code, in the same category as the Emergency Wallet
being unreachable and pre-activation claims being payable.

| Behaviour | Clause |
| --- | --- |
| Monthly instalment subscriptions exist at all | §5.2 |
| First cleared payment buys digital access only | §5.3 |
| Benefits need N *consecutive* cleared payments | §5.4 |
| 6 / 8 / 10 planned, 3 / 3 / 4 emergency | §5.5 |
| Late payment may suspend and reset the qualifying period | §5.6 |
| Member status labels | §5.7 |
| No benefit for a service predating the eligibility date | §5.8 |
| Annual members skip vesting entirely | §5.9 |
| Activation, eligibility, authorisation, settlement are separate | §5.10 |

The one part **no document backs** is the monthly prices themselves
(₱300 / ₱600 / ₱900). They appear in `seed.py`, the database and the website
pricing toggle, but no peso figure for monthly appears in the Agreement, and
the manual catalogue in [`document-system-alignment.md`](./document-system-alignment.md)
records only annual prices. Unverified against the Manual PDF, which cannot be
read in this environment.

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

## The mobile side

Three screens, and the count matters — see the drift note below.

- **Plan selection** and **Add-a-Pet** both sell plans, so both carry the
  `CadenceToggle` (`core/widgets/cadence_toggle.dart`, shared deliberately). The
  toggle only appears when a visible plan actually has a `priceMonthly`.
- **Benefits card**, **Home pet card** and the **Submit form** all render wallet
  balances, so all three had to learn that an unvested pool is not spendable.

The Pack Discount is suppressed on every monthly surface: it is 15% off a YEAR,
so per instalment it would discount the same year twelve times.

Paying an instalment reuses the existing `Checkout*` bloc states, so the
launch-and-poll handling that stops a paid member being stranded covers it
unchanged. `WalletPetOut` carries everything the UI needs —
`membership_status_label` is rendered verbatim so the contract's wording is never
compiled into a release.

## Six bugs a real device found that nothing else did

Recorded because every one was invisible to `flutter analyze` and to a green test
suite, and four of them were about money.

1. **Monthly never appeared at registration.** A plan is bought from TWO screens
   and only `PlanSelectionScreen` had been taught. New members — the majority —
   silently got annual.
2. **`_grant_plan` is not called once per payment.** Its four callers (webhook,
   poll, return page, profile reconcile) each check the payment is still pending,
   but two can observe that at the same instant. On dev a single ₱600 instalment
   ran the body twice twelve seconds apart and left the counter at 2. The
   PawPoints award survived because it is keyed on `payment.id`; nothing else was.
   **The guard now sits at the top of `_grant_plan`, so the whole function is
   idempotent** — which also protects `grant_plan_to_pet` on the annual path,
   where a second run would have reset the wallet year.
3. **The wallet showed money that could not be spent.** The claim gate was right,
   but a full pool in gold is the strongest possible claim that it is available.
   Fixed server-side (`preventive_available` / `emergency_available`) rather than
   by the app inferring it — the app has no thresholds, and duplicating the rule
   is how surfaces drift.
4. **"Current plan" appeared under both cadences.** `purchase_eligibility` reads
   plan tier and term only; cadence is not part of the eligibility model at all.
   `Pet.plan_cadence` supplies the missing half, and the badge now says
   "Current · monthly" / "Current · yearly".
5. **Buying outright left the subscription alive.** A monthly subscriber
   upgrading to a higher plan annually — which §5.5's rules allow mid-term — kept
   an active row, so they stayed gated as unvested after paying a full year up
   front. Granting on a payment with no `subscription_id` now cancels it.
6. **The vesting rule arrived as a red error after submitting a claim.** Correct
   rule, wrong shape: nothing had gone wrong. Now an inline banner plus a disabled
   button, keyed to the CATEGORY rather than the pet, because the two pools open
   at different times and the answer differs on the same screen.

### The drift pattern worth naming

Three separate times now, a rule had to be taught to more than one surface, and
the second was missed until someone looked: the Pack Discount across two plan
screens, monthly across those same two, and pool availability across three wallet
renderers. Before adding a fourth surface that renders a balance or sells a plan,
extract the shared piece instead.

## Not built

- **Reminders** before an instalment falls due, and after it lapses. Optional,
  not blocking — the member can pay from the app unprompted.
- **§5.6 admin restore** — the discretionary "restore to last approved
  good-standing status" half. Only the automatic reset exists.
- **Cancellation** — `cancel_for_pet` exists and is called when a plan is bought
  outright, but no member- or admin-facing endpoint reaches it.
- **Same-tier cadence switching.** Deluxe monthly → Deluxe yearly is blocked
  mid-term, because `purchase_eligibility` sees the same plan id and returns
  `current_plan`. That is a side effect, not a decision. Allowing it needs
  answers on crediting instalments already paid and on the wallet-year reset.

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
