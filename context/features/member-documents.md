# Member documents — agreement and manual, restored

**Status:** restored 2026-08-13. The freeze that ran from 2026-08-03 is over —
Romy supplied both revised documents.
**Owns:** [`website/lib/legal-documents.ts`](../../website/lib/legal-documents.ts),
[`website/app/terms-of-service/page.tsx`](../../website/app/terms-of-service/page.tsx),
[`website/app/member-manual/page.tsx`](../../website/app/member-manual/page.tsx),
[`website/components/document-under-revision.tsx`](../../website/components/document-under-revision.tsx),
[`website/next.config.ts`](../../website/next.config.ts),
[`website/components/register-form.tsx`](../../website/components/register-form.tsx),
[`website/components/site-footer.tsx`](../../website/components/site-footer.tsx),
[`website/components/legal-page-layout.tsx`](../../website/components/legal-page-layout.tsx)

## What is published now

| Document | Lives at | Version |
| --- | --- | --- |
| Membership Agreement | `/terms-of-service` | MP-CON-001 **Rev. 5A** — Service Authorization, Annual and Monthly Activation Edition |
| Member Manual | `/docs/member-manual.pdf` | **Rev. 3C** — Authorization & Wellness Benefit Edition, 1,452,321 bytes |

The ToS page **is** the agreement —
[`mobile/lib/core/constants/api_constants.dart`](../../mobile/lib/core/constants/api_constants.dart)
sets `agreementUrl = tosUrl`. There is no separate agreement page. The page is
titled "Membership Agreement" now (it used to say "Terms of Service"), which is
what the app, the sign-up checkbox and the footer already called it.

**The manual slot used to hold the wrong document.** Until this restore,
`public/docs/member-manual.pdf` was 238,337 bytes — byte-for-byte the size of
the *Membership Agreement* Rev5A PDF, from the commit
`4909324 docs: update member manual PDF to Membership Agreement Rev5A`. Anyone
who opened the Member Manual from the app got the agreement. That is fixed: the
file is now the actual Member Manual Rev 3C.

## What Rev. 5A changed in the agreement

The published terms before this were a generic 13-clause ToS (partner clinic
access, QR check-in, annual billing). That is the wording Romy said no longer
matched the business model. Rev. 5A is a different document — 26 clauses plus
two schedules — and the model it describes is:

- **Service Authorization, not reimbursement.** MetroPaws pays the verified
  provider directly after matched service completion. Reimbursement survives
  only as a written exception (§12).
- **Advance notice is mandatory** for planned services (§7): 1 business day for
  consultation, 2 for vaccination/deworming and grooming.
- **Monthly plans vest.** Digital access after the first cleared payment;
  full planned-service eligibility only after a run of consecutive payments
  (§5.5). Annual payers skip vesting (§5.9).
- **Wellness Wallet terminology is gone**, replaced by benefit limits that are
  explicitly "not cash, stored value, a deposit account, legal tender or an
  amount withdrawable by the Member" (§2).

### The §5.5 vesting table — the site does not match the PDF here

Rev. 5A as supplied on 2026-08-13 is otherwise identical to the July Rev. 5A;
the **only** change is the Full Planned-Service Eligibility column, and as
supplied it contradicts itself — the numerals were raised and the words were
not:

| Plan | July Rev. 5A | August Rev. 5A as supplied | Published on the site |
| --- | --- | --- | --- |
| Standard | After two (2) | After **two (6)** consecutive monthly payments | After **six (6)** |
| De Luxe | After three (3) | After **three (8)** consecutive monthly payments | After **eight (8)** |
| Premium | After four (4) | After **four (10)** consecutive monthly payments | After **ten (10)** |

Mario decided on 2026-08-13 to publish the numerals as the intent and make the
words agree, rather than reproduce the contradiction on a public page — an
ambiguity in a contract of adhesion is read against the drafter under Philippine
law. **So the website is deliberately one edit ahead of the controlled PDF.**
Romy still has to reissue MP-CON-001 with 6 / 8 / 10 spelled out, or the signed
document and the published agreement stay out of step.

Emergency Support Control was left alone (3 / 3 / 4 consecutive payments).

### What was deliberately not published

The PDF is a controlled template and carries internal drafting notes that must
not go on a public page:

- the cover's IMPORTANT LEGAL REVIEW NOTE ("should be reviewed and finalized by
  a licensed Philippine lawyer before public issuance")
- the Revision History table (Rev. 0–5 marked Superseded)
- Schedule C, implementation notes for app configuration
- the FINAL CONTROL NOTE
- the blank member-information/signature form in §26, replaced by a short note
  explaining how digital acceptance is recorded

Schedules A and B *are* published — A is the member-facing rules summary, and B
is the exact statement the sign-up checkbox stands for.

## The core constraint — the shipped app links to both URLs

The Android build live on Google Play links to these two paths from three
places, compiled into installs that cannot be changed without a new release:

| Where | Links to |
| --- | --- |
| [`mobile/lib/core/widgets/agreement_checkbox.dart:74-78`](../../mobile/lib/core/widgets/agreement_checkbox.dart) | Membership Agreement, Privacy Policy, Member Manual |
| [`mobile/lib/features/auth/screens/register_screen.dart:669-699`](../../mobile/lib/features/auth/screens/register_screen.dart) | the same three |
| [`mobile/lib/features/member/screens/member_dashboard_screen.dart:3954-3966`](../../mobile/lib/features/member/screens/member_dashboard_screen.dart) | the same three, in the Account section |

**Both URLs must keep resolving, and the manual must keep the exact filename**
`/docs/member-manual.pdf`. A new name breaks every installed app. This is why
the freeze served a notice page instead of 404ing, and why the replacement PDF
was dropped in at the same path.

## How the switch works

Both flags live in `website/lib/legal-documents.ts` and are now `false`. Every
surface follows them, so pulling a document again is a two-line change:

| Surface | Under revision | Restored (now) |
| --- | --- | --- |
| `/terms-of-service` | notice page, `robots: noindex` | full agreement, indexable |
| `/docs/member-manual.pdf` | `beforeFiles` rewrite in `next.config.ts` → `/member-manual` notice | the real PDF (`beforeFiles` is empty) |
| `/member-manual` | the notice | 307 → `/docs/member-manual.pdf`, so stale links still work |
| Site footer | Member Manual and Terms of Service links removed | both back, agreement labelled "Membership Agreement" |
| Sign-up checkbox (website) | Privacy Policy only | Membership Agreement **and** Privacy Policy |
| Privacy Policy page | ToS cross-link hidden | "Read our Membership Agreement" |

`beforeFiles` is the only rewrite phase that runs ahead of the static-file
handler — that is what let the notice shadow a PDF that was still sitting in
`public/`.

The Flutter app was never touched by the freeze, so neither the freeze nor this
restore needed a new AAB or Play review.

## Consent versions — still drifting, deliberately

`AGREEMENT_VERSION` in `register-form.tsx` is now **`2026-08-rev5a`**, so web
sign-ups from today record acceptance of the document they actually read. The
other two surfaces were left alone, because changing them is not a website
deploy:

| Surface | Value | To change it |
| --- | --- | --- |
| `website/components/register-form.tsx` → `AGREEMENT_VERSION` | `2026-08-rev5a` | done |
| `backend/app/routers/auth.py` → `CURRENT_AGREEMENT_VERSION` | `2026-07.2` | needs `deploy.ps1` |
| `mobile/.../register_screen.dart` → `_agreementVersion` | `2026-07.2` | needs a new AAB + Play review |

Nothing validates the string — the backend stores
`payload.agreement_version` verbatim ([`backend/app/routers/auth.py`](../../backend/app/routers/auth.py))
and only falls back to its own constant when the client sends none. So the
website change is safe on its own, but the three will not agree until the
backend and app ship.

## Open items

1. **Get MP-CON-001 reissued** with §5.5 reading six / eight / ten (see above).
   The site already says that; the PDF does not. Confirm with Romy that 6 / 8 /
   10 was the intent — if the *words* were right and the numerals were the typo,
   the site is wrong and the edit reverses.
2. **Legal review.** The PDF's own cover says it should be reviewed by a
   licensed Philippine lawyer before public issuance. It is now public.
3. **Backend + app version strings** (table above).
4. **Members who joined during the freeze.** Website sign-ups between
   2026-08-03 and 2026-08-13 recorded `2026-08-privacy-only`:

   ```sql
   SELECT id, email, agreement_accepted_at FROM members
   WHERE agreement_version = '2026-08-privacy-only';
   ```

   **App sign-ups in that window are not in that result.** The shipped app kept
   asking for the Membership Agreement and kept recording `2026-07.2`, even
   though the link served the notice page — so its consent records for that
   window are false, and indistinguishable from pre-freeze members. Anyone
   acting on the query must also treat every `2026-07.2` row created after
   2026-08-03 as suspect.
5. **Re-consent** for those members and for existing members bound to the
   retired wording. Client/legal decision, not a code one — there is no
   re-consent prompt anywhere in the app.
6. **The system does not implement what these documents describe.** Rev. 5A is
   built on advance Service Authorization and direct provider settlement; the
   product runs pay-then-claim reimbursement, which the agreement calls the
   exception. Vesting, advance notice, member status labels and Wellness Score
   are contractual and absent, and "Wallet" — retired in both documents — still
   appears 388 times in the code. Full register with citations and a suggested
   order in
   [`document-system-alignment.md`](./document-system-alignment.md). Mario's
   instruction on 2026-08-13: the documents are the real deal, close the gaps
   ASAP, but not this session.

## Verified 2026-08-13

Against a real production build (`npm run build` + `next start -p 3111`):

- `/docs/member-manual.pdf` → `200`, `application/pdf`, `1452321` bytes, first
  bytes `%PDF-1.7`. `/member-manual` → `307` to the PDF.
- `/terms-of-service` → `200`, `<title>Membership Agreement | MetroPaws Wellness
  Club</title>`, clause text present, 29 ToC anchors, 4 rule tables, none of the
  internal notes above, none of the retired "Partner Clinic Access" wording.
- Footer renders Member Manual / Privacy Policy / Membership Agreement.
- `/register` asks for the Membership Agreement and the Privacy Policy again.
- `routes-manifest.json` `rewrites.beforeFiles` is `[]`.
- `npm run lint` reports nothing for any file touched here (the 50 pre-existing
  errors are elsewhere, plus stale copies under `website/.claude/worktrees/`).

## Layout note

The agreement runs to 29 ToC entries, which overflows the viewport. The sticky
sidebar nav in `legal-page-layout.tsx` now scrolls
(`max-h-[calc(100svh-8rem)] overflow-y-auto overscroll-contain`) instead of
pushing entries out of reach. The Privacy Policy shares that component and is
unaffected at 11 entries.
