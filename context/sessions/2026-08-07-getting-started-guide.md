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

## "Wallet" became "benefit", and the app did not follow

Later the same day the client asked to drop the word "wallet" for the two
annual pools, and to pull the app-preview section from the homepage.

**The word meant two unrelated things and only one was renamed.** The
MetroPaws pools ("Preventive Wellness Wallet", "Emergency Wallet", "Benefit
Wallet") are now "benefit". Third-party e-wallet apps ("scan with your wallet
app", "e-wallet and bank apps", meaning GCash and Maya) were left alone,
because "open your benefit app, tap Scan QR" is not a sentence. The instruction
was "alisin lahat"; taking it literally would have broken the payment copy.

**The fallback drift warned about above actually happened.** Live pricing
already said "benefit" because the cards render `plan.features` from the
database, while the hardcoded `FALLBACK_PLANS` in
[`website/components/plans-section.tsx`](../../website/components/plans-section.tsx)
still said "Wallet". A backend outage would have flipped the wording back with
no error anywhere. Both now agree. This is the concrete cost of DB-backed copy:
two places to change, and only one of them fails loudly.

**The app still says "Wallet"** — a `BENEFIT WALLET` heading and a `Wallet` tab
in the bottom nav. So site and app now disagree on the word, which is the
confusion the rename was meant to remove. Closing it needs a new AAB.

Two consequences for assets committed hours earlier:

| Asset | Now stale because |
| --- | --- |
| `website/public/app-home-screen.png` | shows the `BENEFIT WALLET` heading |
| `website/public/app-choose-plan.png` | shows "Preventive Wellness Wallet"; those strings come from the same database row that was already edited, so a fresh capture reads "Benefit" |

`AppPreviewSection` is unmounted, not deleted — the client said "muna". Its
`public/mobile-app-*.jpg` mocks show per-service session counts ("Vaccines 1
left") and a **Book** tab, neither of which exists any more; the app moved to
two peso benefits and a Claim tab. **Side effect worth undoing soon:** the
homepage now carries no app screenshots at all, which works against the "show
the product, not the category" principle in `PRODUCT.md`.

## Open

- **Consent gap in the shipped app** — step one of this guide is the sign-up
  screen, which still asks members to accept a document they cannot read. See
  [`../features/member-documents.md`](../features/member-documents.md). Needs a
  new AAB.
- **App wording lags the site** — the app says "Wallet" where the site now says
  "benefit". Needs a new AAB, same trip as the consent fix above.
- **Re-capture four screenshots** — `mobile-app-*.jpg` for the app preview, plus
  `app-home-screen.png` and `app-choose-plan.png` for the guide.
- **Member Manual boundary** — "how to use the app" is the manual's job, and the
  manual is frozen for rewriting. The guide deliberately stops at payment.
  `website/public/app-reimbursement-screen.png` is committed but unused,
  pending that decision: either a claims section is added or the file goes.
- **Missing screenshot** — the "One step left / Complete Payment" screen. Step 4
  currently has no image.
- **`app-choose-plan.png` carries prices and DB wording.** Plans are
  admin-editable, so a price or feature-string change makes the screenshot
  disagree with the pricing section. Re-capture it
  whenever a plan price moves.
