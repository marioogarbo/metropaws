# PawPoints: an empty prod catalogue, and the admin page that would have caught it

**Dates:** 2026-08-18 → 2026-08-19.
**Trigger:** Romy, 2026-08-17: *"in the app, how can we know for both members and
admin reg the accumulation of pawpoints? For example, s admin, mkkita b natin s
dashboard paw points per member? For members nman, will they be prompted if they
reach a certain paw points already, that they can already claim or just click
continue accumulating because once they claim the points will already reset."*

Two questions, and answering the first exposed a live defect neither of us was
looking for.

## The finding: both databases had an empty rewards catalogue

`GET /paw-points/rewards` returned `[]` on **dev and prod**, so every member —
including every live one on the released APK — saw the app's "Rewards coming
soon" empty state. The Rewards tab was never unfinished; it was a finished screen
rendering an empty list.

The catalogue had only ever been inserted by hand-pasting
`migrations/add_paw_points.sql` into the Supabase SQL editor. That file was found
orphaned and absorbed into `seed_paw_points_rewards` on 2026-08-14 — but the
original paste had never reached prod, and **nothing runs a seeder
automatically**: not app startup, not `deploy.ps1`. Verified by direct count
against both databases (dev 0, prod 0), then fixed and confirmed through the live
API: `https://metropaws-backend.onrender.com/paw-points/rewards` → 200, seven
rewards, correct order.

**Why it stayed invisible from every surface at once** — this is the transferable
part:

| Surface | What it showed |
| --- | --- |
| The app | "Rewards coming soon" — indistinguishable from a feature not yet built |
| `seed.py` | Correct. The seeder existed and was right; nothing had run it |
| The admin site | No PawPoints page at all, so nowhere to notice |
| The gap register | Warned the table was "admin-managed and not seeded" — and was read as stale precisely *because* `seed.py` looked correct |

A seeder existing is not the same as its rows existing. The only check that
would have caught this is the one that reads the database or the API, and no test
does — the suite runs on SQLite with tables it creates itself.

**Corrected mid-session:** I first told Mario the register's "not seeded" note
was stale because `seed.py` covered it. Wrong, and wrong in the direction that
mattered — the note was live. Counting the dev rows is what settled it.

## Documents: MMS-DWP-001 Part VI is the real PawPoints spec

Mario asked for the manual and agreement to be verified rather than trusted, and
`pdftotext -layout` **works here** (`/mingw64/bin/pdftotext`, ships with Git
Bash) — the standing note that PDFs were unreadable was wrong. Its replacement
warning is that multi-column tables come out misaligned: the manual's §9 Premium
column extracted two rows out of step and had to be re-associated by hand.
Mario's screenshots later confirmed the reconstruction, but **verify any table
before quoting it**.

That read turned up
`website/MMS-DWP-001_Digital_Wellness_Platform_Framework_Rev1_PawPoints_Rewards.pdf`
— a CEO-owned Controlled Document, 70 sections, **referenced by nothing** in this
repo, whose Part VI (§61–70) is the actual PawPoints system spec. It answers what
Manual §9 does not, and it changes what to ask the client:

- **§66 Redemption** — in the app *or* via CSR; Operations approves, Technology
  deducts and updates the ledger; final once processed. Forms MP-F-017/018.
- **§67 Expiry** — 12 months from issuance, or at membership lapse past the grace
  period. Refunded / cancelled / reversed transactions **must reverse** their
  points. So expiry is **already decided policy, not an open question** — my
  earlier framing of it as a decision for Romy was wrong. It is unimplemented,
  which is different.
- **§69 Dashboards** — both are *required*, with field lists. Romy's question was
  not a feature request; it was an unmet documented requirement.
- **§70** — referral and birthday bonus are Phase 1; events are Phase 2.

It also **conflicts with the manual** on the earning matrix and the catalogue
(11 tiers to 10,000 pts against the manual's 7 to 5,000). The code follows the
manual; the framework says values "may be adjusted by management prior to
launch". Unresolved — Romy has to say which governs. **Do not publish it:** it is
marked Confidential & Proprietary and is deliberately outside `public/`.

Full register in [`features/document-system-alignment.md`](../features/document-system-alignment.md#L293).

## Answering the "reset" question

Romy's premise — that claiming wipes the balance — is wrong, and the documents
agree with the code. `paw_points_transactions` is append-only;
`current_balance` is `SUM(all)` floored at zero and `lifetime_earned` is
`SUM(positive)`. A redemption is a negative row: the balance drops by exactly the
reward's cost and lifetime earned never decreases. §66 says "deducts", §69 wants
balance and redeemed as separate figures, and Appendix H's sample journey has the
member redeem and keep their history. So "claim now vs keep accumulating" is not
the trade-off he pictured — it is a wallet debit.

## Built: `/admin/paw-points`

Backend, every figure a SUM over the ledger computed exactly as the member
endpoint computes it, so an admin cannot quote a number the member's app
disagrees with:

    GET    /admin/paw-points/summary        issued / redeemed / outstanding,
                                            holders, top earners, reward reach
    GET    /admin/paw-points/members        per-member balances, searchable
    GET    /admin/paw-points/members/{id}   one member's full ledger
    GET    /admin/paw-points/rewards        includes retired, unlike the
                                            member endpoint
    POST   /admin/paw-points/rewards
    PATCH  /admin/paw-points/rewards/{id}
    DELETE /admin/paw-points/rewards/{id}

Two places where the honest number is not the one §69 names, both deliberate:

- **No peso liability estimate.** The catalogue stores no cost per reward, so a
  peso figure would be invented. "Members already over each threshold" is derived
  from real balances and drives the same decision.
- **Redeemed reads 0**, because nothing writes a negative row yet. Computed, not
  hardcoded, so it reports the moment redemption exists — and the page states why
  it is zero rather than leaving a bare 0 to be misread as "nobody wants these".

Website page is `/admin/paw-points`, sidebar entry between Reimbursements and
Providers. A manual award **requires a reason**: the ledger is append-only, so
that note is the only record of why a balance moved outside member activity.
Deleting a reward warns you to hide it instead.

Two defects fixed from Mario's screenshots: lucide `Coins` at 15px reads as a
chain link next to the word PAWPOINTS (→ `PawPrint`, which also matches the app's
paw coin; stars stay reserved for bonus/featured), and every icon-only button had
`title` but no `aria-label`, against the project's stated WCAG AA commitment.

## The real cause, and why the page is the fix

**No admin endpoint could write `paw_points_rewards`.** The gap register called
it "admin-managed"; no admin could manage it. §66 assigns the job to a person —
"Marketing maintains reward catalog" — and Marketing had no way to. The
catalogue could only ever be changed by a developer running a seeder or pasting
SQL, which is exactly how it was lost. That, not the missing rows, is what this
page closes.

## Verified

- dev and prod reward counts before (0 / 0) and after (7 / 7), and the live prod
  API serving all seven with the reward types the app's `_rewardIcon` handles.
- Backend suite **526 passing, exit 0**, 16 new. They pin the arithmetic that
  fails quietly: a redemption debits balance but not lifetime earned, a balance
  never reads negative after an over-correction, a member who earned nothing
  still appears at zero, and top earners rank by lifetime so redeeming cannot
  cost a place.
- The new aggregate SQL run against **real Postgres**, not only the suite's
  SQLite — reach counts confirmed by hand (1,800 clears five tiers, 600 clears
  two).
- Website `tsc --noEmit` clean, lint clean, production build compiled, route in
  `routes-manifest.json`.
- Prod's live OpenAPI compared against `main`: **117 routes deployed vs 125 on
  main.** The 8 undeployed are the 7 above plus `POST /payments/installment`.

## Left open

1. **The prod backend is not deployed** — the admin page renders empty states
   against prod until it is. Code-only; no migration (prod took the monthly
   schema on 2026-08-17, and `paw_points_*` has existed all along). Confirm
   `.env.prod` holds no placeholders first: `deploy.ps1 -Env prod`
   full-replaces Render's env vars from it.
2. **Deploying also ships `POST /payments/installment`** — monthly instalments
   go live server-side. Prod has the schema; the Play APK does not have the
   mobile side (still needs an AAB), so no member reaches it through the app.
   Check whether the website's pricing toggle already offers monthly to web
   visitors — if it does, that path is broken today and this deploy fixes it.
3. **No Redeem action anywhere** (§66). Members now see seven rewards with
   progress bars, "You have enough points!", and nowhere to tap. This is the
   next build: request in-app → Operations approves → deduct.
4. **No expiry, no reversal** (§67). Nothing expires; a refunded membership
   payment keeps its activation points forever. The ledger supports negative
   rows — nothing writes one.
5. **Members are never prompted** on crossing a tier — Romy's second question.
   The `Notification` model exists and reimbursements already use it, so this is
   small.
6. **Four earning activities still unbuilt** — wellness reminder, referral, event
   attendance, birthday bonus. Referral and birthday are Phase 1 per §70 and
   self-contained.
7. **Two confirmations needed from Romy** — that the manual governs over
   MMS-DWP-001 where they disagree, and that §67's 12-month expiry stands.
8. **`Metro Admin` appears in the members list at 0 points** — the admin
   account's own `Member` row. Left visible deliberately: the Users page includes
   it too, and silently dropping rows from a report is worse than one you ignore.
   Filter by role if unwanted.
