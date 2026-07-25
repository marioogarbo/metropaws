# CLAUDE.md — MetroPaws Backend

AI instructions for this directory. Read this before writing or modifying any backend code.

---

## Architecture at a Glance

```
HTTP Request → FastAPI Router → Depends(auth) → Business Logic → SQLAlchemy ORM → PostgreSQL (Supabase)
                                                      ↓
                                               uploads/ (local disk, mounted volume in Docker)
```

**Single process, no background workers.** All operations are synchronous request/response. There is no task queue, no WebSocket, no caching layer.

---

## File Responsibilities

| File | What it owns |
|---|---|
| `main.py` | App factory, middleware, static file mount, router registration, DB table creation on startup |
| `database.py` | SQLAlchemy engine + `SessionLocal` + `get_db` dependency |
| `models.py` | All ORM table definitions — single source of truth for the DB schema |
| `schemas.py` | All Pydantic request/response models — single source of truth for API contracts |
| `auth.py` | JWT encode/decode, password hashing, and the three FastAPI dependency guards: `get_current_user`, `require_admin`, `require_member` |
| `email_utils.py` | Outbound email — password reset, reimbursement claim status updates, **and payment receipt (`send_payment_receipt_email`, PDF attached)**. Sends via the **ZeptoMail HTTP API** when `ZEPTOMAIL_TOKEN` is set (**required in prod** — Render's free tier blocks outbound SMTP ports 25/465/587); falls back to plain SMTP for local dev. |
| `invoice_utils.py` | **Payment receipt PDF generation + send** (fpdf2, branded, `assets/metropaws-logo.png` + bundled Montserrat). `notify_payment_receipt` = best-effort/never-raises (auto path); `generate_and_send` = raises (admin resend). |
| `storage.py` | **Canonical file-upload helper (`save_upload`)** — writes to Supabase Storage when configured, else local disk. Use this for new uploads. |
| `reimbursement_utils.py` | Shared reimbursement math (per-plan cap, category usage/remaining) + best-effort status email |
| `seed.py` | One-time script to create default `ServiceType` rows and the admin user — not part of the app lifecycle |
| `routers/auth.py` | Registration, login, `/me`, forgot/reset password |
| `routers/members.py` | Member profile CRUD + in-app notifications (list / unread-count / mark-read) |
| `routers/pets.py` | Pet CRUD + file uploads (photos, vax cards) |
| `routers/admin.py` | QR scan, service deployment, service assignment, member listing, logs, reimbursement review |
| `routers/reimbursements.py` | Member reimbursement claims: submit, list, resubmit, Benefit Wallet |
| `routers/payments.py` | PayMongo checkout, return pages, webhook, plan-grant on payment |
| `routers/settings.py` | App settings (payments on/off, founding-50 toggle/limit) |
| `paymongo.py` | PayMongo REST client — Checkout Sessions + webhook signature verification |

---

## Data Model & Relationships

```
User (1) ──── (1) Member (1) ──── (many) Pet
                    │
                    └──── (many) MemberService ──── ServiceType
                    └──── (many) ServiceLog    ──── ServiceType
                                               └─── Pet (nullable)

User (admin) ──── logs ──── ServiceLog
```

**Key invariants — never break these:**

- `User` and `Member` are always created together in the same transaction during `/auth/register`. There is no `User` without a `Member` row.
- `Member.qr_token` is a UUID generated at creation and is the only lookup key for QR scans. Never expose a flow that changes it without admin intent.
- `MemberService.remaining_sessions` is a computed property (`total_sessions - used_sessions`). The `deploy-service` endpoint increments `used_sessions` — never mutate `total_sessions` to log a service.
- `ServiceLog` is append-only. Never delete or edit logs — they are the audit trail.
- `PasswordResetToken` expires in 1 hour. The token is deleted immediately on use or on the next forgot-password request for the same user.

---

## Auth & RBAC

Three dependency guards in `auth.py` — always use the right one:

| Dependency | Grants access to |
|---|---|
| `get_current_user` | Any authenticated user (member or admin) |
| `require_admin` | Admin role only — raises 403 otherwise |
| `require_member` | Member role only — raises 403 otherwise |

JWT payload shape: `{ "sub": user.id, "role": "member"|"admin", "exp": ... }`

Token lifetime: 7 days (`ACCESS_TOKEN_EXPIRE_MINUTES=10080`). There is no refresh token — the Flutter app must re-login after expiry.

**Security patterns already in place — don't regress them:**
- `/auth/forgot-password` always returns HTTP 200 regardless of whether the email exists (prevents user enumeration).
- File uploads use UUID filenames — original filenames are never persisted to disk.
- MIME type is validated against an allowlist before writing any file. Extension is derived from the allowed MIME, not trusted from the client.

---

## File Uploads

New uploads go through `save_upload()` in `storage.py`. Legacy pet photo / vax card uploads still use `_validate_and_save_file()` in `routers/pets.py` (same validation; migrating it to `storage.py` is a pending follow-up).

| Upload type | Subdir | Allowed MIME types | Max size |
|---|---|---|---|
| Pet photo | `photos/` | jpeg, png, webp | env `MAX_FILE_BYTES` |
| Vaccination card | `vax_cards/` | jpeg, png, pdf | env `MAX_FILE_BYTES` |
| Reimbursement receipt | `receipts/` | jpeg, png, pdf | env `MAX_FILE_BYTES` (8 MB default in `storage.py`) |

UUID filenames; extension derived from the validated MIME, never the client filename. The returned value is a full public URL saved on the row (e.g. `reimbursements.receipt_url`).

**Storage durability (important):** when `SUPABASE_URL` + `SUPABASE_SERVICE_KEY` are set, `storage.py` uploads to **Supabase Storage** (durable) and returns the public object URL. Otherwise it falls back to the local `uploads/` dir — which is **NOT durable on Render's free tier** (wiped on every redeploy / idle spin-down). Configure Supabase Storage in production. See `docs/HOSTING_AND_DATA_SAFETY_RECOMMENDATION.md`.

---

## Reimbursements

Members claim money back for services paid out-of-pocket (see `docs/REIMBURSEMENT_FEATURE_PLAN.md`). Tables: `reimbursements` + append-only `reimbursement_events`. Per-plan/category ceiling lives in `plan_services.reimbursement_cap_centavos`.

**Invariants — don't break these:**
- **All money is integer centavos** (`claimed_amount_centavos`, `approved_amount_centavos`, `reimbursement_cap_centavos`). Never float, never whole-peso. Format to ₱ at the UI edge only. (Contrast: `Payment.amount_php` is legacy whole-peso — do not copy that for receipts.)
- Status lifecycle: `pending → under_review → approved → paid`, plus `rejected`, plus `needs_info` (member resubmits to the same claim → `under_review`). `paid` is terminal; never modify a paid claim.
- Every status transition appends a `ReimbursementEvent` (audit trail) — like `ServiceLog`, never edit/delete.
- Approval enforces the remaining cap inside a `with_for_update()` lock (`reimbursement_utils.category_usage(..., lock=True)`) — keep the lock to prevent concurrent overspend.
- Status emails are best-effort via `reimbursement_utils.notify_status` (never raises). Admin review is web-admin only (`require_admin`).

---

## Adding New Features — Patterns to Follow

### New endpoint
1. Add Pydantic schemas to `schemas.py` (request + response).
2. Add the route to the appropriate router in `routers/`. Use the correct auth dependency.
3. Register the router in `main.py` only if it's a new router file.
4. Never put business logic in `main.py`.

### New database table
1. Add the ORM model to `models.py`. Follow the `gen_uuid` primary key pattern.
2. `models.Base.metadata.create_all(bind=engine)` in `main.py` auto-creates the table on next startup — no migration file needed for new tables.
3. If modifying an existing table, use Alembic (`alembic` is already in `requirements.txt` but not yet initialized). Do not rely on `create_all` to alter existing columns.

### New service type (business domain)
Add it via the admin API (`POST /admin/service-types`) or in `seed.py`. Do not hardcode service type names in application logic.

---

## Payments (PayMongo Checkout Sessions)

Subscription payments use PayMongo's **hosted Checkout Session API** (`POST /v1/checkout_sessions`) — the branded "Open in GCash / scan this QR" page. The deprecated Sources API is no longer used.

**Flow:**
1. `POST /payments/checkout` (member) creates a pending `Payment`, then a Checkout Session. The session id (`cs_...`) is stored in `Payment.provider_source_id` and the hosted-page URL in `Payment.checkout_url`.
2. The app opens `checkout_url`. PayMongo handles GCash app handoff (mobile) or dynamic QR (web) on its own page — we don't build that UI.
3. On completion PayMongo redirects to `/payments/return/success|failed` (must be `http(s)`), which renders an HTML page that deep-links back into the app via `metropaws://payment/success|failed?payment_id=...`.
4. Checkout Sessions **charge automatically** — there is no `source.chargeable → create payment` step. The single `checkout_session.payment.paid` webhook event triggers `_grant_plan()` (activates plan via `plan_utils`, awards Paw Points via `paw_points_utils`, idempotent on `payment.id`).
5. The app polls `GET /payments/{id}` until `status == paid`.

**Invariants — don't break these:**
- The `cs_...` session id lives in `provider_source_id` (reused to avoid a schema migration). The webhook matches the paid session back to its `Payment` row by this id — never change that mapping without a migration.
- Webhook signature is verified (`paymongo.verify_webhook_signature`) before any DB write — keep it.
- `success_url`/`cancel_url` MUST be `http(s)` (PayMongo rejects custom schemes). The custom-scheme deep link happens only inside the return pages.
- The PayMongo dashboard webhook must be subscribed to **`checkout_session.payment.paid`**. To add payment methods, extend `payment_method_types` in `paymongo.create_checkout_session` (currently `["gcash"]`).
- When payments are disabled (`/settings/payments-enabled` → false), `/payments/checkout` returns 400; plans are granted in person by admins instead.

PayMongo env vars: `PAYMONGO_SECRET_KEY`, `PAYMONGO_WEBHOOK_SECRET`, `PAYMONGO_SUCCESS_REDIRECT`, `PAYMONGO_FAILURE_REDIRECT` (the last two are the `http(s)` return-page URLs).

### Payment receipts / invoices (`invoice_utils.py`)

Every paid plan payment emails the member a **branded PDF receipt**. It's generated by `invoice_utils.py` (fpdf2) using `assets/metropaws-logo.png` + the bundled Montserrat weights in `assets/fonts/`.

- **Auto path:** `_grant_plan` (`routers/payments.py`) calls `invoice_utils.notify_payment_receipt(db, payment)` **after** `db.commit()`. It's best-effort and **never raises** — a mail failure must not undo a grant. It runs exactly once per payment because every grant caller (webhook / poll / return page / profile safety-net) only reaches `_grant_plan` while the payment is still `pending`.
- **Admin view/download:** `GET /admin/payments/{payment_id}/invoice` (`require_admin`) returns the PDF via `invoice_utils.build_receipt_pdf` — `inline` by default, `?download=true` forces a save. Website Payments page has a per-row **"View"** button that opens `/api/admin/payments/[id]/invoice` (same-origin Next route that forwards the httpOnly `admin_token` as a Bearer) in a new tab.
- **Admin resend (email):** `POST /admin/payments/{payment_id}/resend-invoice` (`require_admin`) calls `invoice_utils.generate_and_send` which **raises** on failure, so a bad SMTP config / missing member email surfaces to the operator (400/502). Website has a secondary per-row mail-icon button (server action) for this.
- **Receipt number** is deterministic — `MP-<year>-<first 8 of payment id>` — so a resend reproduces the same number (NOT a sequential BIR OR series).
- **Payment method:** shown as the SINGLE method the member actually used (QR Ph / GCash / …), fetched live from PayMongo via `paymongo.get_paid_payment_method(provider_source_id)` and mapped by `_METHOD_LABELS`. The gateway name is deliberately omitted (the reference no. already ties it to PayMongo). Falls back to "Online payment" if the lookup fails — never guesses a wallet, and never lists both offered methods (`payment_method_types` is `["gcash","qrph"]`, so hardcoding was wrong). Trade-off: one PayMongo GET per receipt render; acceptable for occasional admin views. If that becomes hot, capture the method onto the `Payment` row at grant time instead (needs a `migrate.py` column).
- **Currency:** the PDF prints `PHP 1,500.00` (ISO code), NOT the ₱ glyph — the bundled Montserrat weights don't include U+20B1 (verified) and a formal doc must never risk a tofu box. Email HTML bodies still use ₱. `Payment.amount_php` is whole pesos — do not run it through the centavos `_peso` helpers.
- **Business/tax identity is env-configurable** (`INVOICE_*`, see below); TIN / registration lines only render when their var is set — nothing is fabricated. `INVOICE_DOC_TITLE` defaults to "PAYMENT RECEIPT"; only set it to "OFFICIAL RECEIPT" once a BIR-accredited OR series is actually in place.
- **Deploy note:** `fpdf2` is a new dependency — a fresh image build (`.\deploy.ps1`) is required, not just a code push. The `assets/` folder is copied into the image by the Dockerfile's `COPY . .` (only `uploads/` is dockerignored). **The `INVOICE_*` env vars must be listed in `deploy.ps1`'s `$renderEnvKeys` allowlist** or they are silently dropped when the script full-replaces Render's env vars (this is exactly why an early receipt showed the fallback `SMTP_USER` email instead of `INVOICE_BUSINESS_EMAIL` — the vars were in `.env.*` but not the allowlist). Any NEW env var added anywhere must also be added to that allowlist.

---

## Environment Variables

All config is loaded from `.env` via `python-dotenv`. Never hardcode values.

| Variable | Required | Default | Notes |
|---|---|---|---|
| `DATABASE_URL` | Yes | — | Full PostgreSQL connection string |
| `SECRET_KEY` | Yes | `"fallback-secret-key"` | Must be changed in production |
| `ALGORITHM` | No | `HS256` | JWT signing algorithm |
| `ACCESS_TOKEN_EXPIRE_MINUTES` | No | `10080` | 7 days |
| `UPLOAD_DIR` | No | `uploads` | Relative path; must be volume-mounted in Docker |
| `BASE_URL` | No | `http://localhost:8000` | Used to build file URLs returned to clients |
| `FRONTEND_URL` | No | `http://localhost:3000` | Used to construct password reset links in emails |
| `MAX_FILE_BYTES` | No | `5242880` (pets) / `8388608` (storage.py) | Upload limit. Set to `8388608` (8 MB) for receipts. |
| `SUPABASE_URL` | Yes (for durable uploads) | — | Supabase project URL; enables Supabase Storage in `storage.py` |
| `SUPABASE_SERVICE_KEY` | Yes (for durable uploads) | — | Supabase service-role key (server-side only — never ship to client) |
| `SUPABASE_BUCKET` | No | `uploads` | Storage bucket name (must be created + public) |
| `REIMBURSEMENT_MAX_CLAIM_PHP` | No | `20000` | Per-claim ceiling in pesos (compared in centavos) |
| `REIMBURSEMENT_MAX_PER_DAY` | No | `20` | Max claims a member can submit per rolling 24h (anti-spam) |
| `REIMBURSEMENT_ENFORCE_DUAL_CONTROL` | No | `false` | When `true`, the admin who approved a claim can't also mark it paid (needs ≥2 admins) |
| `ZEPTOMAIL_TOKEN` | Yes (prod email) | — | ZeptoMail "Send Mail Token". When set, ALL email goes via ZeptoMail's HTTPS API — required in prod because Render's free tier blocks outbound SMTP ports (25/465/587). Accepted with or without the `Zoho-enczapikey ` prefix. |
| `ZEPTOMAIL_API_URL` | No | `https://api.zeptomail.com/v1.1/email` | Override for non-.com ZeptoMail data centers |
| `SMTP_HOST` | Yes (dev email) | — | SMTP fallback used only when `ZEPTOMAIL_TOKEN` is unset (local dev) |
| `SMTP_PORT` | Yes (dev email) | — | |
| `SMTP_USER` | Yes (dev email) | — | Also the default sender address when `EMAIL_FROM` is unset |
| `SMTP_PASSWORD` | Yes (dev email) | — | Zoho app password |
| `EMAIL_FROM` | No | `SMTP_USER` | Sender address (must be on the ZeptoMail-verified domain in prod) |
| `EMAIL_FROM_NAME` | No | `MetroPaws` | Display name in reset + receipt emails |
| `INVOICE_BUSINESS_NAME` | No | `MetroPaws Wellness Club Philippines, Inc.` | Seller name on the receipt PDF |
| `INVOICE_BUSINESS_ADDRESS` | No | — | Registered business address (blank = hidden). Use `\|` to split into separate lines, e.g. `street \| city + ZIP`. Member/business phones auto-format to `+63 9XX XXX XXXX`. |
| `INVOICE_BUSINESS_TIN` | No | — | Tax Identification No. (blank = hidden) |
| `INVOICE_BUSINESS_EMAIL` | No | `EMAIL_FROM`/`SMTP_USER` | Billing contact email on the PDF |
| `INVOICE_BUSINESS_PHONE` | No | — | Contact phone on the PDF (blank = hidden) |
| `INVOICE_BUSINESS_WEBSITE` | No | `metropaws.ph` | Website line on the PDF |
| `INVOICE_BUSINESS_REG_LINE` | No | — | Footer registration line, e.g. `SEC Reg. No. … · BIR Permit No. …` (blank = hidden) |
| `INVOICE_DOC_TITLE` | No | `PAYMENT RECEIPT` | Document heading. Use `OFFICIAL RECEIPT` only with a real BIR OR series |
| `INVOICE_VAT_PERCENT` | No | `0` | `0` hides tax lines; e.g. `12` shows a VAT-inclusive breakdown (net + VAT) |

`.env` is excluded from Docker images via `.dockerignore`. Pass secrets at runtime via `--env-file .env` or Cloud Run secret manager.

---

## Docker & Deployment

```powershell
# Build and push to marioogarbo/metropaws-backend on Docker Hub
.\deploy.ps1

# Run locally with secrets and persistent uploads
docker run -p 8000:8000 --env-file .env -v ${PWD}/uploads:/app/uploads marioogarbo/metropaws-backend:latest
```

The image targets `linux/amd64`. The app runs as a non-root `app` user inside the container.

---

## What Not to Do

- **Do not add Alembic auto-migrate on startup.** `create_all` is intentional — it only creates missing tables, it never drops or alters. Use explicit migrations for schema changes.
- **Do not store secrets in the image.** `.env` is gitignored and dockerignored for a reason.
- **Do not change `MemberService.total_sessions` to log a service.** Only `used_sessions` is incremented.
- **Do not bypass `require_admin` on admin routes.** All `/admin/*` routes must stay behind this guard.
- **Do not trust the client's reported MIME type for file saves.** The current code re-derives the extension from the validated MIME — keep it that way.
- **Do not return 404 from `/auth/forgot-password`.** The security-safe 200 response is intentional.
