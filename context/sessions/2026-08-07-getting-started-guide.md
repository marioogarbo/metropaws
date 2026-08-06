# 2026-08-07 — Getting Started guide, and what building it uncovered

The client (Romy) asked for edit access to "other portions of the website" so
he could reword the provider section himself, then for a "how to pay"
instruction, then widened it to "how to use the app n sana hanggang payment".
Building that guide turned up four things worth keeping.

## Payments are live. QR Ph has been working all along

Earlier notes read as though members could not pay yet. **They can.** Confirmed
against a real production checkout on 2026-08-06: a Deluxe plan at ₱5,999,
`Fees: Free`, a QR Ph block listing GCash / Maya / BPI / GoTyme / Home Credit,
and roughly a 30-minute countdown on the session.

The code said so already and was not being read carefully:
[`backend/paymongo.py`](../../backend/paymongo.py) comments that "QRPh is
active from day one". The PayMongo blocker costs us the **separate** card /
GCash / Maya / GrabPay buttons and the bank payout, not the ability to collect.

**Consequence:** there is no reason to build a manual or offline payment path,
and one was nearly specified before this was checked. `payments_enabled` is on
in production. Grant-after-payment has four layers: the
`checkout_session.payment.paid` webhook, a client poll, the return page, and
the profile-load reconcile in
[`backend/routers/payments.py`](../../backend/routers/payments.py).

## The app's plan flow is not what the code reading suggested

Choosing a plan is **not** a standalone action on an existing pet. It is the
third step of the Add a Pet wizard (Details → Health Card → Plan), followed by
an "All done / one step left" screen that leads to checkout. The first draft of
the guide described a flow that does not exist. Screenshots from the running
app corrected it; reading
[`plan_selection_screen.dart`](../../mobile/lib/features/member/screens/plan_selection_screen.dart)
alone did not.

## Editable-content decision

Romy wanted to edit site copy himself. Declined for now, and the reasoning is
worth keeping because the request will return:

- The admin panel has **one** role. `UserRole` is `member | admin | clinic`
  ([`backend/models.py`](../../backend/models.py)) and the admin login only
  checks `role !== "admin"`. An account that can edit a heading can also see
  member PII, approve reimbursements, move provider payouts, and flip the
  settings that decide what customers are charged. Granular editing needs a
  fourth role first, not a new admin account.
- Payment instructions are deliberately **not** DB-editable. Wrong payment copy
  costs real money, so it goes through review. FAQs remain editable and are the
  place for the client to add payment nuance.

**Delivery is not the obstacle.** DB-backed copy is served as prerendered
static HTML with a background refresh, so there is no per-visitor cost; adding
`AbortSignal.timeout` did not change `/` from `Static` + `Revalidate 1h`.

### Two live gaps fixed along the way

- Admin saves revalidated `/admin/*` only, never `/`. FAQ and plan edits took
  up to an hour to appear publicly, which reads as a broken save. Now handled
  by [`website/lib/revalidate.ts`](../../website/lib/revalidate.ts).
- Public content fetches had no timeout. A production build while Render is
  asleep would fall through to the hardcoded fallback and cache **that** for an
  hour, silently. Bounded in
  [`website/lib/public-content.ts`](../../website/lib/public-content.ts).

## Never publish the checkout screenshot

The captured PayMongo checkout image carries a **live, scannable QR Ph code**
for a real ₱2,999 charge plus the checkout session id. It is not in
`website/public/` and must not be. The page draws that screen instead
([`website/components/qr-ph-diagram.tsx`](../../website/components/qr-ph-diagram.tsx)),
which also avoids owning a screenshot of a vendor UI we do not control.

Raw captures now land at the repo root ignored by `.gitignore` — they routinely
carry a member name, PawPoints, pet records and wallet balances, and this repo
is public. Anything for the site is renamed and committed deliberately under
`website/public/`.

## Built

`/getting-started` — six steps from account creation to an active plan, five
app screenshots and two drawn diagrams, plus a compact payment rail under the
pricing section on the homepage. `/how-to-pay` 307-redirects to it; the URL
changed when the scope grew past payment.

The one visual that earns its place: a phone cannot scan its own screen, so the
guide shows screenshotting the QR and picking it from the gallery inside the
wallet app. That is the step text alone cannot carry.

### Verified

Production build, `tsc --noEmit`, and ESLint all clean. `/` stays `Static` with
`Revalidate 1h`; `/getting-started` is `Static` with 0 B of page JS. The 307
redirect and every image path were checked against a running `next start`.
Contrast was computed rather than eyeballed, which caught `--color-ink-faint`
used as diagram text at **2.41:1** (it is a divider colour; now `ink-muted` at
5.47:1) and a 36px touch target on the rail link against the 44px floor.

`border-s` compiles to **nothing** in this Tailwind setup. It was silently
dropping the step connector line and the rail separators with no build or lint
error. `ps-*` and `-inset-s-*` do work, via a `:not(:lang(…))` fallback. Check
generated CSS before trusting a logical-property utility here.

### Not verified

**No visual pass.** No browser, screenshot tool, Playwright, or Puppeteer is
available in this environment, so everything above is structural, numerical, or
CSS-level. Layout was reasoned about, not seen. The one spot flagged for human
eyes: at a 320px viewport the gallery-scan diagram labels compute to about
11px.

## Open

- **Consent gap in the shipped app** — step one of this guide is the sign-up
  screen, which still asks members to accept a document they cannot read. See
  [`../features/member-documents.md`](../features/member-documents.md). Needs a
  new AAB.
- **Member Manual boundary** — "how to use the app" is the manual's job, and the
  manual is frozen for rewriting. The guide deliberately stops at payment.
  `website/public/app-reimbursement-screen.png` is committed but unused,
  pending that decision: either a claims section is added or the file goes.
- **Missing screenshot** — the "One step left / Complete Payment" screen. Step 4
  currently has no image.
- **`app-choose-plan.png` carries prices.** Plans are admin-editable, so a price
  change makes the screenshot disagree with the pricing section. Re-capture it
  whenever a plan price moves.
