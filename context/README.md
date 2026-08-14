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
  the two Android install routes (Google Play + direct APK), why they are
  mutually incompatible, and how the website presents the choice.
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
  actually closes it. Nothing has been rotated yet.
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
