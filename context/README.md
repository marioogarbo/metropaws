# context/

Durable engineering context for coding agents and new developers — the
decisions, constraints, and verified facts that the code itself doesn't
record.

Each project already has its own `CLAUDE.md` covering architecture,
conventions, and guardrails. **Read those first.** This folder holds what
sits above them: cross-project decisions, external-platform state (Google
Play, PayMongo, Render), and the reasoning behind choices that look
arbitrary in a diff.

## Layout

```
context/
├── features/    One file per feature or subsystem. Long-lived — update in
│                place as the feature evolves. Answers "how does this work
│                and why is it built this way?"
└── sessions/    One file per working session. Append-only history. Answers
                 "what changed on this date, what was verified, what was
                 left open?"
```

## When to write here

Add to `features/` when a decision will still matter in six months —
especially anything that depends on state outside the repo (a Play Console
setting, a signing key, a provider's account status). That state is
invisible to anyone reading the code, so it has to be written down.

Add to `sessions/` at the end of a working session that produced findings
worth keeping: something verified empirically, a wrong assumption
corrected, or a decision made with the client.

Do **not** duplicate what the code, `CLAUDE.md`, or git history already
says. If a fact is derivable by reading a file, link to that file instead.

## Conventions

- Absolute dates, never "last week" — these files outlive their context.
- Link to real paths (`website/lib/app-download.ts`) so claims stay checkable.
- State what was **verified** versus what is **assumed**. Mark assumptions.
- Never put secrets here. Public certificate fingerprints are fine;
  passwords, tokens, and keystores are not.

## Index

### Features
- [`features/android-distribution.md`](features/android-distribution.md) —
  the two Android install routes and why they are mutually incompatible. **The
  direct APK was retired 2026-08-03**, so the site now offers Play alone — but
  the constraint inverted rather than ended: Play is now ahead of the last APK,
  and a member still holding one cannot take any Play update, with nothing
  telling them so.
- [`features/provider-nomination.md`](features/provider-nomination.md) —
  **proposed, not built.** Letting members nominate their own groomer/clinic so
  direct-to-provider payouts become reachable, and why members must never
  supply the payout details.
- [`features/member-documents.md`](features/member-documents.md) —
  the Membership Agreement and Member Manual: the 2026-08-03 freeze and its
  2026-08-13 restore with Agreement Rev. 5A and Manual Rev. 3C, why their URLs
  must keep resolving whatever their state, what sign-up recorded during the
  freeze, and why the published site is deliberately one edit ahead of the
  controlled PDF.
- [`features/document-system-alignment.md`](features/document-system-alignment.md) —
  **open register, nothing scheduled.** Where the published agreement and manual
  promise behaviour the system doesn't implement, each with the cheaper fix —
  build it, or amend the document. Includes two live money bugs.
- [`features/direct-provider-payments.md`](features/direct-provider-payments.md) —
  paying a provider directly instead of reimbursing the member: the global
  switch, the per-member tri-state override and why it exists, why the app can't
  read it from `/settings/mobile-config`, and the sequence that must be followed
  or the benefit can't be deducted at all.
- [`features/pet-care-directory.md`](features/pet-care-directory.md) —
  the public Las Piñas pet-care directory and its admin CRUD: why it gets its own
  table instead of reusing `reimbursement_providers`, why "Providers" was the
  wrong name for the admin page, and why this page ships without a hardcoded
  fallback list.
- [`features/credential-exposure-2026-08.md`](features/credential-exposure-2026-08.md) —
  **open, and the highest-priority item in the repo.** Production credentials
  were publicly pullable inside Docker images for four months: what was exposed,
  how it happened, which tags were deleted, and the ordered rotation list that
  actually closes it. `SECRET_KEY` is rotated and deployed; everything else on
  that list is still outstanding, the admin account password first.
- [`features/mobile-unreleased.md`](features/mobile-unreleased.md) —
  **what is in the app but not yet on Play.** The standing answer to "what
  changed since the last release?", plus the pre-build checklist (bump the
  version, deploy the backend first, verify the AAB has no localhost URL —
  including the byte-search command that replaces a `strings` check which
  fails open). 1.5.0+10 is built and on internal testing; empty this when it
  is promoted to production, not before.
- [`features/monthly-subscriptions.md`](features/monthly-subscriptions.md) —
  monthly instalment memberships and the vesting they gate (Agreement §5.2–§5.10):
  why a subscription is per pet, why an annual member has no row at all, why
  default is derived instead of swept, and the money invariant that stops a
  monthly payment re-granting the plan and handing back a spent allowance twelve
  times a year. Backend and app both built and exercised on a real device. **The
  backend half is now live in production** (verified 2026-08-19); the app half is
  on the internal testing track in 1.5.0+10 and gated on the unconfirmed prices.
- [`features/deployment-topology.md`](features/deployment-topology.md) —
  which repo and branch deploys to which host, which frontend calls which
  backend (staging points at *dev*), why production deploys from `master` and not
  `main`, the CORS allowlist that follows and why the mobile app is exempt from
  it, plus the operating rules for `deploy.ps1` and `APP_ENV`.

### Sessions
- [`sessions/2026-07-30-play-store-launch.md`](sessions/2026-07-30-play-store-launch.md) —
  Play Store production launch follow-up: internal-testing confusion,
  signing-key investigation, website Play Store buttons, then the v1.4.0 build,
  prod backend deploy, and submission for review.
- [`sessions/2026-08-03-launch-email-and-document-freeze.md`](sessions/2026-08-03-launch-email-and-document-freeze.md) —
  the app-launch announcement broadcast: what the member list actually contained
  (38 rows → 30, sent to 25), who was excluded and why; then froze the agreement
  and manual on the client's instruction.
- [`sessions/2026-08-07-getting-started-guide.md`](sessions/2026-08-07-getting-started-guide.md) —
  built `/getting-started`; confirmed QR Ph payments have been live all along (so
  no manual payment path is needed), corrected the app's plan flow, declined
  client edit access and why, and found the shipped app still asks for the frozen
  Membership Agreement. Then renamed the benefit pools from "wallet" to
  "benefit" — website only, so the app's wording now lags the site.
- [`sessions/2026-08-14-per-member-direct-pay-and-release.md`](sessions/2026-08-14-per-member-direct-pay-and-release.md) —
  republished the member documents with Rev. 5A / Rev. 3C, built the per-member
  direct-pay override and in-app claim instructions, then released across all
  three projects (prod migration, backend deploy, website sync, Play 1.4.1
  published). Found: pre-activation claims aren't deducted, no category matches
  "Emergency" so that pool is unreachable, and a skipped vaccination card can
  never be added.
- [`sessions/2026-08-14-backend-config-and-cleanup.md`](sessions/2026-08-14-backend-config-and-cleanup.md) —
  deleted `backend/.env` and made `APP_ENV` decide the environment (dev by
  default), added a hermetic test suite, and split the four largest backend
  files into packages without changing a single caller. Found: live credentials
  were being baked into every Docker image, `ALLOWED_ORIGINS` was deployed but
  never read, `migrate.py` ran every migration on import, and a `__file__`-based
  asset path broke every receipt while the whole suite stayed green. Then
  released to production, discovered that prod had been echoing
  `Access-Control-Allow-Origin` to any site that asked, found production
  credentials publicly pullable from Docker Hub, and gave the three auth guards
  their first tests.
- [`sessions/2026-08-14-benefit-utilization-kpi.md`](sessions/2026-08-14-benefit-utilization-kpi.md) —
  a client asked why Benefit Utilization read 0%; it was dividing by service
  sessions, which nothing increments since claims replaced clinic scans. Rebuilt
  it on the same peso pools the app's Benefit Wallet uses, then took the whole
  backend reorganisation to dev and prod. Found: `used_sessions` is now dead data,
  which silently makes the upgrade rule's "benefits untouched" check looser than
  its docstring; and the migration script deletes rows as well as adding columns.
- [`sessions/2026-08-15-emergency-pool-and-preactivation-claims.md`](sessions/2026-08-15-emergency-pool-and-preactivation-claims.md) —
  fixed the two alignment-register items that could misroute money: no service
  category matched the Emergency Wallet, so emergency claims drew on the far
  larger preventive pool and qualified for direct-to-provider pay; and a claim
  dated before the plan started was accepted, uncapped, and never deducted. A
  read-only audit of both databases confirmed production was affected by the
  first but that no emergency claim has ever been filed, so nothing was mispaid —
  and settled the duplicate `member_services` question at zero rows.
- [`sessions/2026-08-18-navy-chrome-and-narrow-screens.md`](sessions/2026-08-18-navy-chrome-and-narrow-screens.md) —
  made the app chrome navy and rebalanced Home to 60/30/10 (gold appeared ten
  times on one screen, navy once), then supported narrow screens down to 320dp —
  a normal phone at Samsung's largest Screen zoom, not just Fold cover displays.
  Records the measured contrast figures, including that **gold on navy is 2.9:1
  and fails even the 3:1 UI floor**. The keeper: two commits written from static
  analysis caught none of the six defects that mattered, all of which needed the
  app rendered on a device — among them a `Stack`/`Positioned` overlap that no
  amount of code reading exposes. Also: the pet card now states its plan, and the
  meter-bar redesign was built, rejected, and force-pushed away, so that
  complaint is still open.
- [`sessions/2026-08-19-pawpoints-admin.md`](sessions/2026-08-19-pawpoints-admin.md) —
  Romy asked whether an admin can see PawPoints per member; answering it found
  **dev and prod both had an empty rewards catalogue**, so every live member saw
  the app's "Rewards coming soon" empty state. The catalogue had only ever been
  hand-pasted into the Supabase SQL editor, and nothing seeds automatically. The
  keeper is why it hid from every surface at once: the app looked coming-soon,
  `seed.py` looked correct, no admin page existed to notice, and the gap register's
  warning was dismissed as stale *because* the seeder looked right — a seeder
  existing is not its rows existing, and no test reads a real database. Also:
  `pdftotext` **does** work here (the standing "PDFs unreadable" note was wrong),
  and it surfaced MMS-DWP-001 Part VI — an unreferenced controlled document that
  is the real PawPoints spec, mandating both dashboards, 12-month expiry and
  points reversal, and conflicting with the manual's catalogue. Built
  `/admin/paw-points`; the missing admin CRUD was the actual cause.
- [`sessions/2026-08-19-play-release-1-5-0.md`](sessions/2026-08-19-play-release-1-5-0.md) —
  built, verified and uploaded 1.5.0+10 to the **internal testing** track: monthly
  instalments, pet records, light-only theme and navy chrome, all 26 mobile
  commits since the 1.4.1 release. The keeper is a verification that **failed
  open** — `strings` is not installed here, so the AAB's compiled-in-URL check
  returned `0` for every host while reading nothing, which is indistinguishable
  from a clean build on exactly the two rows that guard against a Play rejection;
  the must-be-present row is what exposed it. Also found `mobile-unreleased.md`
  stale in both directions (a cleared blocker still declared, shipped work still
  listed as a separate branch), and the direct-APK route retired since
  2026-08-03 with its incompatibility now pointing the other way. Promotion to
  production is gated on the unconfirmed ₱300/₱600/₱900 monthly prices.
