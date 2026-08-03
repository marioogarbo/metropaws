# 2026-08-03 — App-launch announcement email, and freezing the member documents

Two pieces of work: a broadcast tool to tell existing members and Founding 50
reservations that the Android app is live, and — after the client reviewed that
email — taking the Membership Agreement and Member Manual offline for rewriting.

## 1. Launch announcement email

Built [`backend/notify_app_launch.py`](../../backend/notify_app_launch.py) plus
the template in [`backend/email_utils.py`](../../backend/email_utils.py)
(`build_app_launch_email` / `send_app_launch_email`).

**Recipients come from the admin XLSX exports, not the database.** A run needs
mail credentials only, so it never touches production Postgres. Refreshing the
list means re-exporting the spreadsheets. Those exports hold names, emails and
phones, so they are gitignored — this repo is public.

**Three audience variants,** because the two exports describe three different
relationships:

| Variant | Source | Count on 2026-08-03 |
| --- | --- | --- |
| `founding_member` | members export, Founding Member = Yes | 11 |
| `member` | registered, not founding | 8 |
| `founding_reservation` | in the reservations export only, never registered | 11 |

A registered member's variant comes from the members export's Founding Member
column **alone**. That column is the approved-reservation flag, so someone whose
reservation is still `pending` gets the plain member copy rather than being
addressed as a Founding Member.

### Duplicates — what the data actually contained

38 raw rows → **30 recipients.** Audited every flavour:

- **7 addresses appear in both exports** (a member who also reserved early).
  Collapsed, members winning so the copy is right.
- **1 undeliverable row** — `testuser@example.com`. Reserved domains (RFC
  2606/6761) are dropped automatically; bounces cost sender reputation for the
  whole batch.
- **0 Gmail alias collisions** in this data, but dedupe runs on a canonical
  mailbox key that folds Gmail dots and `+tags` anyway, since exact-string
  matching would have emailed one inbox twice. The ledger and the send loop use
  the same key.
- **5 people hold two different addresses**, matched by identical phone number.
  These are genuinely separate inboxes, so both get emailed. **Deliberately not
  auto-collapsed:** phone matching is a hint, not a fact — one pair has two
  different names and could be a household sharing a mobile, and silently
  dropping a real Founding 50 reservation is worse than one extra email. The dry
  run prints the pairs with ready-to-paste `--exclude` flags.

### Safety design

Dry run is the default; `--send` also demands typed confirmation. `--test` and
`--preview` never touch the roster. Delivered inboxes are appended to a ledger
so a re-run after a failure resumes rather than double-sending; a failed address
is **not** recorded, so it gets retried. One bad address never aborts the batch.

### State at end of session

**Nothing has been broadcast.** The ledger does not exist yet. Test copies of
all three variants were sent to `mro.garbo@gmail.com` and
`metropaws.wellclub@gmail.com` only — `--test` bypasses the ledger, so both
addresses are still on the roster and would receive the real email.

Client approved the copy: *"the notification message is already fine with me."*

### Bug found and fixed while testing

The send-loop duplicate guard never recorded what it had sent, so it did
nothing — three aliases of one address all went out. Caught only because the
dedupe was tested against synthetic exports containing every duplicate trick at
once, rather than against the real data (which has no alias collisions and would
have passed). Fixed; re-verified 2 sends from 4 recipients.

## 2. Member documents frozen

Same conversation, straight after the email approval: the agreement is being
rewritten because it no longer matches the business model, so both it and the
manual come down in the meantime.

Full detail, and the restore checklist, in
[`../features/member-documents.md`](../features/member-documents.md).

The finding that shaped the implementation: **the app live on Play links to
`/terms-of-service` and `/docs/member-manual.pdf` from three places, including
the sign-up consent checkbox.** Those links are baked into installed apps, so
deleting the routes would have put 404s in a live consent flow. Both URLs now
serve an "under revision" notice instead, the Flutter app was left untouched
(no new AAB, no Play review), and the whole freeze is two booleans in
[`website/lib/legal-documents.ts`](../../website/lib/legal-documents.ts).

Sign-up now asks for the Privacy Policy alone and records
`agreement_version = "2026-08-privacy-only"`, so members who join during the
freeze stay distinguishable when re-consent is decided.

## 3. Shipped

| Repo | Ref |
| --- | --- |
| `marioogarbo/metropaws` (monorepo, public) | `main` `dcf2a28..3d86288` |
| `marioogarbo/metropaws-website` (Vercel production source) | `master` `ff65328..b90dc70` |

The website repo was fast-forwarded with a single commit carrying
`main:website`'s tree, the established mirror pattern. Before pushing, its
`master` tree was confirmed byte-identical to the last synced tree
(`9e785fe…`), so this was a true fast-forward — `ff65328` is still an ancestor
and the 35-commit history is intact.

A docstring example using the owner's own Gmail was swapped for a neutral one
and the commit amended before anything reached the public repo.

## Still open

- **The broadcast has not been sent.** 30 recipients; decide the 5 same-person
  `--exclude` flags first, and whether staff rows (`admin@metropaws.ph`,
  `carsliquor@yahoo.com` whose first name is literally "Test",
  `metropaws.wellclub@gmail.com`) should be on the list.
- **Waiting on Romy** for the revised agreement and manual — see the restore
  checklist.
- **Backend not redeployed.** `email_utils.py` changed, so the password-reset
  template now builds on a shared `_branded_shell()`. Verified render-identical,
  so nothing is broken meanwhile, but Render won't have the new module until
  `deploy.ps1` runs. The broadcast script runs locally and does not need it.
- The pre-existing three-way `agreement_version` drift documented in the feature
  file.
