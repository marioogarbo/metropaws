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
| `app/main.py` | App factory, middleware, static file mount, router registration, DB table creation on startup |
| `app/config.py` | **Environment selection + settings access.** `APP_ENV` (`dev` default / `prod`) picks `.env.dev` or `.env.prod`; `.env.local` overrides both; real environment variables beat every file, which is how Docker and Render are configured. Import it before any other project module and read settings through `require` / `env` / `env_int` / `env_bool` — several modules read config at import time, so the import order is what guarantees correctness. |
| `app/database.py` | SQLAlchemy engine + `SessionLocal` + `get_db` dependency |
| `app/models.py` | All ORM table definitions — single source of truth for the DB schema |
| `app/schemas/` | **All Pydantic request/response models — single source of truth for API contracts.** One module per subject (`auth`, `services`, `pets`, `members`, `plans`, `bookings`, `clinics`, `providers`, `payments`, `reimbursements`, `paw_points`, `content`, `directory`, `reservations`, `settings`, `notifications`, plus shared `validators`). `__init__.py` re-exports every name, so `import schemas` / `schemas.PetOut` works unchanged. Imports are layered one way — `validators → services → pets, plans → members → bookings → clinics`, and `providers → reimbursements`; if two modules need each other, the shared shape belongs in the lower one. |
| `app/auth.py` | JWT encode/decode, password hashing, and the three FastAPI dependency guards: `get_current_user`, `require_admin`, `require_member` |
| `app/email_utils/` | **Outbound email**, one module per concern: `transport` (delivery), `layout` (shared chrome), then one template each — `password_reset`, `claims`, `receipts` (**`send_payment_receipt_email`, PDF attached**), `app_launch` (**`build_app_launch_email` / `send_app_launch_email`**). `__init__.py` re-exports the public senders, so `import email_utils` is unchanged. Keeps the name `email_utils` deliberately — a package called `email` would shadow the stdlib module the transport imports `MIMEText` from. Sends via the **ZeptoMail HTTP API** when `ZEPTOMAIL_TOKEN` is set (**required in prod** — Render's free tier blocks outbound SMTP ports 25/465/587); falls back to plain SMTP for local dev. `layout._branded_shell()` is the shared logo header + card + footer chrome — build new templates on it. `claims` and `receipts` predate it and still inline their own copies, so a styling change currently has to be made three times. |
| `app/invoice_utils/` | **Payment receipt PDF generation + send** (fpdf2, branded), split by concern: `business` (env-configurable seller identity), `formatting` (peso/phone/date/receipt number), `render` (page geometry, palette, drawing), `delivery` (build + send). `__init__.py` re-exports the public names. `notify_payment_receipt` = best-effort/never-raises (auto path); `generate_and_send` = raises (admin resend). Asset paths are anchored on `config.BACKEND_DIR`, **not** `__file__` — a relative-to-here path broke every render when this became a package. |
| `app/storage.py` | **Canonical file-upload helper (`save_upload`)** — writes to Supabase Storage when configured, else local disk. Use this for new uploads. |
| `app/domain/` | **Business rules, independent of HTTP** — `plan_utils` (granting benefits), `plan_term_utils`, `pricing_utils`, `reimbursement_utils`, `paw_points_utils`, `directory_taxonomy`. Nothing here imports a router or touches a request; routers translate HTTP into calls on these. Called `domain` and **not** `services` on purpose: in this product a "service" is a vet or grooming visit (`ServiceType`), and `app/routers/admin/services.py` already means that — two senses of the word in one tree would be worse than a slightly formal package name. |
| `app/domain/reimbursement_utils.py` | Shared reimbursement math (per-plan cap, category usage/remaining) + best-effort status email |
| `app/domain/pricing_utils.py` | Plan pricing rules — the multi-pet **Pack Discount** (`pack_discount_quote`). The ONLY place plan prices are adjusted; checkout and `GET /payments/quotes` both call it. |
| `app/domain/plan_term_utils.py` | Plan term math + **upgrade/renewal eligibility** (`plan_status`, `purchase_eligibility`, `benefits_untouched`). The ONLY place those rules live; checkout, activate-plan, quotes, wallet, and the claim expiry gate all call it. |
| `scripts/seed.py` | **Reference data for a fresh database**, one named function per subject in `SEEDERS` order: service types, plans, plan services, app settings, admin user, PawPoints rewards, sample clinics (only with `SEED_CLINIC_PASSWORD`), FAQs. Every step is idempotent — it inserts only what is missing — so re-running tops a database up after a new default is added, and never overwrites an admin's edit. Nothing runs on import; `python -m scripts.seed`, minding `APP_ENV`. Not part of the app lifecycle |
| `scripts/migrate.py` | **Idempotent schema migrations, one named function per step, run in `MIGRATIONS` order.** Nothing executes on import — run `python -m scripts.migrate` explicitly, and mind which DB `APP_ENV` resolves to. Add a step as a new function *and* register it in `MIGRATIONS`; `tests/test_migrate.py` fails if you forget, or if the module regains an import-time side effect. `deploy.ps1` does **not** run it |
| `scripts/notify_app_launch.py` | One-off CLI broadcast of the Android launch announcement to members + Founding 50 reservations. Reads the admin XLSX exports (no DB access) and picks the audience variant per person. **Deduped on `_mailbox_key` (canonical inbox, folding Gmail dots/`+tags`), not on the raw address** — a member who also reserved early is emailed once, with the members-export row winning so the copy is right. Ledger of delivered inboxes means a re-run resumes instead of double-sending; the send loop re-checks too. Same person on two *different* addresses (matched by phone) is reported for a human decision, never auto-dropped. Dry-run by default; `--send` confirms first. |
| `app/routers/auth.py` | Registration, login, `/me`, forgot/reset password |
| `app/routers/members.py` | Member profile CRUD + in-app notifications (list / unread-count / mark-read) |
| `app/routers/pets.py` | Pet CRUD + file uploads (photos, vax cards) |
| `app/routers/admin/` | **Admin API, one module per subject** — `services` (QR scan, deploy/assign, service types, logs), `members`, `plans`, `partners` (clinic partners), `providers` (direct-pay payees), `pets`, `bookings`, `analytics`, `payments` (+ invoices), `paw_points`, `reimbursements` (review/approve/mark-paid). `__init__.py` supplies the shared `/admin` prefix and includes each module — routes and OpenAPI tags are unchanged from the single 1,347-line `admin.py` this replaced. Add a new admin area as a new module here rather than growing an existing one past its subject. |
| `app/routers/reimbursements.py` | Member reimbursement claims: submit, list, resubmit, Benefit Wallet |
| `app/routers/payments.py` | PayMongo checkout, return pages, webhook, plan-grant on payment |
| `app/routers/settings.py` | App settings (payments on/off, founding-50 toggle/limit) |
| `app/paymongo.py` | PayMongo REST client — Checkout Sessions + webhook signature verification |

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

Three dependency guards in `app/auth.py` — always use the right one:

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

**All** uploads go through `save_upload()` in `app/storage.py` — pet photos, vaccination cards and reimbursement receipts. There is no second upload path; add new ones here rather than validating bytes in a router.

| Upload type | Subdir | Allowed MIME types | Max size |
|---|---|---|---|
| Pet photo | `photos/` | jpeg, png, webp | env `MAX_FILE_BYTES` |
| Vaccination card | `vax_cards/` | jpeg, png, pdf | env `MAX_FILE_BYTES` |
| Reimbursement receipt | `receipts/` | jpeg, png, pdf | env `MAX_FILE_BYTES` (8 MB default in `app/storage.py`) |

UUID filenames; extension derived from the validated MIME, never the client filename. The returned value is a full public URL saved on the row (e.g. `reimbursements.receipt_url`).

**Storage durability (important):** when `SUPABASE_URL` + `SUPABASE_SERVICE_KEY` are set, `app/storage.py` uploads to **Supabase Storage** (durable) and returns the public object URL. Otherwise it falls back to the local `uploads/` dir — which is **NOT durable on Render's free tier** (wiped on every redeploy / idle spin-down). Configure Supabase Storage in production. See `docs/HOSTING_AND_DATA_SAFETY_RECOMMENDATION.md`.

---

## Reimbursements

Members claim money back for services paid out-of-pocket (see `docs/REIMBURSEMENT_FEATURE_PLAN.md`). Tables: `reimbursements` + append-only `reimbursement_events`. The ceiling is **two per-plan wallet pools** on `plans` — `reimbursement_wallet_centavos` (Preventive Wellness) and `emergency_wallet_centavos` — chosen by service-category NAME in `reimbursement_utils.is_emergency_category`. Per-category `plan_services.reimbursement_cap_centavos` is **legacy and no longer consulted**.

**Invariants — don't break these:**
- **All money is integer centavos** (`claimed_amount_centavos`, `approved_amount_centavos`, `reimbursement_cap_centavos`). Never float, never whole-peso. Format to ₱ at the UI edge only. (Contrast: `Payment.amount_php` is legacy whole-peso — do not copy that for receipts.)
- Status lifecycle: `pending → under_review → approved → paid`, plus `rejected`, plus `needs_info` (member resubmits to the same claim → `under_review`). `paid` is terminal; never modify a paid claim.
- Every status transition appends a `ReimbursementEvent` (audit trail) — like `ServiceLog`, never edit/delete.
- Approval enforces the remaining pool inside a `with_for_update()` lock (`reimbursement_utils.wallet_usage(..., lock=True)`) — keep the lock to prevent concurrent overspend.
- **Benefit utilization is money, not sessions.** `admin/analytics.benefit_utilization` divides approved+paid claim amounts by the wallet pools granted to pets still inside their term. Do not "restore" the old `used_sessions / total_sessions` ratio: sessions are written only by the clinic QR scan and `deploy-service`, neither of which the reimbursement flow touches, so that ratio reads 0% forever.
- Status emails are best-effort via `reimbursement_utils.notify_status` (never raises). Admin review is web-admin only (`require_admin`).

---

## Adding New Features — Patterns to Follow

### New endpoint
1. Add Pydantic schemas to the matching module in `app/schemas/` (request + response), and re-export them from `app/schemas/__init__.py`.
2. Add the route to the appropriate router in `app/routers/`. Use the correct auth dependency.
3. Register the router in `app/main.py` only if it's a new router file.
4. Never put business logic in `app/main.py`.

### New database table
1. Add the ORM model to `app/models.py`. Follow the `gen_uuid` primary key pattern.
2. `models.Base.metadata.create_all(bind=engine)` in `app/main.py` auto-creates the table on next startup — no migration file needed for new tables.
3. If modifying an existing table, add a step to `scripts/migrate.py` — a named function using `ADD COLUMN IF NOT EXISTS` (or a guarded `DO $$`), registered in `MIGRATIONS`. Do not rely on `create_all` to alter existing columns. Run it against dev **and** prod before the deploy that needs the column. (`alembic` is in `requirements.txt` but has never been initialized.)

### New service type (business domain)
Add it via the admin API (`POST /admin/service-types`) or in `scripts/seed.py`. Do not hardcode service type names in application logic.

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
- The PayMongo dashboard webhook must be subscribed to **`checkout_session.payment.paid`**. To add payment methods, extend `payment_method_types` in `paymongo.create_checkout_session` (currently `["card", "gcash", "qrph"]`) — but the method must also be activated/approved in the PayMongo dashboard or it stays hidden.
- When payments are disabled (`/settings/payments-enabled` → false), `/payments/checkout` returns 400; plans are granted in person by admins instead.
- **Upgrade / renewal rules (2026-07-27/28, client decision — `app/domain/plan_term_utils.py`):** A pet's plan runs **365 days** from `plan_activated_at`. Mid-term, a member may buy only a **strictly higher-priced** plan for that pet, and only while this term's benefits are **completely untouched** (both wallet pools at zero used AND zero pending — rejected claims don't count — and zero `used_sessions`); same/lower plans 409 until the **renewal window** (`RENEWAL_WINDOW_DAYS`, default 30, before expiry) or after expiry, when ANY plan may be bought with no untouched requirement. Enforced in `/payments/checkout` AND `pets.activate_plan` (payments-disabled path) via `purchase_eligibility` → 409 with `eligibility_message` (shown verbatim in-app). **Every grant REPLACES benefits** — `grant_plan_to_pet` deletes the pet's `PetService` rows and rebuilds them from the plan (+ founding bonus), fresh `expires_at`, `plan_activated_at = now` (which also resets wallets, since `wallet_usage` windows on it). No stacking/rollover, ever. **Expiry is enforced**: expired pets get 400 on new claim submission (resubmits of in-term claims stay allowed; provider-target future `service_date` may not pass the term end). `GET /payments/quotes` carries per-plan `eligible/eligibility/is_current`; `WalletPetOut` carries `plan_status/plan_expires_at` (additive JSON — old apps unaffected). Legacy pets with `plan_id` but NULL `plan_activated_at`: active, never expire, upgradeable while untouched. PawPoints: an upgrade counts as `membership_renewal` (no new activity type).
- **Pack Discount (2026-07-27, published in the website FAQ):** 15% off the annual plan for a member's 2nd and 3rd pet, only when the new plan is **strictly cheaper** than the member's best still-active pet plan (equal tier = no discount; 4th+ pet = full price; anchor plans count while `plan_activated_at` is within 365 days, legacy null counts as active). Implemented in `pricing_utils.pack_discount_quote`, applied **server-side only** at `/payments/checkout` (snapshotted to `Payment.discount_php`; `amount_php` stays the FINAL charged amount) and re-evaluated on every checkout, so a secondary pet's renewal keeps the discount only while the primary is still active. Rounding favors the member: `final = price * (100-pct) // 100` (15%: ₱2,999→₱2,549). **FIRST ACTIVATION ONLY** (client decision 2026-07-29 — it's a joining incentive for adding a pet, not a standing multi-pet rate): callers pass the `plan_term_utils` eligibility code as `purchase_code`, and only `new` (`pricing_utils._DISCOUNT_ELIGIBLE_CODES`) carries a discount — **upgrades AND renewals pay full price**. `purchase_code=None` means "no context" and keeps the discount. A renewal-time incentive, if ever wanted, must be its own rule/percent rather than widening that set. The app shows prices from `GET /payments/quotes?pet_id=` (declared BEFORE `/{payment_id}` — route order matters) and never computes them. The receipt PDF prints Subtotal − Pack Discount = Total Paid when discounted. `payments.discount_php` is added by `scripts/migrate.py` — **must be run on dev + prod DBs**. **On/off + percent are ADMIN-CONTROLLED, live, no redeploy** (2026-07-28) — `pricing_utils.pack_discount_settings(db)` reads `AppSetting` keys `pack_discount_enabled`/`pack_discount_percent` (same key/value pattern as `booking_enabled`), exposed via `GET /settings/pack-discount` (public) + `PUT /admin/settings/pack-discount` (`require_admin`, `percent` validated 0–100) on the website's Settings page ("Pricing" section). `PACK_DISCOUNT_PERCENT`/`PACK_DISCOUNT_MAX_PLAN_PETS` env vars are now only the **fresh-install fallback** before an admin has ever saved a value — `PACK_DISCOUNT_MAX_PLAN_PETS` itself stays env-only (no admin UI; not requested).

PayMongo env vars: `PAYMONGO_SECRET_KEY`, `PAYMONGO_WEBHOOK_SECRET`, `PAYMONGO_SUCCESS_REDIRECT`, `PAYMONGO_FAILURE_REDIRECT` (the last two are the `http(s)` return-page URLs).

### Payment receipts / invoices (`app/invoice_utils/`)

Every paid plan payment emails the member a **branded PDF receipt**. It's generated by `app/invoice_utils/render.py` (fpdf2) using `assets/metropaws-logo.png` + the bundled Montserrat weights in `assets/fonts/`.

- **Auto path:** `_grant_plan` (`app/routers/payments.py`) calls `invoice_utils.notify_payment_receipt(db, payment)` **after** `db.commit()`. It's best-effort and **never raises** — a mail failure must not undo a grant. It runs exactly once per payment because every grant caller (webhook / poll / return page / profile safety-net) only reaches `_grant_plan` while the payment is still `pending`.
- **Admin view/download:** `GET /admin/payments/{payment_id}/invoice` (`require_admin`) returns the PDF via `invoice_utils.build_receipt_pdf` — `inline` by default, `?download=true` forces a save. Website Payments page has a per-row **"View"** button that opens `/api/admin/payments/[id]/invoice` (same-origin Next route that forwards the httpOnly `admin_token` as a Bearer) in a new tab.
- **Admin resend (email):** `POST /admin/payments/{payment_id}/resend-invoice` (`require_admin`) calls `invoice_utils.generate_and_send` which **raises** on failure, so a bad SMTP config / missing member email surfaces to the operator (400/502). Website has a secondary per-row mail-icon button (server action) for this.
- **Receipt number** is deterministic — `MP-<year>-<first 8 of payment id>` — so a resend reproduces the same number (NOT a sequential BIR OR series).
- **Payment method:** shown as the SINGLE method the member actually used (QR Ph / GCash / …), fetched live from PayMongo via `paymongo.get_paid_payment_method(provider_source_id)` and mapped by `_METHOD_LABELS`. The gateway name is deliberately omitted (the reference no. already ties it to PayMongo). Falls back to "Online payment" if the lookup fails — never guesses a wallet, and never lists both offered methods (`payment_method_types` is `["gcash","qrph"]`, so hardcoding was wrong). Trade-off: one PayMongo GET per receipt render; acceptable for occasional admin views. If that becomes hot, capture the method onto the `Payment` row at grant time instead (needs a `scripts/migrate.py` column).
- **Currency:** the PDF prints `PHP 1,500.00` (ISO code), NOT the ₱ glyph — the bundled Montserrat weights don't include U+20B1 (verified) and a formal doc must never risk a tofu box. Email HTML bodies still use ₱. `Payment.amount_php` is whole pesos — do not run it through the centavos `_peso` helpers.
- **Business/tax identity is env-configurable** (`INVOICE_*`, see below); TIN / registration lines only render when their var is set — nothing is fabricated. `INVOICE_DOC_TITLE` defaults to "PAYMENT RECEIPT"; only set it to "OFFICIAL RECEIPT" once a BIR-accredited OR series is actually in place.
- **Deploy note:** `fpdf2` is a new dependency — a fresh image build (`.\deploy.ps1`) is required, not just a code push. The `assets/` folder is copied into the image by the Dockerfile's `COPY . .` (only `uploads/` is dockerignored). **The `INVOICE_*` env vars must be listed in `deploy.ps1`'s `$renderEnvKeys` allowlist** or they are silently dropped when the script full-replaces Render's env vars (this is exactly why an early receipt showed the fallback `SMTP_USER` email instead of `INVOICE_BUSINESS_EMAIL` — the vars were in `.env.*` but not the allowlist). Any NEW env var added anywhere must also be added to that allowlist.

---

## Environment Variables

All config goes through `app/config.py`. Never hardcode values, and never call
`load_dotenv()` or read `os.getenv` at module level in new code — use
`config.require(...)` for settings the app cannot start without and
`config.env` / `config.env_int` / `config.env_bool` for the rest.

`APP_ENV` selects the environment: unset or `dev` → `.env.dev` (DEV Supabase),
`prod` → `.env.prod` (LIVE). A bare `uvicorn app.main:app` therefore targets dev;
production takes a deliberate `APP_ENV=prod`. Every process prints its resolved
target (`[config] APP_ENV=… db=… config=…`) on startup.

**Scope `APP_ENV` to the child process, never to the shell.** Use `.\run.ps1`
(`-Env prod` for the live DB, with a typed confirmation) or
`cmd /c "set APP_ENV=prod&& <command>"`. The `$env:APP_ENV='prod'; …;
$env:APP_ENV=$null` idiom is unsafe: Ctrl+C aborts the rest of the line, so the
reset never runs and every later command in that terminal targets production.

| Variable | Required | Default | Notes |
|---|---|---|---|
| `APP_ENV` | No | `dev` | Which environment this process is. `dev` → `.env.dev`, `prod` → `.env.prod`. Set explicitly on the deployed services so their startup banner is truthful |
| `DATABASE_URL` | Yes | — | Full PostgreSQL connection string |
| `SECRET_KEY` | Yes | — | App refuses to start without it |
| `ALGORITHM` | No | `HS256` | JWT signing algorithm |
| `ACCESS_TOKEN_EXPIRE_MINUTES` | No | `10080` | 7 days |
| `UPLOAD_DIR` | No | `uploads` | Relative path; must be volume-mounted in Docker |
| `BASE_URL` | No | `http://localhost:8000` | Used to build file URLs returned to clients |
| `FRONTEND_URL` | No | `http://localhost:3000` | Used to construct password reset links in emails |
| `ALLOWED_ORIGINS` | No | — | Comma-separated browser origins allowed by CORS. Governs the **website's browser-side calls only** (admin login, password reset, founding/pricing forms) — the mobile app sends no `Origin`, so CORS never applies to it, and Next.js server actions are server-to-server. Unset (together with the regex below) allows every origin and logs `[cors] no ALLOWED_ORIGINS set` |
| `ALLOWED_ORIGIN_REGEX` | No | — | Pattern for origins whose hostname changes per deploy (Vercel previews). **Scope it to the Vercel account slug** (`…-mario-garbos-projects.vercel.app`) — a bare `*.vercel.app` would admit anyone's deployment. Set in both envs: previews reach prod too, because `website/lib/api.ts` falls back to the production API when `NEXT_PUBLIC_API_URL` is unset |
| `MAX_FILE_BYTES` | No | `5242880` (pets) / `8388608` (storage.py) | Upload limit. Set to `8388608` (8 MB) for receipts. |
| `SUPABASE_URL` | Yes (for durable uploads) | — | Supabase project URL; enables Supabase Storage in `app/storage.py` |
| `SUPABASE_SERVICE_KEY` | Yes (for durable uploads) | — | Supabase service-role key (server-side only — never ship to client) |
| `SUPABASE_BUCKET` | No | `uploads` | Storage bucket name (must be created + public) |
| `REIMBURSEMENT_MAX_CLAIM_PHP` | No | `20000` | Per-claim ceiling in pesos (compared in centavos) |
| `REIMBURSEMENT_MAX_PER_DAY` | No | `20` | Max claims a member can submit per rolling 24h (anti-spam) |
| `REIMBURSEMENT_ENFORCE_DUAL_CONTROL` | No | `false` | When `true`, the admin who approved a claim can't also mark it paid (needs ≥2 admins) |
| `PACK_DISCOUNT_PERCENT` | No | `15` | Fresh-install default for the multi-pet Pack Discount % — superseded once an admin saves a value on the Settings page (see Pack Discount above) |
| `PACK_DISCOUNT_MAX_PLAN_PETS` | No | `3` | Max pets with plans before new activations stop qualifying (3 = pets #2–#3 discounted) |
| `RENEWAL_WINDOW_DAYS` | No | `30` | Final stretch of the plan year in which any plan (same/higher/lower) may be purchased as a renewal |
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

All env files (`.env`, `.env.*`) are excluded from Docker images via `.dockerignore` — secrets must never be baked into an image that is pushed to Docker Hub. Pass them at runtime instead: `--env-file .env.dev` locally, Render env vars in deployment (`deploy.ps1` pushes them from `.env.<env>`).

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

## Production Database — Hard Rules

**Production is live.** Real members, real memberships, real payment history. A
mistake there is a customer's money and their pet's benefits, not a bad test run.

| Action | dev | prod |
|---|---|---|
| Read (SELECT) | free | **ask first, every time** |
| `scripts/seed.py` | free | **never** |
| `scripts/migrate.py` | free | only when Mario explicitly asks |
| `create_all` (a bare `import main`, `run.ps1`, `uvicorn`) | free | **never** |
| `DROP` / `TRUNCATE` / `DELETE FROM` | ask | **never** |

- **Default to dev.** `APP_ENV` unset or `dev` → `.env.dev`; `prod` → `.env.prod`.
  Read the `[config] APP_ENV=… db=… config=…` banner on every run and say which
  environment it names. Dev is `aws-1-ap-southeast-2…:6543`, prod is
  `aws-1-ap-southeast-1…:5432`.
- **An earlier approval does not carry over.** Approval to read prod for one
  question is not approval for the next one.
- `scripts/migrate.py` is **not** purely additive — `deduplicate_pet_services`
  and `deduplicate_plan_services` delete rows.
- **`deploy.ps1 -Env prod` full-replaces Render's env vars from `.env.prod`.**
  Confirm that file holds no placeholder values before deploying: a blanked
  `DATABASE_URL` would be pushed live and take the API down.

A `PreToolUse` guard in [`.claude/settings.json`](../.claude/settings.json)
enforces the "never" rows and prompts on a prod deploy. It is a safety net, not
permission to stop thinking — it matches command text, so a novel phrasing can
slip past it.

## What Not to Do

- **Do not add Alembic auto-migrate on startup.** `create_all` is intentional — it only creates missing tables, it never drops or alters. Use explicit migrations for schema changes.
- **Do not loosen the pins in `requirements.txt`.** That file is what the image installs, and the image is what production runs. It carried `>=` ranges until 2026-08-14, so every build silently resolved to whatever was newest: local had FastAPI 0.136.1 while a fresh image got 0.141.1 — a release that changed how `app.routes` is represented, which is what the tests were reading. Bump a version deliberately, run the suite, then deploy. `pyproject.toml` and `uv.lock` are kept in step.
- **Do not read `app.routes` to enumerate endpoints.** It is an internal representation and it changed shape between minor FastAPI versions, returning almost nothing without erroring. Use `tests/api_surface.py`, which derives the table from the OpenAPI schema — the published contract.
- **Do not store secrets in the image.** Every `.env*` file is gitignored and dockerignored for a reason. `.env.example` is the one committed file and holds placeholders only.
- **Do not add a plain `.env`.** Environments are explicit: `.env.dev` / `.env.prod`, selected by `APP_ENV`, with `.env.local` for personal overrides. A generic `.env` is what previously made an innocent `import main` run `create_all` against production.
- **Do not change `MemberService.total_sessions` to log a service.** Only `used_sessions` is incremented.
- **Do not bypass `require_admin` on admin routes.** All `/admin/*` routes must stay behind this guard.
- **Do not trust the client's reported MIME type for file saves.** The current code re-derives the extension from the validated MIME — keep it that way.
- **Do not return 404 from `/auth/forgot-password`.** The security-safe 200 response is intentional.
