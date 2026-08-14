# Benefit Utilization KPI, and the backend reorganisation reaching production (2026-08-14, evening)

Started from a client question in the MetroPaws group chat: Romy screenshotted the
admin dashboard showing **0% BENEFIT UTILIZATION / 0 of 28 sessions** and asked
why the tile had no value, while the app screenshots in the same thread showed
Luster with ₱650 of ₱2,000 already used.

He was right, and the tile was not stale data — it was measuring something the
product stopped doing.

## The finding

`admin/analytics/overview` computed utilization as

```
SUM(pet_services.used_sessions) / SUM(pet_services.total_sessions)
```

`used_sessions` is incremented in exactly three places: the clinic QR-scan
endpoint (`app/routers/clinic.py`) and the admin deploy/assign-service endpoints
(`app/routers/admin/services.py`, `.../bookings.py`). The admin QR scan/deploy
tool was removed from the website — nothing in `website/` calls `deploy-service`
any more — and members now consume benefit through **reimbursement claims**,
which never touch sessions.

So the denominator was live data and the numerator was dead. The metric could
only ever read 0%.

The real usage was already in the database, in pesos:
`reimbursement_utils.wallet_usage` sums approved + paid claim amounts against the
plan's Preventive Wellness and Emergency pools. That is the number the app's
Benefit Wallet has been showing all along.

## The fix

`benefit_utilization(db)` in `backend/app/routers/admin/analytics.py`:

- **numerator** — `SUM(approved_amount_centavos)` for `approved` + `paid` claims,
  reusing `reimbursement_utils.USED_STATUSES` so it cannot drift from what the
  member's wallet counts.
- **denominator** — `SUM(reimbursement_wallet_centavos + emergency_wallet_centavos)`
  over pets joined to their plan, limited to terms started within
  `plan_term_utils.PLAN_TERM_DAYS`.
- **window** — claims count only from `date(plan_activated_at)` onward, matching
  `wallet_usage`, so a re-grant resets utilization exactly as it resets a
  member's wallet.
- Legacy grants (`plan_id` set, `plan_activated_at` NULL) count in **both** halves.
  `plan_term_utils` treats those as active with no expiry, and excluding them
  would have re-created the same 0% bug for precisely the manually-granted pets.

Response shape changed from `{total_sessions, used_sessions, used_pct}` to
`{used_php, granted_php, used_pct}`. The website is the only consumer, so the
shape was changed rather than extended. The tile keeps its `%` headline; the
sub-label reads `₱650 of ₱13,800` and falls back to "No active plans" when the
denominator is zero, so it never renders a ratio of two zeroes.

11 tests in `backend/tests/test_analytics.py` pin the behaviour that the old
metric had none of: both pools summed, paid counts, pending and rejected do not,
a claim dated before activation excluded, a claim dated *on* the activation day
included, expired term excluded, legacy null-activation counted, and the
zero-denominator case.

## Verified in both environments

| | dev | prod |
|---|---|---|
| Migration | 17 steps, all applied | 17 steps, all applied |
| Image | `metropaws-backend-dev:20260814-195239` | `metropaws-backend:20260814-200520` |
| Render deploy | `dep-d9veb5bl550s738dnl00`, live | `dep-d9vegte7bikc73da63q0`, live |
| Route surface | 95 paths / 117 operations | 95 paths / 117 operations |
| Utilization | 19.7% — ₱7,150 of ₱36,300 | 4.7% — ₱650 of ₱13,800 |

Route surface was compared against `tests/routes_snapshot.json` with zero drift
in either direction, which is what proves the `app/` package restructure imports
correctly inside the image — this was its first deploy anywhere.

The prod figure reconciles exactly with the app: 6 active pets × (₱2,000 + ₱300)
= ₱13,800 granted, and Luster's single paid claim of ₱650 = 4.7%.

**Three different correct percentages exist** for the same claim, which will be
asked about again:

| Number | Scope |
|---|---|
| 33% | Luster's preventive pool only — ₱650 of ₱2,000 (what the app shows) |
| 28.3% | Luster across both pools — ₱650 of ₱2,300 |
| 4.7% | All active pets, both pools — ₱650 of ₱13,800 (the dashboard) |

The app answers "how much of *this pet's* allowance is left"; the dashboard
answers "how much of the benefit we have sold has been drawn down". One member's
claim cannot move a six-pet portfolio, so the club-wide figure will always look
small beside an individual wallet.

## Also released

`refactor/backend-organize` fast-forwarded onto `main` and pushed — 14 commits,
none previously deployed anywhere: the `app/` package move, `domain/`,
`scripts/`, dependency pinning, and roughly 1,100 lines of new tests. All the
`feature/*` branches and `refactor/backend-cleanup` were already ancestors, so
nothing was left behind.

`website/` synced to `metropaws-website:master` (`9a8e436`) as a tree-carrying
fast-forward, no force push, per `deployment-topology.md`.

`SECRET_KEY` went live with this deploy, invalidating every member and admin
token. Admins re-signed in successfully, which closes item 2 of the rotation
list — see [`../features/credential-exposure-2026-08.md`](../features/credential-exposure-2026-08.md).

## Findings worth keeping

### `used_sessions` is now dead data across the product

Nothing a member or admin can do increments it. One consequence hides in
`plan_term_utils.benefits_untouched()`, which gates mid-term plan upgrades on

```python
if any((ps.used_sessions or 0) > 0 for ps in pet.pet_services):
    return False
```

That clause can no longer be true, so the wallet check beside it is doing all the
work. The rule is therefore **looser than its own docstring claims** — "zero
service sessions used" is satisfied by definition. Not a live bug, since the
wallet check is the one that matters for money, but it should not be mistaken for
an enforced condition.

### The migration script is not purely additive

Worth knowing before running it against prod: alongside the
`ADD COLUMN IF NOT EXISTS` steps, `deduplicate_pet_services` and
`deduplicate_plan_services` **delete** rows, and `add_benefit_wallet_pools`
backfills plan values.

On this run both were no-ops, and the reason is structural rather than lucky:
each dedupe step adds a UNIQUE constraint on completion, so once it has run,
duplicates cannot exist for a later run to remove. The backfill reported 0 plans
in both environments.

`member_services` is **not** covered by any dedupe step, so the possible
duplicate `member_services` rows noted in
[`2026-08-14-backend-config-and-cleanup.md`](2026-08-14-backend-config-and-cleanup.md)
are untouched and still open.

### Two operational notes on `deploy.ps1`

- The prod confirmation is compared with `-cne`, so it is **case-sensitive**:
  typing `prod` aborts, only `PROD` proceeds.
- The prod push failed once on `failed to authorize: ... auth.docker.io: EOF` —
  the same Docker Hub flake seen before. A straight retry succeeded. It is worth
  assuming one retry rather than diagnosing it.

### Stale references corrected in `backend/CLAUDE.md`

It pointed at `reimbursement_utils.category_usage(..., lock=True)`, which does
not exist — the function is `wallet_usage`, and nothing anywhere refers to the
old name. It also described the claim ceiling as per-category
`plan_services.reimbursement_cap_centavos`, which the code itself marks legacy
and no longer consults; the real ceiling is the two per-plan pools. Both would
have sent a future reader looking for code that isn't there.

## Left open

1. **Credential rotation**, items 1 and 3–8: the admin account password is still
   the most exploitable, and the never-expiring Docker Hub delete-scope token
   still needs revoking. `SECRET_KEY` is done.
2. **Possible duplicate `member_services` rows in prod** — needs a read-only
   count to settle. Unchanged by this session's migration.
3. **`benefits_untouched`'s session clause** is a permanent no-op (above). Either
   drop it or restate the rule to match what it actually enforces.
4. **Vercel deploys can't be verified from this environment** — no CLI, no token,
   so a website release is confirmed only by the push landing on `master`. A
   global `vercel` install plus a token would close that gap.
