# Credential exposure via public Docker images (2026-08-14)

Production credentials were readable by anyone for roughly four months, because
the backend's `.dockerignore` excluded `.env` but not `.env.dev` or `.env.prod`,
and the Dockerfile does `COPY . .`. Both Docker Hub repositories are public.

**No secrets in this file** — only which kinds were exposed, and what has and
has not been done about it.

## What was exposed

Every image tag pushed between **2026-04-26** and **2026-08-14** contained both
`/app/.env.dev` and `/app/.env.prod`. The dev repository carried the production
file too, so "it was only dev" was never true.

Verified by running an old image, not inferred:

```
docker run --rm marioogarbo/metropaws-backend:20260814-093000 sh -c "ls -la /app/.env*"
-rwxr-xr-x 1 app app 2760 /app/.env.dev
-rwxr-xr-x 1 app app 3923 /app/.env.prod
```

| Credential | What it grants |
| --- | --- |
| `SEED_ADMIN_PASSWORD` | The literal password on `admin@metropaws.ph`. Usable at the login form — no tooling required. **The most immediately exploitable.** |
| `SECRET_KEY` | Signs JWTs. Forges an admin token for any user id. |
| `DATABASE_URL` | Direct Postgres on the live member database (Supabase pooler, internet-reachable). |
| `SUPABASE_SERVICE_KEY` | service_role — bypasses row-level security; also Storage. |
| `RENDER_API_KEY` | Account-level: redeploy, rewrite env vars, delete services. |
| `PAYMONGO_SECRET_KEY` | **Live** payments API (the file holds `sk_live_…`, not test). |
| `PAYMONGO_WEBHOOK_SECRET` | Forges `checkout_session.payment.paid`, granting plans without paying. |
| `ZEPTOMAIL_TOKEN`, `SMTP_PASSWORD` | Sends mail as MetroPaws to members. |

Scale: 68 tags on `metropaws-backend` (oldest 2026-04-26), 32 on
`metropaws-backend-dev` (oldest 2026-06-24); 4,141 and 1,615 pulls respectively.
Pull counts include our own deploys, so they are an upper bound on third-party
access, not evidence of it.

GitHub was never affected — the env files are gitignored and have never been
committed. This was Docker Hub only.

## Done

- **`.dockerignore` now excludes `.env*`** (commit `db5363f`). Images pushed from
  `20260814-131454` (dev) and `20260814-144603` (prod) onward are clean, verified
  the same way.
- **96 tags deleted** on 2026-08-14 via the Docker Hub API. Four remain: `latest`
  and today's versioned build in each repo, both confirmed to contain no env
  files. `latest` was left in place throughout, so Render never lost its pull
  target.
- **`SECRET_KEY` rotated** in `.env.dev` and `.env.prod` — fresh 512-bit values,
  different per environment. **Not yet deployed**: the running services still
  hold the old key, and the next deploy for any reason will push the new one and
  log every member and admin out (tokens last 7 days). Originals are in the
  session scratchpad.

## Not done — this is what actually closes it

Deleting tags stops new copies. It does nothing about four months of
availability; anyone who pulled an image still has the file. **Treat every
credential above as compromised until rotated.**

Ordered by how easily each can be used, not by how alarming it sounds:

1. **The admin account password.** Rotating `SEED_ADMIN_PASSWORD` alone changes
   nothing — it is only read when seeding. The account's own password has to
   change. There is no "change password while signed in" endpoint; the only path
   is the forgot-password email flow, or updating the hash directly.
2. `SECRET_KEY` — rotated in the files, pending a deploy.
3. `DATABASE_URL` (Supabase → Settings → Database → reset password). The only one
   with a real outage window: the running service keeps the old password and
   starts failing the moment it is reset, until the redeploy lands. Do it last,
   immediately before deploying.
4. `SUPABASE_SERVICE_KEY`. Note the constraint recorded in `.env.prod`: this must
   be the **legacy** `service_role` JWT (starts `eyJ`) — the newer `sb_secret_…`
   keys 403 with "Invalid Compact JWS". A fresh legacy key means rotating the
   project's JWT secret, which regenerates `anon` as well. Nothing here uses
   `anon`.
5. `RENDER_API_KEY` — zero downtime, only `deploy.ps1` reads it.
6. PayMongo secret + webhook secret. The webhook secret is tied to the endpoint
   registration, so rotating it means recreating the webhook.
7. `ZEPTOMAIL_TOKEN`, `SMTP_PASSWORD`.

Then check Supabase logs, PayMongo transactions and Render deploy history for
anything unrecognised.

## Why it happened, so it doesn't again

`.dockerignore` listed `.env` when only that file existed. `.env.dev` and
`.env.prod` were introduced later and nobody revisited the ignore list — the
kind of gap that never announces itself, because the build keeps working.

The general rule now recorded in `backend/CLAUDE.md`: secrets never enter the
image. Configuration arrives as real environment variables at runtime —
`--env-file` locally, Render's env vars in deployment — and `app/config.py` is built
around that, with files being a local-development convenience only.

## Related

- [`deployment-topology.md`](deployment-topology.md) — the registry, what each
  repo feeds, and the operating rules.
- [`../sessions/2026-08-14-backend-config-and-cleanup.md`](../sessions/2026-08-14-backend-config-and-cleanup.md)
  — the session where this was found and acted on.
