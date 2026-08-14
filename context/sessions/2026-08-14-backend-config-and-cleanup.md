# 2026-08-14 — Backend environments, a test suite, and a structural cleanup

Second session of 2026-08-14, picked up after the 1.4.1 release earlier the same
day. Started as "delete `backend/.env` and make the project easy to run", and
widened into config, tests, and splitting the three largest backend files.

**Backend only.** No app or website source changed — the website repo work at
the end was a branch sync, not an edit.

## 1. Which environment a process is depends on `APP_ENV` now

`backend/.env` is gone. `backend/config.py` resolves `APP_ENV` — unset or `dev`
reads `.env.dev`, `prod` reads `.env.prod` — with `.env.local` as a personal
override above both, and real environment variables above everything, which is
how Render and `docker run --env-file` already worked. Every process prints its
target on startup:

```
[config] APP_ENV=dev  db=aws-1-ap-southeast-2.pooler.supabase.com:6543/postgres  config=.env.dev
```

This closes item 4 of the previous session's *Left open*: there is no longer a
`.env` to point at the wrong database. A bare `python -m uvicorn main:app` now
targets dev, so `import main` can no longer run `create_all` against production
by accident. The variables themselves are documented in `backend/CLAUDE.md`.

### The reset-on-Ctrl+C trap — observed, not theorised

The obvious way to run one command against prod is wrong:

```powershell
$env:APP_ENV='prod'; python -m uvicorn main:app --port 8000; $env:APP_ENV=$null
```

**Ctrl+C aborts the rest of the line, so the reset never runs.** This happened
within minutes of it being suggested: the next bare `python -m uvicorn main:app`
in the same terminal printed `APP_ENV=prod` and served the live database.

Scope it to a child process instead, so the parent shell never holds it:

```powershell
cmd /c "set APP_ENV=prod&& python migrate.py"
```

`backend/run.ps1` exists for this reason — `.\run.ps1` for dev with reload,
`.\run.ps1 -Env prod` types `PROD` to confirm and defaults reload **off**,
because the reloader re-imports the app (and so re-runs `create_all`) on every
file save.

## 2. Secrets were being baked into every Docker image

`.dockerignore` excluded `.env` but not `.env.dev` or `.env.prod`, and the
Dockerfile does `COPY . .`. Every image pushed to
`marioogarbo/metropaws-backend*` therefore contained the **live database URL,
Supabase service key, PayMongo live keys, and the Render API key**.

Fixed by excluding `.env*` — images pushed from `20260814-131454` onward are
clean. **Every earlier tag on Docker Hub still contains them.** Rotating those
credentials or deleting the tags is the only thing that actually resolves it;
the fix only stops new images.

Member data is a separate, still-open case. `notify_app_launch_sent.log` (25
member addresses) was deleted on 2026-08-14 at Mario's request — with it goes
the guard that made `notify_app_launch.py --send` skip people already emailed, so
a re-run would email all 25 again. `founding_reservations_backup.csv` / `.json`
are gitignored but **not** dockerignored, so they still enter the image; Mario
chose to leave that.

## 3. CORS was configured but not enforced

`ALLOWED_ORIGINS` was set in both env files and pushed to Render on every
deploy, and read by nothing — `main.py` hardcoded `allow_origins=["*"]`.

It is enforced now, plus `ALLOWED_ORIGIN_REGEX` for Vercel previews. Facts
established while choosing the list, all verified:

- **`https://www.metropaws.ph` is the production origin.** The bare
  `metropaws.ph` returns 307 to it, so `www` is what browsers actually send.
- **`staging-metropaws.vercel.app` is live**, served from the separate
  `marioogarbo/staging-metropaws-website` repo, and **its `NEXT_PUBLIC_API_URL`
  points at the dev backend** (confirmed by reading the deployed client bundle).
- **Preview URLs carry the Vercel account slug** —
  `staging-metropaws-1rgrc4xmo-mario-garbos-projects.vercel.app`. The pattern is
  anchored on it, because a bare `*.vercel.app` would admit any site anyone has
  ever deployed there.
- **Previews reach the production API.** `website/lib/api.ts` falls back to
  `https://metropaws-backend.onrender.com` whenever `NEXT_PUBLIC_API_URL` is
  unset, so prod carries the preview pattern too — without it a preview of the
  website repo would have its admin login blocked.

Two decisions worth keeping:

- **Unset means allow everything, loudly.** A missing variable locking admins out
  of production is a worse failure than a permissive default. The startup line
  `[cors] no ALLOWED_ORIGINS set` is how you notice.
- `allow_credentials` now tracks whether the list is explicit, because browsers
  reject credentialed requests against `"*"` — advertising it there was a promise
  the middleware could not keep.

**The mobile app is unaffected by any of this** — native HTTP sends no `Origin`
header, so CORS never applies to it. This governs the website's browser-side
calls only: admin login, password reset, and the public founding/pricing forms.

## 4. The three biggest files became packages

| Was | Now | Largest module |
| --- | --- | --- |
| `routers/admin.py`, 1,347 lines | `routers/admin/`, 12 modules | 214 |
| `schemas.py`, ~1,000 lines / 87 models | `schemas/`, 18 modules | 118 |
| `email_utils.py`, 629 lines | `email_utils/`, 7 modules | 244 |

Each keeps its original import name and re-exports everything, so **no caller
changed**. `models.py` (623) was deliberately left alone: SQLAlchemy's registry
and relationship resolution make import order load-bearing there, for little
gain.

Two things that will matter to whoever extends this:

- **`schemas/` is layered, not themed.** The module boundaries came from the
  actual dependency graph: `validators → services → pets, plans → members →
  bookings → clinics`, and `providers → reimbursements`. `ClinicBriefOut` sits
  with bookings rather than clinics specifically to break a cycle — its own
  comment says it exists for booking responses. If two modules ever need each
  other, the shared shape belongs in the lower one.
- **`email_utils` keeps that name on purpose.** A package called `email` would
  shadow the standard library module its own transport imports `MIMEText` from.

### How the moves were verified

Worth reusing, because "the tests pass" is not sufficient for a pure move:

- Bodies were **sliced out of the original by AST line span**, never retyped, with
  the splitter asserting every top-level name landed in exactly one module.
- For routers and schemas: the generated **OpenAPI schema is byte-identical**
  across all 10,239 lines — every path, method, tag, operation id, field, default
  and constraint.
- Registration order does shift when routers regroup (30 of 122 moved), so every
  URL was resolved through the real router before and after: **all 121 resolve to
  the same handler function**.
- OpenAPI proves nothing about email, so every template was **rendered** with
  `_send_email` patched out — 15 bodies across all five claim statuses in both
  payout variants, the receipt, the reset link, and all three launch audiences —
  and diffed. Byte-identical.

## 5. There are tests now

125 of them, ~3 seconds, and hermetic: `tests/conftest.py` pins `DATABASE_URL`
to in-memory SQLite **before any project module is imported**, so the suite
cannot reach dev or production even with env files present. Coverage is aimed at
the rules that move money — `pricing_utils` and `plan_term_utils` at 100%,
`reimbursement_utils` at 80%.

`tests/routes_snapshot.json` pins all 121 endpoints. Regenerating it is a
deliberate act (`python -m tests.generate_routes_snapshot`) so a refactor cannot
quietly drop a route the app depends on.

## Findings

### 1. The Emergency-category gap is now pinned by a test

Register [item 12](../features/document-system-alignment.md) is unchanged and
still unfixed, but `tests/test_reimbursement_utils.py` now asserts the current
behaviour explicitly —
`test_emergency_stabilization_does_not_match_the_emergency_pool` — with a
docstring saying it documents a gap rather than endorses it. Whoever fixes the
category will see that test fail and has to update it deliberately.

### 2. Two email templates don't use the shared shell

`email_utils/claims.py` and `email_utils/receipts.py` predate
`layout._branded_shell` and still inline their own HTML shells, so **a styling
change to MetroPaws emails currently has to be made in three places**. Not
changed here: it alters what members see in their inbox, which is a product
decision. `password_reset` and `app_launch` do use the shell.

### 3. The docs described an upload path that no longer exists

`backend/CLAUDE.md` and `storage.py`'s docstring both described a legacy
`_validate_and_save_file()` in `routers/pets.py` that "still trusts the client
Content-Type". That function does not exist — everything already goes through
`storage.save_upload`. The docs were advertising a weakness the code doesn't
have. Corrected.

### 4. Nearly half of ruff's findings are wrong for FastAPI

A bare `ruff check` reported 690 problems, of which **309 fire on correct code**:
`B008` flags every `Depends()` in an argument default, and `ARG001` flags every
`current_user` parameter — which is unused precisely because its presence is what
applies the auth guard. `--fix` would have broken authentication.

`pyproject.toml` now records which rules apply and why, including `E712` ignored
because SQLAlchemy filters need `Column == True` (`if Column:` doesn't build
SQL). After that, 19 real findings remained and all were fixed — 13 of them
`raise ... from exc`, which is what keeps the original error in the traceback
when a receipt PDF or PayMongo call fails in production.

### 5. PowerShell traps hit during this session

- **`deploy.ps1` fails if you redirect its stderr.** `.\deploy.ps1 -Env dev 2>&1`
  or `2>$null` turns Docker's normal progress output into an ErrorRecord, and the
  script's `$ErrorActionPreference = "Stop"` aborts it right after a *successful*
  build. Run it with no redirection.
- **`-SkipHttpErrorCheck` is PowerShell 7+.** A verification loop using it threw
  silently for ten minutes on this 5.1 host while appearing to poll. `curl.exe`
  is the reliable way to inspect response headers here.
- **`Compare-Object` compares as sets, not sequences.** It reported route
  ordering as "identical" when 30 routes had in fact moved. Positional comparison
  is required.

## Verified

| Check | Result |
| --- | --- |
| `deploy.ps1 -Env dev` | images `20260814-131454`, then `20260814-133025` |
| Live dev `/openapi.json` | 95 paths, 117 operations, 47 admin paths, 92 models — matches local |
| Live dev CORS | `www.metropaws.ph`, bare domain, staging, account previews, `localhost:3000` allowed; unrelated `*.vercel.app` and `evil.example.com` blocked |
| Real browser admin login | `staging-metropaws.vercel.app/admin/dashboard` loads authenticated data against the dev backend |
| `staging-metropaws-website` `main` | `74f7617..612fcc6`, fast-forward, 30 commits, now matches `main:website` |

The browser login is the meaningful one: it exercises the new CORS, the split
`routers/admin/` and the split `schemas/` together, in a real deployment.

## Left open

1. **`main` is 12 commits ahead of `origin/main`** and unpushed.
2. **Production backend is not deployed.** It still runs `allow_origins=["*"]`
   and the pre-split code. The CORS change reaches real members only then.
3. **Old Docker Hub tags still contain live credentials.** Delete the tags or
   rotate the keys — the `.dockerignore` fix only protects new images.
4. **`staging-metropaws-website`'s `master` and `staging` branches** are still on
   the 2026-07-11 commit; only `main` was moved.
5. **GitHub is showing a billing failure** on the account ("We are having a
   problem billing your account"). Unrelated to this work.
6. `founding_reservations_backup.csv` / `.json` still enter the Docker image.
7. `email_utils.notify_status` is the one uncovered branch — it needs a mail
   double to test meaningfully.
8. Deleting the broadcast ledger re-armed the double-send risk in
   `notify_app_launch.py` (see §2).
