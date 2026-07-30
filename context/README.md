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

### Sessions
- [`sessions/2026-07-30-play-store-launch.md`](sessions/2026-07-30-play-store-launch.md) —
  Play Store production launch follow-up: internal-testing confusion,
  signing-key investigation, website Play Store buttons.
