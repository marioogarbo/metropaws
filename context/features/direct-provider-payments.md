# Direct-to-provider payments

**Status:** live in production since 2026-08-14. Global switch **on**.
**Owns:** [`backend/app/domain/reimbursement_utils.py`](../../backend/app/domain/reimbursement_utils.py),
[`backend/app/routers/reimbursements.py`](../../backend/app/routers/reimbursements.py),
[`backend/app/routers/settings.py`](../../backend/app/routers/settings.py),
[`backend/app/models.py`](../../backend/app/models.py) (`Member.direct_pay_*`,
`Reimbursement.payout_target`, `ReimbursementProvider`),
[`website/components/admin/member-direct-pay-control.tsx`](../../website/components/admin/member-direct-pay-control.tsx),
[`mobile/lib/features/member/screens/reimbursement_screen.dart`](../../mobile/lib/features/member/screens/reimbursement_screen.dart)

## What it is

The normal claim is pay-then-reimburse: the member pays a provider, uploads a
receipt, an admin approves, MetroPaws sends money to the member. Direct-to-
provider inverts that — the member asks **before** the visit, an admin approves
an amount, and MetroPaws pays the clinic directly.

Mechanically it is the same `Reimbursement` row with
`payout_target = provider`. There is no separate table, and no entity named
"Service Authorization" even though that is what Membership Agreement §6 calls
this shape. See
[`document-system-alignment.md`](./document-system-alignment.md) item 1 for how
far it does and doesn't match the published agreement.

## Two switches, resolved server-side

| Layer | Where | Default |
| --- | --- | --- |
| Global | `AppSetting` key `direct_provider_payment_enabled`, admin toggle at `/admin/settings` | `false` |
| Per member | `Member.direct_pay_enabled` — **tri-state**, admin control on the member page | `NULL` |

`NULL` means "follow the global switch", which is every member until an admin
says otherwise. `true` allows a member even while the global switch is off (use
it to pilot). `false` restricts them while it stays on for everyone else.

One resolver decides, and both the enforcement point and the API response call
it:

```python
reimbursement_utils.is_direct_pay_available(member, global_enabled) -> bool
```

It takes the resolved global as an argument rather than reading the setting
itself — the value lives in `routers.settings`, and a utils module importing a
router would invert the dependency.

**Why the override exists:** the global switch was all-or-nothing, so one member
misusing the flow meant turning the feature off for everybody. Agreement §5.7
already names the right lever — the "Authorization Restricted" member status —
and §17 supplies the grounds, which is why `direct_pay_note`,
`direct_pay_updated_by_admin_id` and `direct_pay_updated_at` are stored
alongside the flag. This is a contractual restriction, not a preference.

## Why the app can't read this from `/settings/mobile-config`

`GET /settings/mobile-config` is **unauthenticated** — it has no member to
resolve against and can only ever carry the global switch. The member-scoped
value rides on `GET /wallet` instead (`WalletOut.direct_pay_available`), which
the claims screen already loads.

On the app side `Wallet.directPayAvailable` is **nullable on purpose**. A null —
meaning a backend that predates this — falls back to the global flag rather than
to `false`, so an app shipped ahead of the API doesn't hide the option from
everyone. `reimbursement_screen.dart` keeps the global flag in
`_globalDirectPayEnabled` and recomputes the effective value in
`_applyDirectPayAvailability()`, which also reverts an in-progress provider
selection when the option disappears mid-session.

Enforcement is server-side in `POST /reimbursements`, so a stale client gains
nothing. The rejection message is deliberately neutral — whether a member is
restricted is between MetroPaws and support, not an app error string.

## The admin control has its own endpoint

`PUT /admin/members/{member_id}/direct-pay`, not the existing
`PUT /admin/members/{member_id}`. The latter applies
`payload.model_dump(exclude_none=True)`, which cannot express "set this back to
NULL" — and NULL is a real choice here, not an absence.

## Operating it — the sequence is mandatory

1. Admin adds the clinic at `/admin/providers` (a `ReimbursementProvider`, with
   payout details). Nothing is selectable until one exists and is active.
2. Global switch on, and the member not restricted.
3. **Member files in the app**, with a future appointment date.
4. **Admin approves with an amount — this is the moment the benefit is
   deducted** (`USED_STATUSES = (approved, paid)`).
5. MetroPaws pays the provider offline.
6. Admin marks paid with a reference. No second deduction.

**If MetroPaws pays before the member files, the benefit cannot be deducted at
all.** A provider-target request rejects a past appointment date
(`_validate_service_date`, window today → +60 days via
`PROVIDER_MAX_FUTURE_DAYS`), and `POST /reimbursements` requires
`require_member`, so no admin can create one on a member's behalf. The only
remaining route would be a member-payout claim, which pays the member for money
MetroPaws already spent. Open decision on relaxing this is recorded in the
alignment register.

## Gotchas

- **`Member` has two foreign keys to `users`** now (`user_id` and
  `direct_pay_updated_by_admin_id`). Both `Member.user` and `User.member` name
  their `foreign_keys` explicitly; without that SQLAlchemy fails at *mapper
  configuration*, i.e. on import, taking the whole API down rather than just
  this feature.
- **Emergency is excluded by design** (`is_direct_pay_eligible_category`) — but
  that exclusion does not currently fire, because no service category matches
  the name the code looks for. See alignment register item 12. Member-facing
  copy deliberately avoids asserting the rule until it's true.
- **The member still uploads a file** even for a future appointment. A quote,
  estimate or booking confirmation is what the form asks for.

## Verified 2026-08-14

Against dev with a local backend, then against production after deploy:

- Restricting a member hides the option after a pull-to-refresh, and an
  in-progress provider selection reverts to "Reimburse me".
- A restricted member submitting from a stale client gets
  "Direct-to-provider payments aren't available right now."
- Resolver truth table: inherit/on → allowed, inherit/off → blocked,
  restricted/on → blocked, forced-on/off → allowed.
- A filed request appears in `/admin/reimbursements` with a
  **PAY PROVIDER DIRECTLY** badge.
- Production `openapi.json` carries `/admin/members/{member_id}/direct-pay`,
  `WalletOut.direct_pay_available` and the three `MemberSummary` fields; all
  four `direct_pay_*` columns exist on the prod `members` table.
