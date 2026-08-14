# Deployment topology — what runs where, and what calls what

Which repo deploys to which host, which frontend talks to which backend, and the
CORS allowlist that follows from it. None of this is visible from the code, and
getting it wrong locks admins out of the website or lets any site call the API.

Established 2026-08-14. Everything below was verified against the live hosts and
dashboards unless marked otherwise.

## The map

| Surface | Source | Branch | Host | Calls |
| --- | --- | --- | --- | --- |
| Production website | `marioogarbo/metropaws-website` | **`master`** | Vercel `metropaws` → `www.metropaws.ph` | prod backend |
| Staging website | `marioogarbo/staging-metropaws-website` | `main` | Vercel `staging-metropaws` → `staging-metropaws.vercel.app` | **dev backend** |
| Prod backend | monorepo `backend/` | — | Render `metropaws-backend` (Singapore) | prod Supabase |
| Dev backend | monorepo `backend/` | — | Render `metropaws-backend-dev` (Singapore) | dev Supabase |
| Mobile app | monorepo `mobile/` | — | Google Play | prod backend |

Three traps in that table:

- **Production deploys from `master`, not `main`.** `metropaws-website`'s `main`
  branch is stale (last touched 2026-07-27). Only `master` is current.
- **The staging site is a different repository**, not a branch of the production
  one. Its histories share an ancestor, so syncing it is a fast-forward, not a
  force push.
- **Staging points at the *dev* backend** via `NEXT_PUBLIC_API_URL` (confirmed by
  reading the deployed client bundle). That makes it the natural place to
  click-test backend changes before production.

The monorepo (`marioogarbo/metropaws`, **public**) holds `backend/`, `website/`,
`mobile/`. `website/` is kept byte-identical to `metropaws-website:master` and
synced by pushing that ref — there is no `git subtree` history.

## Domains

`metropaws.ph` returns **307 → `https://www.metropaws.ph/`**. So `www` is the
origin a browser actually sends, and it is the one that must be allowed. The
bare domain is allowed too, harmlessly.

## Vercel preview URLs carry the account slug

A real one:

```
staging-metropaws-1rgrc4xmo-mario-garbos-projects.vercel.app
```

CORS matches previews by pattern, anchored on that slug:

```
^https://[a-z0-9-]+-mario-garbos-projects\.vercel\.app$
```

A bare `*.vercel.app` would admit **any site anyone has ever deployed to
Vercel**, which is not a trade worth making to support previews. If the Vercel
account is ever renamed, this pattern is what breaks.

**Previews reach the production API.** `website/lib/api.ts` falls back to
`https://metropaws-backend.onrender.com` whenever `NEXT_PUBLIC_API_URL` is
unset, so the pattern is set on prod as well as dev.

## What CORS actually governs

Only the website's **browser-side** calls: admin login, password reset, and the
public founding/pricing forms — five files import the axios client. Everything
else in the website is Next.js server actions, which are server-to-server.

**The mobile app is not affected at all.** Native HTTP sends no `Origin` header,
so CORS never applies to it. Restricting origins cannot break the app.

Allowlists live in `backend/.env.dev` and `backend/.env.prod` and reach Render
via `deploy.ps1`. Dev additionally allows `http://localhost:3000`; prod does not.
With `ALLOWED_ORIGINS` and `ALLOWED_ORIGIN_REGEX` both unset the API allows every
origin and logs `[cors] no ALLOWED_ORIGINS set` — deliberate, because a missing
variable locking admins out of production is the worse failure.

## Operating rules

- **`deploy.ps1` full-replaces Render's env vars** from `.env.<env>`. Any new
  variable must be added to its `$renderEnvKeys` allowlist or it is silently
  dropped on the next deploy.
- **`deploy.ps1` does not run migrations.** Run `scripts/migrate.py` against the target
  database *first*, or the deployed API 500s on the affected tables. Since
  2026-08-14 it does nothing on import and has to be invoked explicitly
  (`python -m scripts.migrate`); before that, merely importing it migrated whatever
  `APP_ENV` pointed at.
- **Never redirect `deploy.ps1`'s stderr.** `2>&1` or `2>$null` turns Docker's
  progress output into an ErrorRecord and its `$ErrorActionPreference = "Stop"`
  aborts the script after a successful build.
- **Scope `APP_ENV` to a child process**, never to the shell:
  `cmd /c "set APP_ENV=prod&& …"`, or `.\run.ps1 -Env prod`. The
  `$env:APP_ENV='prod'; …; $env:APP_ENV=$null` form does not survive Ctrl+C, and
  leaves the terminal pointed at production.

## Docker images

`marioogarbo/metropaws-backend` (prod) and `-dev`. Tagged `latest` plus a
`yyyyMMdd-HHmmss` stamp; Render pulls `latest`.

**Both repositories are public.** Anyone can pull any tag without an account,
which is what made the 2026-08 credential exposure serious rather than
theoretical: every tag pushed before 2026-08-14 carried `.env.dev` and
`.env.prod` inside the image. Those 96 tags were deleted on 2026-08-14 and only
`latest` plus one clean versioned build remain in each repo. **`SECRET_KEY` has
since been rotated and deployed; the rest of the credentials still need
rotating** — see
[`credential-exposure-2026-08.md`](credential-exposure-2026-08.md).

Keep `latest` alive through any future cleanup: it is Render's pull target, and
deleting it breaks both services.

`founding_reservations_backup.csv` / `.json` still enter the image (gitignored
but not dockerignored) — a deliberate choice as of 2026-08-14.

## Related

- `backend/CLAUDE.md` — the environment variables themselves and `APP_ENV`.
- [`sessions/2026-08-14-backend-config-and-cleanup.md`](../sessions/2026-08-14-backend-config-and-cleanup.md)
  — where this was established, and what was verified live.
- [`android-distribution.md`](android-distribution.md) — the app's two install
  routes, which have their own signing constraints.
