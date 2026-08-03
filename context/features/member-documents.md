# Member documents — agreement and manual, frozen for rewriting

**Status:** active freeze as of 2026-08-03. Blocked on new documents from the
client (Romy).
**Owns:** [`website/lib/legal-documents.ts`](../../website/lib/legal-documents.ts),
[`website/app/terms-of-service/page.tsx`](../../website/app/terms-of-service/page.tsx),
[`website/app/member-manual/page.tsx`](../../website/app/member-manual/page.tsx),
[`website/components/document-under-revision.tsx`](../../website/components/document-under-revision.tsx),
[`website/next.config.ts`](../../website/next.config.ts),
[`website/components/register-form.tsx`](../../website/components/register-form.tsx),
[`website/components/site-footer.tsx`](../../website/components/site-footer.tsx)

## What happened

On **2026-08-03**, reviewing the app-launch announcement email, Romy said the
Membership Agreement no longer matches the business model and has to be
rewritten — *"yung nasa agreement yun ang irerevise natin ksi di n cya aligned
s business model natin"* — and asked to take it down in the meantime:
*"the notification message is already fine with me. but we temporarily disable
the agreement and manual in the meantime."*

So this is a **temporary freeze, not a removal.** Both documents are expected
back once Romy supplies the revised versions. Nothing was deleted: the terms
text and the PDF are still in the repo, behind two flags.

## The two documents

| Document | Lives at | Note |
| --- | --- | --- |
| Membership Agreement | `/terms-of-service` | The ToS page **is** the agreement — [`mobile/lib/core/constants/api_constants.dart`](../../mobile/lib/core/constants/api_constants.dart) sets `agreementUrl = tosUrl`. There is no separate agreement page. |
| Member Manual | `/docs/member-manual.pdf` | Static file in `website/public/docs/`. Last content update in the website repo was `4909324 docs: update member manual PDF to Membership Agreement Rev5A`, so the PDF itself carries agreement revisions — which is why both had to go dark together. |

## The core constraint — the shipped app links to both URLs

The Android build live on Google Play links to these two paths from three
places, and those links are compiled into installs that cannot be changed
without a new release that members then have to install:

| Where | Links to |
| --- | --- |
| [`mobile/lib/core/widgets/agreement_checkbox.dart:74-78`](../../mobile/lib/core/widgets/agreement_checkbox.dart) | Membership Agreement, Privacy Policy, Member Manual |
| [`mobile/lib/features/auth/screens/register_screen.dart:669-699`](../../mobile/lib/features/auth/screens/register_screen.dart) | the same three |
| [`mobile/lib/features/member/screens/member_dashboard_screen.dart:3954-3966`](../../mobile/lib/features/member/screens/member_dashboard_screen.dart) | the same three, in the Account section |

**Therefore both URLs must keep resolving.** 404ing them would put dead links
inside a live app's sign-up consent flow — the class of defect Play review has
already rejected this app for twice (see
[`../sessions/2026-07-30-play-store-launch.md`](../sessions/2026-07-30-play-store-launch.md)).
Both paths serve a notice page instead.

This also means **the replacement manual must keep the exact filename**
`/docs/member-manual.pdf`. A new name breaks every installed app.

The Flutter app was deliberately left untouched, so the freeze needed no new
AAB and no Play review.

## What the freeze does

Both flags live in `website/lib/legal-documents.ts`.

| Surface | Frozen behaviour |
| --- | --- |
| `/terms-of-service` | `DocumentUnderRevision` notice, `robots: noindex`. `TermsContent` stays in the file, unrendered. |
| `/docs/member-manual.pdf` | `beforeFiles` rewrite in `next.config.ts` → `/member-manual`, which renders the same notice. The PDF stays in `public/`, shadowed. `beforeFiles` is the only rewrite phase that runs ahead of the static-file handler. |
| Site footer | Member Manual and Terms of Service links removed. Privacy Policy stays. |
| Sign-up checkbox | Privacy Policy only. |
| Privacy Policy page | ToS cross-link hidden (`crossLink` is now optional on `LegalPageLayout`). |

The Privacy Policy is **never** part of this freeze — Play requires a live
privacy policy, and it is a separate document that the client did not question.

## Consent during the freeze

Sign-up still requires consent and still records it, but members who join
during the freeze never saw the Membership Agreement, so recording the real
agreement version against them would be a false consent record. They get
`agreement_version = "2026-08-privacy-only"`
(`PRIVACY_ONLY_CONSENT_VERSION`), which makes them queryable later:

```sql
SELECT id, email, agreement_accepted_at FROM members
WHERE agreement_version = '2026-08-privacy-only';
```

The backend takes `agreement_version` as a free-form string and stores it
verbatim ([`backend/routers/auth.py`](../../backend/routers/auth.py)), so this
needed no API change.

**Pre-existing drift worth knowing** (verified 2026-08-03, not introduced by
the freeze): the three surfaces do not agree on the version string, even
though the website comment claims they must.

| Surface | Value |
| --- | --- |
| `website/components/register-form.tsx` → `AGREEMENT_VERSION` | `2026-07` |
| `backend/routers/auth.py` → `CURRENT_AGREEMENT_VERSION` | `2026-07.2` |
| `mobile/.../register_screen.dart` → `_agreementVersion` | `2026-07.2` |

Harmless today because nothing validates it, but it means web sign-ups and app
sign-ups carry different version strings for the same document. Fix it when the
new agreement lands, since all three have to be touched anyway.

## Bringing them back

1. **Get both documents from Romy** — the revised agreement text and the
   replacement manual PDF. Confirm which revision number supersedes Rev5A.
2. **Replace the agreement text** in `website/app/terms-of-service/page.tsx`:
   rewrite `TermsContent`, and update the `sections` array to match the new
   headings — it drives both the table of contents and the scroll-spy
   `IntersectionObserver`, so a stale entry silently breaks the ToC. Update
   `lastUpdated` (currently `"June 1, 2026"`).
3. **Replace the PDF** at `website/public/docs/member-manual.pdf` — same path,
   same filename (see the constraint above).
4. **Flip both flags** to `false` in `website/lib/legal-documents.ts`.
5. **Agree one version string** and set it in all three places listed above.
   Bumping it is what marks the new document as a new acceptance.
6. **Decide on re-consent** for members who joined during the freeze (the SQL
   above) and for existing members bound to the retired wording. That is a
   client/legal decision, not a code one — there is currently no re-consent
   prompt anywhere in the app.
7. **Deploy:** push `main` on the monorepo for version control, then
   fast-forward `metropaws-website`'s `master` with a commit carrying
   `main:website`'s tree — that repo is still Vercel's production source (see
   [`../../MONOREPO_MIGRATION_PLAN.md`](../../MONOREPO_MIGRATION_PLAN.md)).
   The backend only needs `deploy.ps1` if `CURRENT_AGREEMENT_VERSION` changed.
   The app needs a new AAB only if its own consent copy or version string
   changed.
8. `website/app/member-manual/page.tsx` can stay — with the flag off it
   redirects to the real PDF, so stale links keep working. Delete it only if
   you also drop `MANUAL_NOTICE_PATH`.

## Verified 2026-08-03

Checked against a real production build (`npm run build` + `next start`), both
flag states:

- Frozen: `/docs/member-manual.pdf` returns `text/html` containing the notice —
  first bytes `<!DOCTYPE`, not `%PDF`. `/terms-of-service` serves the notice
  with no clause text present. Register page links only to `/privacy-policy`.
- Restored: the same path returns `application/pdf`, 238,337 bytes; the full
  terms render; footer links and the two-document checkbox come back.
- The rewrite is present in `.next/routes-manifest.json` under `beforeFiles`,
  which is what Vercel applies ahead of the filesystem — so the shadowing holds
  in production, not just under `next start`.
