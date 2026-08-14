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

---

## Second pass — after the merge and push

`main` was merged, pushed, and deployed to dev before this part started, so it
is on its own branch (`refactor/backend-organize`). Work chosen against the
Clean Code catalog rather than by file size, which changed what got done.

### 6. `config` is now the only way the environment is read

26 `os.getenv` calls across six modules became `config.*` (G11, G35). Grepping
`os.getenv` outside `config.py` returns nothing.

`pricing_utils` and `plan_term_utils` deliberately did **not** move to
`config.env_int`, and now say why in the code: `env_int` raises on an
unparseable value, which is correct for a startup setting and wrong for a live
pricing tunable — a typo there must not take checkout down. Same read,
different and documented policy.

### 7. `migrate.py` no longer migrates on import

It was 378 lines of top-level statements: `create_all` plus 16 bare
`with engine.connect()` blocks. **Eighteen statements ran at import**, so
`import migrate` applied every migration to whatever `APP_ENV` resolved to —
the same hazard as the prod-pointing `.env`, with nothing in the module's shape
to warn you.

Now one named function per step with a docstring, a `MIGRATIONS` tuple, and
`main()` behind a `__main__` guard. It prints the target database and each step
as it runs, instead of silence until "Migration complete."

Verified: the SQL was lifted by line span, never retyped — 31 statements before,
31 after, identical text and order; import-time statements 18 → 0; then run
against dev end to end, where it is a no-op on an up-to-date schema.
`tests/test_migrate.py` pins all of it, including that every step is registered
in `MIGRATIONS` (an unregistered one would silently never run).

### 8. `invoice_utils` became a package, and the move broke every receipt

Split into `business` / `formatting` / `render` / `delivery`. The interesting
part is the bug it exposed, described in finding 6 below.

## Findings (second pass)

### 6. A `__file__`-relative path broke silently, and the whole suite passed

`invoice_utils._ASSETS_DIR` was
`os.path.join(os.path.dirname(os.path.abspath(__file__)), "assets")`. Moving the
module one directory deeper into a package made it resolve to
`backend/invoice_utils/assets/`, so **every receipt render would have raised
`FileNotFoundError`** looking for the bundled Montserrat weights.

**All 130 tests passed anyway** — nothing in the suite had ever rendered a PDF.
What caught it was rendering a receipt from fixed inputs before and after the
move and diffing the bytes; the "after" run simply failed.

Two things to keep from this:

- **Anchor asset paths on `config.BACKEND_DIR`, never on `__file__`.** A module
  can move; the backend directory is the stable reference.
- **A green suite is not evidence for a move.** Byte-comparing the real output —
  OpenAPI for routers and schemas, rendered HTML for emails, rendered PDF for
  receipts — is what actually caught things this session. Twice.

`tests/test_invoice_utils.py` now renders receipts (plain, discounted, no-pet)
and asserts the fonts and logo resolve.

### 7. Most F1 / G30 violations here are not worth fixing

Measured across the backend, excluding route handlers whose parameters are the
HTTP interface: **19 functions take more than 3 arguments** (F1) and **7 exceed
60 lines** (G30). Deliberately left alone, so this doesn't get re-litigated:

- The 10-argument email senders (`send_payment_receipt_email`,
  `send_claim_status_email`) read fine because every call site uses keyword
  arguments. The prescribed dataclass fix would relocate the same ten fields.
- The longest functions are template builders (`build_app_launch_email`, 123
  lines) — linear and cohesive; splitting fragments a template.
- The genuine F1 case is `invoice_utils.render`, which threads the same context
  through six drawing functions. That one is worth a context object.

### 8. The money-path functions are long *and* untested

`routers/admin/plans._apply_service_caps` (80 lines), `plan_utils.grant_plan_to_pet`
(79) and `pricing_utils.pack_discount_quote` (70) are the real G30 candidates,
but only the last has direct test coverage. Restructuring the first two without
tests first would be how you cause an incident, not prevent one. Tests before
refactor, in that order.

---

## Third pass — production release, and what the audit turned up

### 9. `main` went to production

`deploy.ps1 -Env prod` from `main` at `5a185c5` — deliberately not the
`refactor/backend-organize` branch, which had never been deployed anywhere.
No migration was needed: nothing on `main` touches `models.py`.

Image `20260814-144603`, deploy `dep-d9v9rap42hec738glngg`. Verified live:

| Origin | Before | After |
| --- | --- | --- |
| `www.metropaws.ph`, bare domain, staging, own previews | allowed | allowed |
| `localhost:3000` | allowed | **blocked** |
| unrelated `*.vercel.app`, `evil.example.com` | allowed | **blocked** |

The "before" column is the finding: production was echoing
`Access-Control-Allow-Origin` back to *any* site that asked, **with credentials
enabled** — so any website could make authenticated cross-origin calls using a
member's token. That is what `ALLOWED_ORIGINS`-not-being-read actually cost.

Live `/openapi.json` reports 95 paths, 117 operations, 47 admin paths, 92 models
— identical to local, so all four package splits import correctly in the
production image.

Consequence to remember: **`localhost:3000` can no longer call the production
API.** Local website development must point `NEXT_PUBLIC_API_URL` at the dev
backend, which is what staging already does.

### 10. The Docker Hub exposure was confirmed, measured and partly closed

Full account in [`features/credential-exposure-2026-08.md`](../features/credential-exposure-2026-08.md).
In short: every image tag pushed between 2026-04-26 and today contained
`.env.prod`; 96 tags were deleted, four clean ones remain, and **none of the
credentials have been rotated yet**. `SECRET_KEY` is rotated in the env files
but not deployed.

### 11. `_apply_service_caps` and the auth guards got tests

- `_apply_service_caps` (14 tests) — the audited money-config path. No bug
  found; it behaves as documented, including the boundary where an omitted
  `sessions` must not zero the value and an explicit `0` must not be read as
  "not supplied".
- **The three auth guards had no coverage at all** (136 tests). `require_admin`,
  `require_member` and `get_current_user` are the guards `CLAUDE.md` calls
  load-bearing, and deleting one from a handler would have left every test
  green. Now every `/admin` route is checked for 401 anonymous and 403 as a
  member, driven off the real route table so new routes are covered on arrival.

333 tests total.

## Findings (third pass)

### 9. The unauthenticated surface, now pinned

Walking every route anonymously found **27 that answer without a token**. All
deliberate — `/auth/*`, public content, the settings the app reads before
sign-in, PayMongo's return pages and webhook. The set is now asserted, so an
endpoint that forgets its guard shows up as an addition.

Two things in it are decisions rather than bugs, recorded so they are not
rediscovered as alarms:

- **`/docs`, `/redoc` and `/openapi.json` are public**, advertising the whole
  admin API. It is also how deploys get verified here.
- **`GET /auth/check-email` confirms whether an address is registered.** That is
  user enumeration, in a codebase that deliberately hardened
  `/auth/forgot-password` to always return 200 *to prevent exactly that*. It is
  rate-limited to 5/min per IP, which slows it rather than stopping it. The
  registration form needs it for the "email already taken" check, so it is a
  genuine UX-versus-privacy trade.

### 10. `seed.py` had migrate.py's problem, and hid a migration

15 statements ran on import, including `create_all` and creating the admin
account — against whatever `APP_ENV` resolved to. It also raised on import when
`SEED_ADMIN_PASSWORD` was unset.

While restructuring it, `migrations/add_paw_points.sql` turned out to be
orphaned: referenced by nothing, pasted into the Supabase SQL editor by hand, so
**a fresh environment silently had no PawPoints rewards catalogue**. It could
not safely be re-run either — its ids came from `gen_random_uuid()`, so
`ON CONFLICT DO NOTHING` never matched and a second run would have inserted all
seven rewards again. Absorbed into `seed_paw_points_rewards`, matched on name;
file and directory deleted.

### 11. Test helpers that reimplement production sequencing will lie to you

The first `seed.py` test helper copied `main()`'s loop but left out the commit
between steps. The session is `autoflush=False`, so `seed_plan_services` could
not see the plans `seed_plans` had added, and the test failed against correct
code. Both now call the same `run_all()`.

This is the second time in one session that a divergence between a real path and
a near-copy caused a false signal — the first produced the duplicate-benefit bug
in `grant_plan_to_member`. Where sequencing matters, have one function own it
and make the test call that.

## Left open

1. **No credential has been rotated.** The single most important item; see
   [`features/credential-exposure-2026-08.md`](../features/credential-exposure-2026-08.md)
   for the ordered list. The admin account password is the most exploitable.
2. **`SECRET_KEY` is rotated in the env files but not deployed.** The next
   deploy — for any reason — pushes it and logs everyone out. Not a problem,
   but not a surprise you want mid-something-else.
3. **A Docker Hub access token with delete scope, never-expiring, was pasted in
   plaintext during this session.** Revoke it.
4. **`refactor/backend-organize` is unmerged and unpushed** — 8 commits, never
   deployed. Dev before prod.
5. **Production may already hold duplicate `member_services` rows** from the
   `grant_plan_to_member` bug fixed in `4261c20`. The fix stops new ones; it
   does not clean up old ones. A read-only count would settle it.
6. A context object for `invoice_utils.render`'s six drawing functions (F1,
   second-pass finding 7).
7. **`staging-metropaws-website`'s `master` and `staging` branches** are still on
   the 2026-07-11 commit; only `main` was moved.
8. **GitHub is showing a billing failure** on the account. Unrelated to this work.
9. `founding_reservations_backup.csv` / `.json` still enter the Docker image.
10. `email_utils.notify_status` is the one uncovered branch — it needs a mail
    double to test meaningfully.
11. Deleting the broadcast ledger re-armed the double-send risk in
    `notify_app_launch.py` (see §2).
12. `email_utils` `claims` and `receipts` still inline their own HTML shell
    instead of `layout._branded_shell` (finding 2) — a product decision, since
    fixing it changes what members see.
