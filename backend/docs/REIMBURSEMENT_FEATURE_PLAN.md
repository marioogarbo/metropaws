# Reimbursement Feature — Implementation Plan (v1 "Honest Wallet")

> **Status:** Approved spec, pre-implementation. No code written yet.
> **Last updated:** 2026-06-27 (rev 2 — added production-readiness section; money → centavos; files → object storage)
> **Scope:** Spans 3 projects — `backend` (FastAPI), `mobile` (Flutter), `website` (Next.js admin).
> This file is kept identical in `mobile/docs/`, `backend/docs/`, and `website/docs/` for cross-team reference.

---

## 1. Concept

A member pays out-of-pocket for a covered service at **any** provider (grooming, consultation, vaccine, lab, emergency), photographs/uploads the official receipt, and submits a **reimbursement claim** against their plan benefit. An admin reviews it on the **website**, sets the reimbursed peso amount within the plan's cap, and the member is paid **offline** (bank/GCash/cash). The app is the **system of record** for the claim and its lifecycle — it never moves money.

This is the third way to use a benefit, alongside the two that already exist:

| Way to use a benefit | Mechanism | Status |
| --- | --- | --- |
| At a partner clinic (QR scan) | admin `deploy-service` → `used_sessions += 1` | exists |
| At a partner clinic (booked) | booking flow | exists |
| **Out-of-pocket elsewhere** | **upload receipt → admin approves peso amount → paid offline** | **this feature** |

### Why "Honest Wallet" and not the manual's full model
The member manual (Rev 0, §6–8) promises a peso **Benefit Wallet** with **percentage cashback** ("10% of PHP 500 = PHP 50"). The codebase has **no peso values, no percentage, no wallet** — benefits are pure **session counts** (`PlanService.sessions`). The manual itself hedges every rule with *"depending on plan, provider, and current program rules"* — i.e., rules aren't finalized. So v1 builds a **real peso wallet** (the manual's 5 line-items) but the reimbursed amount per claim is **set by the admin within a per-plan cap** — no automatic percentage engine. Percentage automation can come later once the business fixes the rules.

> A retracted earlier idea: "consume one session on approval." Rejected because it gives no money back and contradicts what "reimbursement" promises members.

---

## 2. Locked decisions

| Decision | Choice |
| --- | --- |
| Benefit model | Honest peso wallet; admin sets reimbursed amount within a per-plan cap (no % engine in v1) |
| Statuses | `pending → under_review → approved → paid`, plus `rejected`, plus `needs_info` |
| Payout | Offline (bank/GCash/cash); app is system-of-record only; "Paid" set by admin after transfer |
| Eligibility | Any member with an **active plan + registered pet**; caps differ **per plan × category** |
| Money representation | **Integer centavos everywhere** (₱523.75 → `52375`). Never float, never whole-peso. |
| File types | **Images + PDF**, max **8 MB** (configurable), images compressed on device |
| File storage | **Object storage** (Supabase Storage), public bucket + UUID path. NOT the local `uploads/` dir (ephemeral — see §11). |
| Notifications | In-app status + **status-change email** (existing SMTP); push **deferred** to a later project |
| Unclear receipt | **"Needs Info" resubmit loop** — member re-uploads to the same claim |
| Admin review UI | **Website admin only** (clone the Founding Reservations approval page) |

### Out of scope for v1
Percentage-rate cashback engine · push notifications (FCM) · in-app notification center / bell · free-form admin↔member chat · automated payouts.

---

## 3. Status lifecycle

```
            ┌─────────── needs_info ◄──────────┐
            │  (admin requests clearer receipt) │
            ▼                                   │ (member re-uploads to SAME claim)
  submit → pending → under_review ──────────────┘
                          │
                          ├──► approved ──► paid     (admin sets approved amount; finance releases offline)
                          │
                          └──► rejected             (with reason)
```

- **pending** — submitted, awaiting review.
- **under_review** — admin is checking it.
- **needs_info** — admin requested a clearer/complete receipt (with a note). Member re-uploads to the **same** claim → it returns to `under_review`. `receipt_url` is overwritten; full history kept in the events table (§4).
- **approved** — eligible; admin has set `approved_amount_centavos` (≤ remaining cap).
- **rejected** — not eligible/incomplete, with a reason.
- **paid** — offline reimbursement released; stamped with payer + time.

Every status change emails the member, **including the admin note**, so "receipt blurry, please resubmit" reaches their inbox automatically. The note is also visible in-app on the claim. Every transition is also written to an append-only events table (§4, item 3).

---

## 4. Backend (FastAPI) — Phase 1

### Data model (`models.py`)
- **`ReimbursementStatus`** enum: `pending, under_review, needs_info, approved, rejected, paid`.
- **`Reimbursement`** table (new table → auto-created by `create_all`, **no migration needed**):
  - `id, member_id, pet_id` (required — manual: claim must link to a registered pet)
  - `service_type_id, provider_name, service_date`
  - `claimed_amount_centavos` (Integer), `approved_amount_centavos` (Integer, nullable)
  - `receipt_url, receipt_reference` (nullable), `member_notes` (nullable)
  - `status, admin_notes` (nullable)
  - `reviewed_by_admin_id, reviewed_at, paid_by_admin_id, paid_at, created_at, updated_at`
- **`ReimbursementEvent`** table (new — append-only audit trail; see §11 item 3):
  - `id, reimbursement_id, from_status, to_status, actor_user_id, note, created_at`
- **`PlanService.reimbursement_cap_centavos`** — new Integer column (default 0), per plan × category.
  - ⚠️ New **column** on an existing table is **NOT** handled by `create_all`. Add an idempotent `ALTER TABLE plan_services ADD COLUMN IF NOT EXISTS reimbursement_cap_centavos INTEGER DEFAULT 0;` to **`migrate.py`** (the project's established migration pattern — NOT the ad-hoc Supabase SQL editor). New **tables** are created by `create_all`/`migrate.py`'s `create_all` call.

### Schemas (`schemas.py`)
`ReimbursementCreate` (multipart form) · `ReimbursementOut` · `AdminReimbursementOut` (nested member/pet/service) · `ReimbursementReviewRequest` (`{status, approved_amount_centavos?, admin_notes?}`) · `MarkPaidRequest` · `WalletCategoryOut` · `WalletOut`. All money fields are integer **centavos**; the API may also expose a derived `*_php` display string, but the source of truth is centavos.

### Endpoints
**Member** (`require_member`, active-plan check) — new `routers/reimbursements.py`:
- `POST /members/me/reimbursements` (multipart) — validates pet ownership, active plan, category, amount ≤ per-claim ceiling (`REIMBURSEMENT_MAX_CLAIM_PHP` env, pesos for readability, compared in centavos), soft duplicate check on `(member, provider, service_date, claimed_amount_centavos)`. Uploads receipt to **object storage**; stores returned URL. **Also handles re-upload** to a `needs_info` claim (overwrite `receipt_url`, status → `under_review`, log event). Accepts an **idempotency key** header to dedupe retries (§11 item 8).
- `GET /members/me/reimbursements` — own claims + statuses.
- `GET /members/me/wallet` — per (pet × category): **Available** = plan cap, **Pending** = Σ claimed of pending claims, **Used** = Σ approved+paid, **Remaining** = cap − used, **Utilization** = claim history. Period = pet's `plan_activated_at` + 365d. All centavos.

**Admin** (`require_admin`) — extend `routers/admin.py`:
- `GET /admin/reimbursements?status=&member_id=` — review queue with eager joins.
- `PUT /admin/reimbursements/{id}/review` — set `under_review`/`needs_info`/`approved`/`rejected`; on approve, `approved_amount_centavos` required and capped at remaining. **Runs inside a DB transaction with a row lock on the cap computation** (§11 item 4). Stamps reviewer + time; writes a `ReimbursementEvent`; fires email.
- `PUT /admin/reimbursements/{id}/mark-paid` — sets `paid`, stamps payer + time; writes event; fires email.

### Email (`email_utils.py`)
Add `send_claim_status_email(...)`, wrapped in try/except like `send_reset_email` so a mail failure never breaks the API. Includes the admin note when present.

### Wiring
- Register the new router in `main.py`.
- Add the `plan_services` `ADD COLUMN IF NOT EXISTS` to `migrate.py`.

### File handling
- Accept **JPEG / PNG / PDF**; `MAX_FILE_BYTES` → **8 MB** (configurable env); UUID object keys.
- Upload to **Supabase Storage** (durable); store the returned public URL on the claim. Do **not** write receipts to the local `uploads/` dir (it does not survive redeploys/spin-downs — §11 item 2).

---

## 5. Mobile (Flutter) — Phase 2 (parallel with Phase 3)

- **New dependency (approved):** `file_picker` for PDF selection, alongside existing `image_picker` for photo capture. (Adding a dependency is normally a Hard Stop — client gave explicit OK.)
- `core/models/reimbursement.dart`, `core/models/wallet.dart` (money fields as int centavos; format to ₱ in the UI layer only).
- `core/constants/api_constants.dart` + `core/services/api_service.dart`: `submitReimbursement()` (multipart, mirrors `uploadVaxCard`), `getMyReimbursements()`, `getWallet()`.
- Extend **`MemberBloc`** (no new BLoC, per CLAUDE.md): events `ReimbursementSubmitted`, `ReimbursementsLoadRequested`, `WalletLoadRequested` (+ resubmit); matching states.
- One screen with tabs (mirrors `paw_points_screen.dart`):
  - **Wallet** — the manual's 5 line-items per category.
  - **My Claims** — status badges (incl. `needs_info`), admin notes, and a **Resubmit** action when `needs_info`.
  - **Submit** — "Take/choose photo" or "Choose PDF", category dropdown, pet picker, amount, provider, service date. Includes the `_submitting` double-submit guard.
- Entry point on the Account tab + a status-change indicator dot.
- All design tokens via `Theme.of(context)`; `SafeArea` + scrollable form per guardrails.

---

## 6. Website admin (Next.js) — Phase 3 (parallel with Phase 2)

- `app/admin/(protected)/reimbursements/page.tsx` + `actions.ts` — clone the **Founding Reservations** pattern (filter tabs with counts, status badges, expandable rows).
- `components/admin/reimbursements-table.tsx` — inline receipt preview (image / PDF in iframe), member + pet + category + amount + provider + date + remaining-cap context, and actions: **Approve** (set amount), **Reject**, **Request Info** (needs_info + note), **Mark Paid**. Admin-notes textarea. Amount inputs entered in pesos, sent as centavos.
- `components/admin/admin-sidebar.tsx` — add a "Reimbursements" link to `NAV_LINKS`.
- Server actions mirror `updateReservationStatusAction` (PUT + `admin_notes`).
- (Optional follow-up) cap-editing field on the Plans editor.

---

## 7. Security

- **Payment security: N/A** — no card/bank data touches the app or backend; members pay providers externally. Only a receipt file + claim metadata are stored.
- **Data/form security:** HTTPS (prod); JWT auth + strict **ownership checks** (members see/submit only their own claims; admins via `require_admin`); server-side validation of amount/date/category/pet-ownership; hardened file upload (MIME allowlist + size cap + UUID keys); **no-duplicate-claim** enforcement; **append-only audit trail** of every status transition (§4, §11 item 3); optional submission rate-limiting.
- **Receipt URLs:** stored in a public Supabase Storage bucket with an unguessable UUID path (matches the earlier "public UUID URL" decision, now durable). If the business later treats receipts as strictly confidential, switch the bucket to private + **signed URLs** — a small change isolated to the storage helper.

---

## 8. Build order

1. **Phase 1 — Backend** (defines the API contract everything depends on). Add the `plan_services` column to `migrate.py` and run it against dev.
2. **Phase 2 (mobile) + Phase 3 (website)** in parallel — both depend only on Phase 1.
3. **Phase 4 — Verify & document:** end-to-end test submit → review → needs_info → resubmit → approve → mark-paid, with emails + wallet math + events. Update both `CLAUDE.md` files with new endpoints/screens.

---

## 9. Remaining inputs (not decisions — just values)

1. **Cap numbers** — per-plan × category reimbursement caps (Standard / Deluxe / Premium) + the per-claim ceiling (`REIMBURSEMENT_MAX_CLAIM_PHP`). May be scaffolded with placeholders and filled later.
2. **"Active membership" definition** — default enforced rule: *pet has an activated, non-expired plan*. Confirm or override.
3. **Object storage target** — default **Supabase Storage** (project already on Supabase). Confirm, or name an alternative (Cloudflare R2 / S3).

---

## 10. Reference: existing patterns reused

- **Backend file upload:** `_validate_and_save_file()` in `routers/pets.py` (vax-card flow) — to be refactored to write to object storage.
- **Backend approval workflow:** Founding Reservations (`pending/approved/rejected` + `admin_notes`).
- **Backend email:** `email_utils.send_reset_email` (SMTP via Gmail; `SMTP_*` env vars).
- **Backend migrations:** idempotent raw SQL in `migrate.py` (`ADD COLUMN IF NOT EXISTS`) + `create_all`.
- **Mobile upload:** `ApiService.createPet` / `uploadVaxCard` (multipart), `paw_points_screen.dart` (tabbed list UI).
- **Website approval UI:** `app/admin/(protected)/reservations/` + `components/admin/reservations-table.tsx`.

---

## 11. Production-readiness & best practices

Because this feature handles **money and financial documents**, the bar is higher than ordinary CRUD. Items are prioritized; P0/P1 are baked into the plan above, P2 are tracked follow-ups.

1. **[P0] Money precision — integer centavos.** Store all amounts as integer centavos (`claimed_amount_centavos`, `approved_amount_centavos`, `reimbursement_cap_centavos`). Never float; never whole-peso. (The existing `Payment.amount_php` whole-peso convention is fine for round plan prices but wrong for receipts that carry centavos.) Format to ₱ only at the UI edge.

2. **[P0] File durability — object storage, not local disk.** **Live finding:** the backend runs on **Render's free plan with no persistent disk**; free services spin down after ~15 min idle and on every redeploy, wiping the container's writable layer. So the current local `uploads/` dir is **ephemeral — pet photos and vax cards are already being lost in production.** Receipts are financial records and must be durable. Move uploads to **Supabase Storage** (project already on Supabase; S3-compatible; public or signed URLs). This also retroactively fixes the existing photo/vax-card loss. (Backfilling already-lost files is not possible; only future uploads are protected.)

3. **[P1] Immutable audit trail.** Add the append-only `ReimbursementEvent` table (§4) recording every status transition: who, when, from→to, note. Storing only the latest reviewer fields on the row loses history — unacceptable for claims/disputes.

4. **[P1] Concurrency on the cap.** Two claims approved simultaneously could both pass the "remaining cap" check and overspend. Compute remaining and write the approval inside one DB transaction with a **row lock** (`SELECT … FOR UPDATE`) on the relevant `plan_service`/claims rows.

5. **[P1] Migrations.** Use the project's existing **`migrate.py`** idempotent-SQL pattern for the new column; new tables come via `create_all`. (Adopting **Alembic** properly — it's a dependency but currently unwired — is a recommended *separate* infra upgrade, not part of this feature.)

6. **[P2] Data privacy (PH Data Privacy Act).** Receipts are personal/financial data. Define a **retention policy** (how long claims/receipts are kept), restrict access to owner + admins, and log admin access. Note in the privacy policy that receipts are collected for claims processing.

7. **[P2] Automated tests.** Unit-test the **money math** (cap/remaining/wallet aggregation) and the **status state-machine** (legal transitions only; e.g. can't pay a rejected claim). Integration-test the submit→review→pay happy path.

8. **[P2] Idempotency.** Accept an idempotency key on `POST` submit so a retried network request doesn't create duplicate claims (stronger than the client-side `_submitting` guard alone).

9. **[P2] Upload malware scanning.** Consider scanning uploaded files (or at least re-validating content-type server-side beyond the header). Acceptable to defer for v1.
