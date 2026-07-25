# MetroPaws — Client Demo Run-of-Show

A scripted, dual-device (phone + browser) walkthrough of the platform mapped to
the 14-step business workflow. Built for the **staging / dev** environment so
uploaded files persist and production stays untouched.

---

## Environment (all on DEV)

| Layer | Target |
| ----- | ------ |
| Website (admin + marketing) | `https://staging-metropaws.vercel.app` |
| Backend API | `https://metropaws-backend-dev.onrender.com` |
| Mobile app | build/run with `flutter run --dart-define=ENV=dev` |
| Database / file storage | Supabase (dev) — durable, receipts/photos persist |

## Pre-demo checklist (do ~15 min before)

- [ ] **Warm the backend**: open the site / hit the API once so Render's free
      tier isn't cold (first request after idle takes 30–60s).
- [ ] **Confirm the admin login** works with real dev credentials (not the
      literal word "admin" — use the seeded admin email + password).
- [ ] **Decide the payment mode** in Admin → Settings → "Require Payment to
      Activate Membership":
  - **ON** → demo the real GCash test checkout (step 7).
  - **OFF** → selecting a plan activates instantly (frictionless; use if GCash
      test is flaky on the day).
- [ ] **Optional: pre-seed data** so the dashboard isn't all zeros at the start,
      or run the happy path once beforehand.
- [ ] Have the phone (app on `ENV=dev`) and a browser tab on the admin site
      ready side by side.

---

## Run-of-show

### Act 1 — Acquisition (steps 1–2)  · Browser

1. **Customer Inquiry** — On the marketing site, submit the Founding 50
   reservation form.
2. **Qualification** — In the admin portal (Reservations), approve the
   reservation with a note.

### Act 2 — Onboarding (steps 3–6)  · Phone

3. **Registration** — Create an account.
6. **Digital Agreement** — Tick the required "Membership Agreement + Privacy
   Policy" checkbox (registration is blocked until accepted; acceptance is
   recorded server-side with a timestamp + version).
4. **Pet Registration** — Add a pet with photo and vaccination card.
5. **Plan Selection** — Choose a tier (Standard / Deluxe / Premium).

### Act 3 — Activation & Payment (steps 7–8)  · Phone

7. **Payment** — Pay via GCash (PayMongo **test** mode — no real money). If the
   payment toggle is OFF, this step is skipped and the plan activates on
   selection.
8. **Activation** — Show the activated **Digital Pawprint** QR membership card.

### Act 4 — Benefits & Claims (steps 9–12)  · Phone + Browser

9. **Benefit Availment** — On the phone, submit a reimbursement claim with a
   receipt.
10. **Validation** — In the browser (Admin → Reimbursements), open the claim,
    preview the receipt, and approve it (with an adjusted amount if you like).
    Fraud controls in place: duplicate detection, receipt-hash reuse, per-day
    caps, cap-vs-remaining.
11. **Reimbursement Posting** — "Mark as paid" with a payment reference; the
    ledger records the event.
12. **Utilization Update** — Back on the phone, show the benefit wallet balance
    reflecting the activity.

### Act 5 — Management view (step 14)  · Browser

14. **Dashboard Review** — Admin dashboard now shows live business KPIs:
    Revenue Collected, Active Memberships, Claims Paid Out, Benefit Utilization,
    plan mix, and claims-by-status. Narrate: "these updated as we ran the flow."

---

## What to frame as roadmap (not built)

- **Step 13 — Renewal reminders (60/30/15/7 days):** the in-app notification
  system that delivers alerts is live; the automated scheduling triggers are the
  remaining piece. Say so plainly rather than clicking into it.
- **Staff roles:** today there is a single `admin` login that covers claims
  review, finance posting, and KPIs. Distinct Claims Officer / Finance / CEO
  roles are future work.

## Don't click during the demo

- The **mobile admin "Activity" tab** — it's a placeholder empty state.

---

## Honest one-liner if asked "is this production-ready?"

> "The member app and the claims back-office are built and working. Agreement
> capture and the management dashboard are new. Automated renewal reminders,
> staff-role separation, and non-GCash payment methods are the remaining scoped
> work. This is a staging build for the walkthrough, not the production release."
