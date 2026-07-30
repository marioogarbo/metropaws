# Provider nomination — proposal, not yet built

**Status:** proposed 2026-07-30, no code written. Decision pending with the client.
**Depends on:** the existing direct-to-provider payout path (`payout_target=provider`)

## The problem

Direct-to-provider payouts are fully built and **currently unreachable**:

- `direct_provider_payment_enabled` defaults **OFF** (`app_settings`)
- Providers can only be created by admin — `POST /admin/reimbursement-providers`
  is behind `require_admin`
- `GET /members/reimbursement-providers` filters `is_active == True`, so members
  only ever see admin-verified rows
- Prod currently returns `[]` for that endpoint — zero providers exist
- With an empty list, `mobile/lib/features/member/screens/reimbursement_screen.dart`
  (the `providers.isEmpty` branch) tells the member to go away: *"No verified
  providers are available yet. Choose 'Reimburse me' above instead."*

So the entire pipeline can never activate. Seeding it requires admin to cold-call
clinics, and the client's position is that clinics don't want to partner
("ayaw nila makipag-partnership").

The business motivation for direct-pay is real: reimbursing the member means the
member fronts the cash, which feels like a loan. Paying the provider directly
removes that.

## The proposal

Let members **nominate** their existing groomer/clinic ("suki"). Admin verifies
and activates. Members introduce the relationship; MetroPaws closes it.

## The critical constraint: members must never supply payout details

| Member submits | Admin supplies after verifying |
| --- | --- |
| Business name, address, phone | `payout_method` |
| Contact person | `payout_account_name` |
| Category (grooming / clinic) | `payout_account_number` |
| Optional photo of signage or an old receipt | `payout_bank_name` |
| Free-text note ("my suki since 2023") | `is_active = true` |

**Why this split is non-negotiable.** A provider-target claim requires only a
*quote/estimate/booking confirmation* — not a paid receipt — and
`_validate_service_date(allow_future=True)` allows an appointment up to
`REIMBURSEMENT_PROVIDER_MAX_FUTURE_DAYS` (60) ahead. Nothing has happened yet.

If the member also supplied the bank details, the flow becomes: nominate a
business with your own GCash number → upload a fabricated quote → MetroPaws
transfers money to you → no service ever occurred.

Reimburse-to-member is safe because two controls hold it up: **proof of payment**
(money already spent) and **a known payee** (the verified member). Member-supplied
payout details remove both at once. This is why `models.ReimbursementProvider`'s
docstring says "**verified** to receive a reimbursement payout directly" — that
word carries the whole control.

## Why this also solves the partnership problem

Cold outreach fails because it asks a clinic for a favour with nothing attached.
Nomination inverts it: *"Your regular customer Maria is a MetroPaws member. She's
asked us to pay you directly for her dog's grooming next Tuesday — ₱1,500. Can we
get your GCash details?"*

A warm intro with revenue attached, from someone the clinic already trusts. **The
nomination queue is a partner-acquisition funnel**, which is a stronger argument
for building it than member convenience.

## Where it goes: mobile, not the website

The website has **no member surface**. `website/app/member/page.tsx`
`router.replace()`s away on mount and its own copy says member access is
app-only. Putting member intake there means building member auth on the website
that doesn't exist.

The trigger already exists in the app: the member picks "Pay the provider
directly", doesn't find their suki, and hits the `providers.isEmpty` branch.
That's where the *"Can't find your groomer? Suggest them →"* CTA belongs.

**Admin review goes on the website**, as a Pending section on the existing
`/admin/providers` page.

## Rough scope

- **Backend** — migration adding `status` (or reusing `is_active`) plus
  `submitted_by_member_id` and a note field; `POST /members/reimbursement-providers/suggest`
  (member auth, identity fields only, rate-limited per member); admin
  list-pending / approve-with-payout-details / reject. The existing
  `is_active == True` filter already keeps pending rows out of member pickers.
- **Mobile** — nomination form behind the empty-state CTA; optionally a
  notification on approval (the notifications infra already exists).
- **Website** — Pending queue on `/admin/providers`.

Call it two days across the three codebases, most of it the admin queue UI.

## Four workflow gaps to decide regardless of this feature

These already exist in the shipped direct-pay design and bite on the first real
claim:

1. **Quote vs. final bill.** Pre-auth claims are filed with an estimate;
   `approved_amount_centavos` is fixed at approval. Nothing resolves a ₱2,200
   actual against a ₱1,800 approval. Suggested rule: MetroPaws caps at the
   approved amount, member pays the excess at the counter, stated upfront. This
   is a member-trust problem, not a code problem.
2. **No cancel path for a pre-auth.** A pending provider claim reserves wallet
   (`remaining = wallet - used - pending`). A member no-show locks that money
   until an admin notices. Resubmit and reject exist; member-initiated cancel
   does not.
3. **Payout is 100% manual.** Per the original design note, an admin wires the
   provider by hand, and PayMongo disbursements are still blocked pending wallet
   activation. Fine at 10 members, a job at 200. Don't launch widely.
4. **Duplicate nominations.** Fifty members nominating "Vetfusion" creates fifty
   pending rows. The admin queue needs dedupe or a name-similarity warning.

## Recommendation

Build it, but keep `direct_provider_payment_enabled` **OFF** until at least three
providers are actually verified, and settle the quote-vs-final-bill rule before
shipping. Do **not** build the variant where members supply payout details.
