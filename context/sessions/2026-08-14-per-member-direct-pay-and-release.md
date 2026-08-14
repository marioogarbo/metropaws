# 2026-08-14 — Per-member direct pay, a claims guide, and the 1.4.1 release

Began 2026-08-13 with the client's revised documents and ran through to a
production release across all three projects the next morning.

## 1. The member documents came back (2026-08-13)

Romy supplied Membership Agreement **Rev. 5A** and Member Manual **Rev. 3C**,
ending the freeze that started 2026-08-03. Both are published. Full detail in
[`features/member-documents.md`](../features/member-documents.md); two findings
worth surfacing here:

- **The manual slot held the wrong file.** `public/docs/member-manual.pdf` was
  238,337 bytes — byte-for-byte the *Agreement* Rev5A PDF. Anyone opening the
  Member Manual from the app got the agreement instead. Now the real manual.
- **The site is deliberately one edit ahead of the controlled PDF.** Rev. 5A
  §5.5 as supplied reads "After two (6) / three (8) / four (10) consecutive
  monthly payments" — numerals raised from 2/3/4, words left behind. Mario chose
  to publish six/eight/ten rather than put a self-contradicting clause on a
  public contract of adhesion. Romy still owes a reissued MP-CON-001.

Publishing the agreement prompted a wider question — does the system actually do
what these documents promise? It largely doesn't. That register is
[`features/document-system-alignment.md`](../features/document-system-alignment.md),
now 12 items.

## 2. Per-member direct-pay override

Romy asked how the app deducts the benefit when MetroPaws has already paid the
provider. Answering it required reading the code rather than assuming, and the
answer corrected an entry written the day before: **direct-to-provider was not
missing, it was switched off.** `Reimbursement` with `payout_target = provider`
is a pre-authorization request in all but name.

Mario then raised the real problem: the switch was global, so one member abusing
the flow meant turning it off for everyone. Built a tri-state per-member
override — follow global / always on / restricted — with the reason recorded.
Design, constraints and the mandatory operating sequence live in
[`features/direct-provider-payments.md`](../features/direct-provider-payments.md).

Three things that shaped the implementation:

- `/settings/mobile-config` is unauthenticated, so it can never carry a
  member-scoped value. The resolved flag rides on `GET /wallet` instead.
- Adding a second FK from `members` to `users` made `Member.user` / `User.member`
  ambiguous. SQLAlchemy fails at mapper configuration — on import — so the whole
  API would have gone down, not just this feature. Both relationships now name
  their `foreign_keys`.
- The admin control needed its own endpoint because the existing member update
  applies `exclude_none=True`, and NULL is a real choice here.

## 3. In-app instructions for claims

Romy: *"do we have a clear instruction dun sa app for the members to follow?"*
There were none. Added a "How claims work" sheet reachable from the app bar and
the My Claims empty state.

It leads with **which situation you're in** rather than which button to press,
because the two paths fail in opposite directions: file "Reimburse me" after
MetroPaws agreed to pay the clinic and the member waits on money that isn't
coming; try "Pay the provider directly" after the visit and it can't be filed at
all. The direct-pay half is hidden when that member can't use it, and the copy
deliberately avoids asserting the emergency-category rule — see finding 2 below.

An inline prompt above the first form field was built and then removed at
Mario's request. Removing it also fixed the header: the title, brand icon, back
arrow and new help action together overflowed a 360dp bar, so `FittedBox` had
been shrinking "Reimbursements" below display size. Dropping the icon returned
the ~34dp needed.

## Findings

### 1. A claim dated before activation is neither blocked nor deducted

Chasing the bounds on a backdated emergency claim (the answer: yes, members can
file days later — there is no filing deadline). The submit path never compares
`service_date` to `pet.plan_activated_at`, and `wallet_usage` *excludes*
pre-activation claims from the used/pending totals. So such a claim is accepted,
can never fail the balance check whatever the amount, and doesn't consume the
wallet even once approved. Agreement §5.1 forbids exactly this. Register item 11.

### 2. No service category is recognised as Emergency

Found while testing on dev: the claim form offered "Pay the provider directly"
with **Emergency Stabilization** selected, showing the *Preventive Wellness*
balance beside it. `EMERGENCY_CATEGORY_NAMES = {"emergency"}` is an exact match,
and none of the six real categories equals it. So the Emergency Wallet
(₱300 / ₱900 / ₱1,500) is unreachable, emergency claims draw from the far larger
preventive pool, and emergency is direct-pay eligible because that rule is
defined as "not emergency".

**Production not checked** — that DB is off-limits without an explicit ask.
Register item 12, and the first thing to verify. Grooming's equivalent set lists
both its real categories and is fine.

### 3. A skipped vaccination card can never be added

Romy asked how pet records get uploaded. The card can only be attached during
pet registration; skip it and there is no route back — not the pet profile, not
the clinic, not an admin. Every layer below the UI works, and
`ApiService.uploadVaxCard` exists with zero callers. The empty state makes it
worse by telling members to "contact your clinic", which cannot upload either.
Deferred deliberately. Register item 7.

### 4. `.env` was a hybrid

At the start of the session `backend/.env` had the **dev** database but **prod**
credentials for Supabase storage, SMTP, ZeptoMail and PayMongo. Local testing
therefore wrote a test receipt into the production storage bucket. `.env.dev`
covers everything except `ZEPTOMAIL_TOKEN` and `EMAIL_FROM` and is the file to
use locally. By end of session `.env` pointed at **prod** — worth checking before
any local run, since `migrate.py` and `uvicorn` both read it.

Also: `uvicorn.exe` is blocked by Windows Application Control on this machine.
`python -m uvicorn ...` works.

## Release

| Step | Result |
| --- | --- |
| `migrate.py` on prod | 4 `direct_pay_*` columns added, 23 members |
| `deploy.ps1 -Env prod` | image `20260814-093000`, deploy `dep-d9v574p5efls73f4tifg` |
| Prod `openapi.json` | new endpoint + schema fields verified live |
| `metropaws-website` `master` | `de7ce79..612fcc6`, tree matches `main:website` |
| Play submission 5 | **Published** 2026-08-14 09:57, version 9 (1.4.1) |

`deploy.ps1` does **not** run migrations — the migration has to be run first, or
every query touching `members` 500s.

The AAB was verified before upload rather than trusted: signed with
`META-INF/UPLOAD.RSA`, `metropaws-backend.onrender.com` compiled in, and
**neither** the dev URL nor `localhost:8000` present. That last check exists
because a build that fell back to localhost is what caused a previous Play
rejection for "login credentials are incorrect".

## Left open

1. **Register item 12** — check prod's service categories. It moves money.
2. **Global direct-pay is on for everyone** in production. Confirm that's
   intended now the feature is live.
3. **Romy owes a reissued MP-CON-001** with §5.5 spelled out as six/eight/ten,
   or confirmation that the words were right and the site is wrong.
4. **`backend/.env` points at prod.** Swap to `.env.dev` before local work.
5. **A test receipt sits in the production Supabase bucket** from local testing.
6. Backend/app agreement version strings still say `2026-07.2` while the website
   records `2026-08-rev5a`. Nothing validates the string; aligning them needs a
   backend deploy and a new AAB.
