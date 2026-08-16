# The two money items from the alignment register (2026-08-15)

Picked up register items 12 and 11 — the only open items that could move money
incorrectly. Both are fixed and tested; neither is deployed.

## The production check that item 12 was waiting on

Item 12 had been blocked since 2026-08-14 on one unanswered question: does
production have a service category named exactly `Emergency`? A read-only audit
(SELECT only, no writes) against both databases answered it and three other open
questions at the same time.

**Production has the same six categories as dev, and no `Emergency` among them:**

```
'Emergency Stabilization'  'Full Grooming'  'General Consultation'
'Grooming'                 'Semi-Annual Exam'  'Vaccines'
```

So the Emergency Wallet was unreachable in production too, exactly as feared.

**But nothing had been mispaid.** No emergency claim has ever been filed in
either environment. Production's entire claim history is a single paid `Vaccines`
claim for ₱650 — the same one behind the 4.7% dashboard figure. Dev has four
claims, none emergency.

That changes the character of the finding. It was a live defect that had not yet
cost anything, and the fix re-buckets no existing row. Had a single emergency
claim been approved first, the fix would have retroactively moved it between
pools and changed a member's visible balance.

Two other open items closed off the same query:

- **No pre-activation claims exist** in either environment, so item 11 needed a
  gate but no data cleanup.
- **Zero duplicate `member_services` rows in production** — settles the item
  carried since the `grant_plan_to_member` bug in `4261c20`. The fix stopped new
  ones and there were no old ones.

## Item 12 — the fix, and why the quick one

`EMERGENCY_CATEGORY_NAMES` is now `{"emergency", "emergency stabilization"}`.

The register offered a quick fix (widen the set) and a proper one
(`ServiceType.is_emergency`, admin-editable). Because no money had moved, there
was an argument for going straight to the flag. Took the quick fix anyway: the
flag needs a migration, an admin UI and a backfill, and holding a live
misrouting open across that work to avoid a one-line change is the wrong trade.
The two-name set also matches the shape `_GROOMING_CATEGORY_NAMES` already uses,
so it reads as the existing pattern rather than a patch.

The flag is still the right end state and is now the only remaining half of item
12 — the match is by name, so renaming the category in the admin UI re-breaks it.

`test_emergency_stabilization_does_not_match_the_emergency_pool` was **inverted,
not deleted** — it existed to force exactly this deliberate decision. Two tests
were added beside it: direct-pay eligibility, and a `wallet_usage` assertion that
a stabilization claim lands in the emergency totals, so the money path is covered
rather than just the predicate.

### Tell the client before this deploys

Emergency claims will now be capped at ₱300 / ₱900 / ₱1,500 instead of drawing on
the ₱2,000 / ₱4,000 / ₱7,000 preventive pool. That is the two-pool model working
as designed and as the documents describe it — but to a member it is a
tightening, and the first emergency claimant will meet a much smaller allowance
than the app would have granted the week before.

## Item 11 — the pre-activation gate

`_reject_before_plan_start` rejects `service_date < plan_activated_at` with a 400
naming the pet and its start date.

Three decisions inside it:

- **It runs on resubmit as well as submit.** Resubmit accepts a new
  `service_date`, so a submit-only gate was bypassable in two steps — file an
  in-term claim, then move the date once the admin asks for more information.
  Resubmit now fetches the pet once and shares it with the existing wallet
  re-check, which was re-querying it separately.
- **The boundary is inclusive.** A claim dated *on* the activation day is
  allowed, matching `wallet_usage`'s `service_date >= plan_activated_at`. An
  off-by-one here would silently reject every same-day claim, so it is pinned by
  its own test.
- **Legacy grants are exempt.** `plan_activated_at IS NULL` means no term start
  to measure against, and `plan_term_utils` already treats those pets as active
  without expiry. Gating them would reject every claim from the manually-granted
  pets.

§5.1's "written exception" still has nowhere to live: only a member can create a
claim, so staff cannot record an approved exception. That is the same missing
admin-create endpoint as item 1's retro-recording trap, and the two should be
built together or not at all.

## State

353 tests pass, up from 345 — 8 new across
`tests/test_reimbursement_dates.py` (new file) and
`tests/test_reimbursement_utils.py`.

Committed to `fix/emergency-pool-and-preactivation-claims` as three commits (the
two fixes separately, then this record). Unmerged and unpushed.

### Released to dev

| Step | Result |
| --- | --- |
| Image | `metropaws-backend-dev:20260816-220514`, digest `sha256:bc04307b…` |
| Render deploy | `dep-da0qf4nlk1mc738i4980` → **live** |
| Health | `{"status": "ok"}` |
| Route surface | 95 paths / 117 operations, **zero drift** vs `tests/routes_snapshot.json` |

Neither change needs a migration, a new endpoint or an AAB, so dev → prod is a
plain `deploy.ps1 -Env prod`.

Verified the running image actually carries the fixes rather than trusting the
deploy: `docker run` on the pushed tag found both the widened category set and
`_reject_before_plan_start` at all three sites. The same run confirmed **no
`.env*` files in the image**, so the `.dockerignore` fix from
[`../features/credential-exposure-2026-08.md`](../features/credential-exposure-2026-08.md)
is still holding.

**Not in production.** Hold until the client has been told about the emergency
cap above — the fix is correct either way, but the first emergency claimant meets
a smaller allowance and that should not be a surprise.

## Left open

Unchanged from [`2026-08-14-benefit-utilization-kpi.md`](2026-08-14-benefit-utilization-kpi.md)
except where noted:

1. **Credential rotation** — items 1 and 3–8 in
   [`../features/credential-exposure-2026-08.md`](../features/credential-exposure-2026-08.md).
   The admin account password and the never-expiring Docker Hub delete-scope
   token are the two worth doing first. Now the largest open risk on the project.
2. ~~Duplicate `member_services` rows~~ — **closed**, zero in production.
3. `benefits_untouched`'s `used_sessions` clause is still a permanent no-op.
4. **Resubmit validates a provider-target claim's date as if it were
   member-target** — `_validate_service_date(service_date)` defaults to
   `allow_future=False`, so resubmitting a direct-pay pre-authorization with its
   future appointment date is rejected as "can't be in the future". Noticed while
   adding the gate; left alone deliberately, since it changes behaviour on a path
   with no end-to-end test. Small, and real.
