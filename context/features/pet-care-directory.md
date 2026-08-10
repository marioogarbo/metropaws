# Pet Care Directory

**Status:** built 2026-08-08 on branch `feature/pet-care-directory`. Verified on dev;
**not yet deployed to prod** (see "Deploy checklist" at the end).
**Scope:** backend (new table + public/admin API) + website (public page + admin CRUD). Mobile is out of scope.

| Piece | Path |
| --- | --- |
| Service vocabulary (backend) | `backend/directory_taxonomy.py` |
| Model | `backend/models.py` → `DirectoryProvider` |
| Schemas | `backend/schemas.py` → `DirectoryProvider{Create,Update,Out}` |
| Routes | `backend/routers/directory.py` |
| Seed | `backend/seed_directory.py` |
| Service vocabulary (website) | `website/lib/directory-taxonomy.ts` |
| Fetch + helpers | `website/lib/directory.ts` |
| Public page | `website/app/find-pet-care/page.tsx` + `components/directory-{hero,list,notes,service-mark}.tsx` |
| Admin page | `website/app/admin/(protected)/directory/` + `components/admin/directory-table.tsx` |

A public, admin-editable list of vet clinics, groomers, pet stores and boarding
places around Las Piñas. It is a **community resource**, not a partner network:
inclusion carries no endorsement and no contractual relationship. Nineteen seed
rows were supplied by the client on 2026-08-08.

---

## Why this is a NEW table, not a reuse

Three "provider-ish" tables already exist and none of them fit:

| Table | What it is | Why not this |
| --- | --- | --- |
| `clinic_partners` | A login-capable clinic **account** (`user_id` FK) | Only used by the flag-disabled booking feature. A directory listing has no login and no user row. |
| `reimbursement_providers` | A payout target — bank/GCash details, admin-verified | `is_active` there means *"cleared to receive MetroPaws money"*. Reusing the row would make publishing a listing and authorising a payout the same act. |
| `faqs` / `promos` | Published website copy | Right shape, wrong content. |

The dangerous one is the middle row. `ReimbursementProvider.is_active == True` is
the control that gates who MetroPaws will wire money to, and the model docstring
says so. If the directory shared that table, an admin adding "Zoey's Pet Shop" so
it appears on the website would also be adding a payout target, and a sloppy
response schema on a **public, unauthenticated** endpoint would expose
`payout_account_number`. Separate tables keep publishing and paying independent.

New table: **`directory_providers`**.

A directory row that later becomes a real partner is represented by
`is_partner = true` on the directory row, not by a foreign key. If the two ever
need to be linked (same business, listed publicly *and* payable), add a nullable
`reimbursement_provider_id` then — not now.

---

## Naming: "Providers" is already taken in the admin

`/admin/providers` already exists and means *reimbursement payout targets*
(sidebar label "Providers", `Banknote` icon). A second page called Providers
would be a genuine operator trap.

- New admin page: **`/admin/directory`**, sidebar label **"Directory"**, icon `MapPin`.
- New public page: **`/find-pet-care`** (client's choice 2026-08-08 over
  `/directory`, so the URL matches the headline and reads in search results),
  headed "Find Pet Care Near You".
- The existing `/admin/providers` page is **not renamed** in this change. If it
  should become "Payouts" or "Direct Payments" for clarity, that's a separate call.

---

## Data model

```python
class DirectoryProvider(Base):
    __tablename__ = "directory_providers"

    id          = Column(String, primary_key=True, default=gen_uuid)
    name        = Column(String, nullable=False)
    services    = Column(JSON, nullable=False, default=list)   # ["veterinary", "grooming"]
    address     = Column(Text,   nullable=True)
    phone       = Column(String, nullable=True)
    email       = Column(String, nullable=True)
    website     = Column(String, nullable=True)
    hours       = Column(Text,   nullable=True)
    map_url     = Column(Text,   nullable=True)   # explicit pin; blank = generated search link
    is_partner  = Column(Boolean, default=False, nullable=False)
    is_published= Column(Boolean, default=True,  nullable=False)
    created_at  = Column(DateTime(timezone=True), server_default=func.now())
    updated_at  = Column(DateTime(timezone=True), onupdate=func.now())
```

`create_all` on startup creates it — no `migrate.py` entry needed, per the
backend's "new table" rule. Nothing here is a schema change to an existing table.

### Why `services` is a tag list, not the free-text category

The client's data has compound categories: *"Veterinary / Grooming / Boarding /
Supplies"*, *"Veterinary / Diagnostics / Surgery"*. The design needs four filter
chips (All / Veterinary / Grooming / Pet Stores / Boarding), and a place that is
both a clinic and a groomer must appear under **both** chips. A single free-text
string cannot do that without substring-matching business names at render time.

So `services` stores canonical slugs and the UI derives two things from it:

| Chip | Slugs it matches |
| --- | --- |
| Veterinary | `veterinary`, `animal_hospital`, `emergency`, `diagnostics`, `surgery` |
| Grooming | `grooming` |
| Pet Stores | `pet_store`, `pet_supplies` |
| Boarding | `boarding`, `pet_hotel` |

The displayed category line is the slugs' labels joined with " / ", which
reproduces the client's strings exactly.

**The vocabulary lives in two places and must stay in sync:** the backend
validates against it (`backend/directory_taxonomy.py`), the website renders
labels and chips from it (`website/lib/directory-taxonomy.ts`). Both files carry
a comment pointing at the other. Adding a service type is a two-line change in
both — deliberately a code change, because a new slug that no chip maps to would
silently vanish from every filter.

### `map_url` and the "View Map" button

Stored when the admin pastes a real Google Maps place link. When blank, the
website generates `https://www.google.com/maps/search/?api=1&query=<name + address>`.
Every card therefore gets a working map button without the admin having to hunt
19 URLs, while still allowing an exact pin where it matters.

---

## API

Public (no auth), mirroring `routers/faqs.py`:

- `GET /directory` → published rows only, partners first then name A→Z.
  Response never contains anything not meant to be public — it's a separate
  table, so there is no payout field to accidentally leak.

Admin (`require_admin`):

- `GET /admin/directory` — all rows including unpublished
- `POST /admin/directory`
- `PUT /admin/directory/{id}`
- `DELETE /admin/directory/{id}` — hard delete; a directory row has no history
  hanging off it (unlike a reimbursement provider, which must be deactivated
  instead of deleted because claims reference it)

New router file `backend/routers/directory.py` with `public_router` +
`admin_router`, registered in `main.py` alongside the FAQ pair.

**Ordering is server-side and fixed** (partners first, then alphabetical). No
`sort_order` column and no drag-to-reorder in v1: FAQs need a narrative order,
a directory does not, and manual ordering of 19+ rows is a maintenance cost with
no reader benefit. `is_partner` already provides the only "pin to top" anyone has
asked for.

---

## Website — public page `/find-pet-care`

Standard page shell: `SiteHeader` → sections → `SiteFooter variant="photo"`,
matching `/getting-started`.

Design direction (built with `/impeccable`, following `DESIGN.md` — navy/gold/
cream, Montserrat, 14px body cap, light mode only, no shadows-as-decoration):

1. **Navy hero** — eyebrow "Wellness Club", headline "Find Pet Care Near You",
   one-paragraph explanation of what this list is and is not.
2. **Disclaimer** — kept prominent and near the top, not buried in the footer.
   This is the legally meaningful element of the page (see below).
3. **Filter row** — search input (name / service / area) + the four chips.
   Filtering is **client-side** over the full list; at ~19 rows a server-side
   search endpoint would be latency for nothing.
4. **Card grid** — responsive; each card shows name, service line, address,
   phone (tel: link), email and website when present, hours, and a map button.
   Partner rows carry a gold "MetroPaws Partner" badge; everything else reads
   "Community Directory".
5. **Empty result state** — when a search matches nothing, say so and offer to
   clear the filter, rather than showing a blank grid.
6. **Footer note** — "Know a provider we should include?" plus, importantly, a
   **removal path** (below).

Not copied from the reference screenshots: the coloured initials rail on the
card's left edge (a side-stripe panel, which `DESIGN.md` rules out under "no
side-stripe colored borders on cards"), and the label-per-line
`Address: / Contact: / Hours:` block, which turns every card into a form.

### Entry points

The header nav already carries six desktop links and wraps if pushed, so it was
left alone. If the client wants the directory in the top nav, something else
comes out.

- `SiteFooter` → Navigate list gains **"Find Pet Care"**.
- `CoverageTeaser`'s "The Pack Network" pillar gains a
  "Find pet care near you →" link.
- **`components/directory-cta.tsx` replaced `components/partner-clinic-cta.tsx`
  on the homepage** (client decision, 2026-08-08). The old "Bring MetroPaws to
  your clinic" section pitched a partner network that does not exist:
  `clinic_partners` and `reimbursement_providers` are both empty, so "join a
  growing network of Metro Manila clinics" was a claim with nothing behind it.

  **What this removed:** the homepage no longer invites clinics to partner. The
  Facebook link that section pointed at is still in `site-footer.tsx` and
  `faq-section.tsx`, so clinics can still reach MetroPaws, but there is no
  partnership pitch anywhere on the site now. Put one back when there is a real
  programme to point at. Nothing linked to the old `#partner` anchor (checked),
  so no dead links.

### No hardcoded fallback list — a deliberate break from the FAQ pattern

`faq-section.tsx` and `plans-section.tsx` ship a full hardcoded copy of their
content so a sleeping backend still renders. The directory will **not**:

Six FAQ answers are stable marketing copy. Nineteen clinics' phone numbers and
opening hours are operational data that goes stale, and a hardcoded copy silently
diverges the moment an admin edits a row. Serving a visitor a stale phone number
for an emergency vet is worse than serving them an honest "we can't load this
right now — here's our contact email". The page keeps the same ISR + fetch policy
from `lib/public-content.ts`; only the fallback differs, and it is an error state,
not stale content.

**This decision held, but the error state turned out to be a trap of its own** —
see "The page shipped broken in production" below. A page with no fallback must
also make sure a failed fetch never becomes the cached page.

---

## Website — admin page `/admin/directory`

Server component fetches with the `admin_token` cookie and redirects to
`/admin/login` on 401, with the `redirect()`-outside-`try/catch` guard the other
admin pages document. Table + dialogs follow `providers-table.tsx`'s existing
conventions (colocated `Overlay` / `DialogShell` / `Field` primitives, focus trap,
Escape to close, focus returned to the trigger).

Columns: Provider (name + service line) · Contact · Area · Published · actions.
`is_partner` is a checkbox in the add/edit dialog, not a fourth column — it's
rare and belongs with the record, not in a scan-the-list position.

Server actions in `app/admin/(protected)/directory/actions.ts` call
`revalidateAdminAndHome("/admin/directory")`. **`revalidateAdminAndHome` purges
`/` only**, so it needs the public directory path too — either extend the helper
to take extra paths or add an explicit `revalidatePath("/find-pet-care")`.
Without it an admin edit stays invisible for up to an hour and reads as a broken
save, which is the exact bug that helper exists to prevent.

---

## Third-party listings — the part that isn't a code problem

These 19 businesses have not consented to being listed. The information is
publicly posted business contact data, so publishing it is ordinary directory
practice, but two things should ship with it:

1. **The disclaimer, verbatim in substance** — inclusion is not accreditation,
   endorsement, approval, or a contractual relationship; details may change;
   confirm directly before visiting. This is what keeps a member who has a bad
   visit from believing MetroPaws vouched for the clinic.
2. **A removal path.** One line in the page footer: a business that wants its
   listing corrected or removed emails `csr@metropaws.ph`. Cheap to add, and the
   only thing that turns a complaint into a two-minute admin edit.

Three rows have placeholder contact data ("Please verify directly with the
clinic"). They ship as-is because that is the honest state of the data, and the
card renders the placeholder as muted text rather than as a fake phone link.

---

## Seeding

`backend/seed_directory.py` — idempotent, inserts by name only if absent, so a
re-run after the client edits rows in admin does not clobber their edits. Run
against dev, then prod, before the first deploy that exposes the page.

## Contrast: two AA failures found and fixed

Measured, not eyeballed (script in the session notes):

- **Body copy on navy.** The site's habit is `--color-ink-faint` on `--color-navy`
  (`partner-clinic-cta.tsx`, `site-footer.tsx`). That is **3.23:1**, under the
  4.5:1 AA floor for body text. This page uses `--color-silver` (**5.77:1**)
  instead. **The pre-existing uses elsewhere on the site were left alone** and
  are still failing; fixing them is a separate, site-wide change.
- **Partner badge.** Navy on `--color-gold` is **3.52:1**, which passes as large
  text on the 14px-semibold CTA buttons but fails for the 12px badge. The badge
  uses a darkened gold `oklch(0.52 0.08 82)` with cream text (**12.52:1**).

### Design pass, 2026-08-08 (`/impeccable layout colorize polish`)

Three structural findings, all fixed:

1. **The search and filters moved onto the navy field.** They used to open the
   cream results section. Under the headline sat a band of empty navy, and on a
   phone the controls were a full screen below the fold. Putting them on the
   same navy as the hero, separated by a `border-white/10` hairline, fixes the
   dead space, brings the controls into reach on mobile, and restores the
   navy share `DESIGN.md` asks for (navy is now ~50% of the first 900px
   instead of ~25%). `DirectoryHero`'s bottom padding is deliberately short
   because `DirectoryList`'s control band continues the same field.
2. **Rows reached only two thirds of the width.** Hours and contacts stacked in
   one column, leaving ~300px of dead space at the right edge of every row.
   They now split into two columns at `xl`, measured down to **16px** of
   trailing space. Hours also carries `--color-ink` + `font-medium` because it
   is the field people scan for; contacts stay `--color-ink-muted`.
3. **Partner rows get a gold wash, not a stripe.** `--color-gold-wash` (7% of
   the brand gold) tints the row; `--color-gold-wash-hover` (13%) on hover and
   focus. A coloured left edge is banned by both `DESIGN.md` and the impeccable
   ruleset, and the wash keeps the row inside one list rather than fencing it
   off.

New tokens in `globals.css` (previously magic values in components):
`--color-gold-deep`, `--color-gold-wash`, `--color-gold-wash-hover`.

Two more AA failures found and fixed in the dark control band: the search input
and the inactive filter chips were outlined in `white/25`, which is **2.06:1**
against navy where WCAG 1.4.11 wants **3:1** for a control's own boundary. They
are now `white/40` (**3.70:1**), hover `white/60`–`white/70`. The active chip is
filled **cream, not gold**: gold behind navy text is 3.52:1 and fails at 14px.

### Device pass, 2026-08-08 (`/impeccable adapt`)

Audited at 320 / 360 / 390 portrait, 844x390 landscape, and 768x1024 tablet,
all with touch emulation. Three measured failures, all fixed:

1. **40 touch targets under 44px on every phone size.** Phone, email, and
   website links were 18px tall. On a page someone opens because their dog needs
   a vet, the phone number is the action. Contact links now carry a real 44px
   band; the "View on map" link uses inline vertical padding (which expands the
   tap box without changing the line box). Padding alone was not enough for the
   contact rows: at a 28px pitch the expanded hit boxes overlap and steal each
   other's taps, so the row itself carries the height.
2. **iOS Safari zoomed the page on search focus.** The input was 14px, and
   Safari zooms any focused input under 16px. It is 16px on touch, back to the
   brand's 14px with a mouse.
3. **A swipe past the end of the filter chips triggered browser back.**
   Fixed with `overscroll-x-contain`.

**These are gated on `pointer-fine:`, not on a width breakpoint.** The first
attempt used `md:`, which silently failed the two contexts that need it most:
a phone in landscape (844px wide) and a tablet in portrait (768px wide) are both
past `md` and both still touch-only. Screen size does not tell you input method.
Verified: every touch context reports 0 undersized targets, a mouse still gets
the compact inline layout.

Landscape phones also got the desktop two-column hero via
`@media (max-height:540px) and (min-width:640px)`, plus reduced padding. First
listing moved from **888px to 609px** down the page, a 31% cut.

The one remaining sub-44px target is `csr@metropaws.ph` in the closing note,
which sits inside a sentence and is covered by WCAG 2.5.8's inline exception.

`viewport-fit=cover` was deliberately **not** added: the site sets no
safe-area insets anywhere, so opting into the notch area would push content
under it. That is a site-wide change, not a directory one.

### Delight pass, 2026-08-08 (`/impeccable delight`)

The brief here is set by PRODUCT.md ("premium, exclusive, confident... does not
beg for attention") plus this page's emotional context: people often open it
because a pet needs care. That rules out playful entirely. Nothing was added to
the disclaimer or the backend-down state; both stay plain.

- **`.mp-settle`** (`globals.css`): the list re-settles over 190ms with a 20ms
  stagger capped at 8 rows, so row 19 is never held more than ~160ms. The `<ul>`
  is keyed on the **filter chip only, deliberately not on the query** — keying
  on typing would replay the animation on every keystroke and strobe. Verified
  by comparing `Animation.startTime` before and after: unchanged across
  keystrokes, changed on a chip tap.
- **Empty state** names the search back to the reader ("Nothing here matches
  *zzzz*"), which is usually where the surprise is: a stray character or an old
  term still in the box.
- **Escape clears the search field**, and clearing via the X button returns the
  caret to the input. Without that the focused element is a button that just
  unmounted, so focus falls to the top of the document and the next keystroke
  goes nowhere.
- **The map arrow leans 2px** toward where it is taking you, on hover and on
  keyboard focus.

Considered and rejected: making the service tags clickable filters. A tag is a
slug ("Diagnostics") while a chip is a group ("Veterinary"), so the jump would
land on a chip the reader did not click. More confusing than helpful.

### Service marks, 2026-08-08 — and why not the providers' own logos

The question was whether each listing should carry the business's logo or some
identifier image. **Logos were rejected**, on three grounds in this order:

1. **It contradicts the page's own disclaimer.** These 19 businesses never
   consented to being listed, and all 19 ship `is_partner = false`. Publishing
   publicly-posted contact details is ordinary directory practice; reproducing a
   business's trademark next to a gold "MetroPaws Partner" tier is an
   affiliation claim, which is the exact thing the hero spends a paragraph
   denying. Copyright in the mark is a separate problem from the trademark one.
2. **It would make scanning worse.** For small Las Piñas businesses the only
   available "logo" is a Facebook profile picture: storefront photos, text on
   white, mixed croppings and densities. Nineteen mismatched images down a left
   edge is noise. A row-start image only helps if it is *consistent*.
3. **Someone has to maintain it** — 19 sourced files kept current, forever.

What shipped instead: **a mark per service group**, derived from data MetroPaws
already owns (`components/directory-service-mark.tsx`).

- Four glyphs, one per filter chip: `Stethoscope` / `Scissors` / `ShoppingBag` /
  `BedDouble`. `BedDouble` over `House` because a house glyph in site chrome
  reads as "home page"; `ShoppingBag` over `Store` because a store front shares
  its roofline with the bed, and silhouette is the whole point at 18px.
- **The same glyph appears on the filter chip**, which is where it gets its
  caption. A reader meets the scissors beside the word "Grooming" before meeting
  it on a row, so the marks read as a vocabulary rather than a puzzle. "All"
  deliberately carries **no** icon: it is the absence of a service filter, not a
  fifth service, and a paw print there collapsed into a smudge at chip size.
- **Which glyph** comes from `primaryFilter()` in `lib/directory-taxonomy.ts`:
  the first stored service a chip claims. `services` keeps the order the admin
  typed, which is the order the business leads with, so **reordering the
  services in admin changes the mark** — the right lever to hand an operator who
  disagrees with the pick. No new column, no new API field.
- **Under a filter the mark still shows the listing's primary service**, not the
  filtered one. Filtering to Grooming and seeing a stethoscope on "Golden Bunch
  Veterinary Clinic & Pet Grooming Center" is information, not a bug: the mark
  says what the place mainly is, the highlighted tag already says why it
  matched. Making the marks follow the active filter would render all 19
  identical and throw the rail away.
- Monochrome navy on `--color-navy-wash` (new token, the gold-wash mechanic in
  navy). Four coloured tiles would have been a fifth palette decision on a
  palette committed to navy and gold.
- `aria-hidden`: the service tags below say the same thing in words, so the
  glyph is never the sole carrier of a fact.

Two layout consequences, both measured:

- The mark sits **outside** the row's two-column grid, not inside the name
  block. Inside, it indented name/tags/address while hours and contacts stayed
  flush left, and on a phone (where the columns stack) that left a visibly
  ragged edge mid-row. Outside, all 19 marks share one left edge and every line
  of content shares another.
- The mark costs 56px of row width, which came out of the hours column and put
  four listings' opening hours on a third line. The identity column went
  **1.2fr → 1.1fr** to buy it back: three-line hours dropped from 4 rows to 2,
  at the cost of ~9px across the whole list. Hours is the field people scan (it
  already carries `--color-ink` + `font-medium` for that reason); addresses wrap
  gracefully, hours do not.

Re-verified after the change: trailing space in a desktop row is still **16px**,
0 touch targets under 44px at 320 / 390 / 844x390 / 768x1024 with touch
emulation, no horizontal overflow at 1440 / 834 / 390, `next build` clean.

**If a real partner is ever signed**, their logo is the one case where the
consent objection disappears — a partner has a contractual relationship by
definition. That would be a nullable `logo_url` on the directory row, rendered
in the mark's slot for partner rows only. Not built: there are zero partners
today, so it would be dead code.

### Copy and simplification pass, 2026-08-08 (`/impeccable clarify simplify`)

**"Providers" is gone from the public page.** In the Philippines "provider"
reads as *HMO-accredited provider*, which is the precise claim the hero
disclaimer exists to deny; it is also already taken in the admin, where
`/admin/providers` means payout targets. The public page now says **places**
("19 places", "7 of 19 places", "Show all 19 places", "Suggest a place"). The
`DirectoryProvider` type, props, and API field names are unchanged: this was a
copy change, not a rename.

**The disclaimer was on the page twice.** The hero box and the closing fine
print said the same thing in different words, and the footer version also
claimed MetroPaws "reconfirms details periodically", which no one does. The
footer paragraph was **deleted**. The hero box, which the original build made
prominent on purpose, is untouched and still carries the full statement
(accreditation / endorsement / agreement, the Partner exception, and confirm
before visiting). The removal path in "Is this your business?" is also
untouched. **If the client wants belt-and-braces boilerplate at the bottom, put
it back without the maintenance claim.**

**The placeholder rows stopped apologising twice.** Three listings carry
"Please verify before visiting" in `hours` and "Please verify directly with the
clinic / with the establishment / directly" in `phone`: four wordings of one
idea, two of them stacked in a single row, none actionable. `isUnverified()` in
`lib/directory.ts` now recognises that family, and `unconfirmedNote()` in
`directory-list.tsx` says it once and points somewhere useful:

| Data | Row now shows |
| --- | --- |
| No hours, no number (South Metro, Paw Station) | "Hours and phone not confirmed. The map listing usually has both." |
| Real hours, prose number (Kaboochi) | the real hours, plus "Phone not confirmed. The map listing usually shows it." |

The underlying rows are unchanged; this is a render-time fix, so an admin
normalising the text later costs nothing.

**Service pills became a service line.** Eleven of nineteen listings have a
single service, so the pill was a lone bordered capsule restating the mark
beside it, and the four-service listings became a hedge of borders. Services now
render as `Veterinary / Grooming / Boarding / Pet Supplies` in muted text, with
the labels matching the active chip in navy semibold. That keeps the "why is
this in my results?" answer, drops a row of chrome and vertical space from every
listing, and leaves the mark to do the at-a-glance work. `ServiceTags` →
`ServiceLine`.

Smaller fixes:

- Disclaimer heading was "What this list is, and what it is not": shape with no
  content, so a heading-skimmer learned nothing. Now **"A listing here is not a
  recommendation"**, which is the fact itself.
- Hero body said the list was "gathered in one list", which describes the page
  to someone already looking at it. Replaced with the thing a first-time visitor
  actually wonders: **"Free to use, whether or not you are a MetroPaws member."**
- Search placeholder said "Search **a** name, service, or area" while its
  `sr-only` label said "Search **by**...". Both now say "by".
- Empty state dropped "a provider further out may simply not be listed yet" and
  the duplicated "see all 19" (the button says it).

Contrast re-measured after the change, through canvas colour parsing (Chromium
returns `oklch()` unconverted, so a naive `getComputedStyle` regex reports
garbage): `--color-ink-muted` on cream is **6.02:1** at 14px, so the count line,
service line, unconfirmed note, and addresses all pass AA. Touch targets stayed
at 0 undersized across 320 / 390 / 844x390 / 768x1024, desktop rows still reach
to 16px of the container edge, no horizontal overflow at 1440 / 834 / 390.

### Phone reach pass, 2026-08-08 (`/impeccable adapt clarify`)

The earlier device pass fixed touch targets and landscape. It never measured
**how far down the page the first listing sits in portrait**, which is the thing
that matters on a page people open when a pet needs care.

| Device | First listing was | After this pass | Viewport |
| --- | --- | --- | --- |
| Galaxy Fold, closed (280px) | 986px | 794px | 653px |
| iPhone SE (375px) | 872px | 728px | 667px |
| Pixel 7 (412px) | 815px | 668px | 915px |
| iPhone 15 Pro Max (430px) | 815px | 668px | 932px |

**Superseded** by the disclosure change below, which took these to 688 / 643 /
583 / 583. The reasoning here still stands; only the figures moved on.

So a Pixel 7 and a 15 Pro Max now show the first listing without scrolling, and
an SE is one short scroll instead of 1.3 screens. Where it came from, measured
per block rather than guessed:

- **The disclaimer's bordered panel is now `lg:` only.** Below `lg` it is a
  hairline rule and flowing text: same words, same position, same prominence,
  but it stops spending 40px of padding plus a border to fence off the only
  thing in its column. Worth 64px on a phone and it reads as part of the hero
  instead of a legal box bolted to it. Desktop is pixel-identical.
- Hero padding `pt-12 pb-11` → `pt-8 pb-7`, control band `pt-7 pb-11` →
  `pt-5 pb-6`, results `pt-8` → `pt-6`, hero gap `gap-8` → `gap-6`, control gap
  `gap-4` → `gap-3`. All phone-only; every `md:` value is untouched, so desktop
  keeps the rhythm `DESIGN.md` asks for.
- The `max-height:540px` landscape overrides became `md:`-scoped, since the
  portrait base is now tighter than what they were setting. Landscape still
  improved (586px → 545px).

**The search placeholder was clipped on the commonest small phones.** At 16px
(the size touch gets, so iOS does not zoom on focus) "Search by name, service,
or area" needs 255px and an iPhone SE gave the field 247px, a folded Galaxy
152px. Two fixes: the placeholder drops the "Search by" that the magnifier icon
already conveys (the `sr-only` label keeps the full phrase), and the field only
reserves right padding for the clear button **when there is one** to clear.
Holding 40px open for an unrendered control was most of the deficit. Now 175px
needed against 180 / 275 / 312px available at 280 / 375 / 412px.

**The eyebrow read "Around Las Piñas" and the paragraph two lines below said
"around Las Piñas".** The eyebrow now names what the list is, "Community
directory", which keeps `DESIGN.md`'s eyebrow pattern, drops the repetition, and
sets the non-endorsement frame before the disclaimer has to argue for it.

Re-verified: 0 touch targets under 44px at 320 / 390 / 844x390 / 768x1024, no
horizontal overflow at 280 through 2560, desktop rows still reach to 16px of the
container edge, all 19 marks on one left edge, `--color-ink-muted` on cream
still 6.02:1.

#### The filter chips: two answers, chosen by input method

The five chips measure **678px**. Everything below that width scrolled
horizontally, which meant **3 of 5 filters were off-screen on an iPhone SE and a
folded Galaxy**, 2 on a Pixel 7 and on a narrow desktop window. On a 19-item
list the chips are the primary navigation, so this was not cosmetic.

Wrapping everywhere was measured and rejected: at 375px the chips wrap to
**three** rows (148px, against 48px for the scroller), because "Veterinary 10"
alone is 151px with its glyph. Dropping the glyph to make wrapping cheaper was
also rejected: the chip is where the row mark gets its caption, so removing it
on phones would break the vocabulary exactly where the marks do the most work.

So the split is by **pointer type, not width**, consistent with the device pass
above:

- **Coarse pointer (touch)** keeps the scroller. Swiping a filter row is a
  learned gesture and it costs one row instead of three. What it lacked was a
  cue, so the row now carries a `mask-image` fade on **only the side that has
  more to reach**: right-only at the start, both edges mid-scroll, left-only at
  the end. Driven by a scroll handler plus a `ResizeObserver`, so rotating the
  phone re-evaluates it. No mask renders until hydration, and a mask does not
  affect layout, so there is no shift.
- **Fine pointer (mouse)** wraps. A mouse has no swipe: on a narrow desktop
  window the scroller became a scrollbar to drag with Pet Stores and Boarding
  simply out of reach. Verified: 547px mouse → 2 rows, 0 off-screen, no
  scrollbar; 375px mouse → 3 rows, 0 off-screen; 768px+ → 1 row, nothing wraps.

Touch reach figures above are unchanged by this, since touch still gets one row.

#### The disclaimer became a disclosure, 2026-08-09 (client call)

The client looked at the page on a phone and said the first screen was all
header and preamble with no list, which the measurements agreed with: the first
listing sat at **724px on a 667px viewport**, and the disclaimer was 144px of
that, the second-largest block on the page.

It could not simply move: it is the one element here with consequences, and the
build deliberately put it above the listings so a member who has a bad visit has
already read that MetroPaws did not vouch for the business. Moving it also
saves almost nothing, since it costs 144px wherever it sits. **Shortening was
the only real lever.**

It is now a native `<details>`. Visible at all times is the operative sentence,
"**A listing here is not a recommendation.** Confirm hours and fees before you
go." Folded away is the precise wording (accreditation / endorsement /
agreement, the Partner exception), which elaborates rather than warns.

`<details>` rather than a client component: it needs no JavaScript, survives a
failed hydration, is keyboard-operable for free, and keeps the full text in the
DOM for screen readers and for the record. **Verified with JavaScript disabled**:
the toggle still opens, 89px to 238px, with the legal text present.

| Device | Was | Now | Viewport | First row visible |
| --- | --- | --- | --- | --- |
| Pixel 7 (412px) | 815px | **583px** | 915px | 332px |
| iPhone 15 Pro Max | 815px | **583px** | 932px | 349px |
| iPhone SE (375px) | 872px | **643px** | 667px | 24px |
| Galaxy Fold (280px) | 986px | **688px** | 653px | 0px |

The hero intro also lost "member or not": "everyone" already carries it, and the
sentence was running to a third line on a 375px phone to say it twice.

**A Fold still shows no listing above the fold** (688px against 653px). The
remaining blocks are the site header at 100px and the control band at 145px,
neither of which is a directory-level decision. Not pursued.

#### Polish pass, 2026-08-09

Three real defects, found by inspecting at 3x rather than by reading the page at
1x:

- **"View on map" had a broken underline.** The anchor is `inline-flex` with a
  `gap`, and a flex container paints `text-decoration` under each flex item
  separately, so the underline stopped at the gap and reappeared under the
  arrow, reading as two links. The underline now lives on a span around the
  label; the anchor is `no-underline` and the arrow, being an affordance rather
  than link text, carries none.
- **The chip row drew a scrollbar.** Phones draw an overlay one that fades by
  itself, but a desktop-class scrollbar renders as a permanent grey bar slicing
  the control band. `scrollbar-none` (verified to resolve to
  `scrollbar-width: none`, not silently no-op), and the `pb-1` that had been
  reserved for it is gone, which also returns 4px to every phone.
- **The service separator could begin a line.** At 280px "Veterinary / Grooming
  / Boarding / Pet Supplies" wrapped onto a line starting with "/". A
  non-breaking space before the slash moves the break to after it.

**Three things that looked like defects and were not.** Recorded so nobody
"fixes" them later:

- "19 places" appears two-toned in screenshots. It is a single text node with a
  single colour (`childNodes: 1, elementChildren: 0`); the split is JPEG
  compression around the numeral.
- The address and hours icons look indented relative to the listing name. The
  boxes align at exactly **88px**; the offset is lucide's glyph inset inside its
  own 14px box. Nudging individual glyphs would be over-tuning that breaks the
  moment an icon is swapped.
- `transitionDuration` still reads 0.15s under `prefers-reduced-motion: reduce`.
  That is the wrong property to measure: `transition-none` sets
  `transition-property`, which correctly computes to `none` on the row, chip,
  mark, and arrow. Nothing transitions.

Also confirmed at 390px: 0 console or hydration warnings, focus rings on
**47/47** interactive elements, cumulative layout shift **0.0000**, keyboard
focus scrolls the last chip into view, and the longest listing renders at 280px
with 0 overflowing elements.

**Still open, needs a brand decision.** At 280px, 15 of 19 listing names wrap to
two or more lines, because the page gutter is `px-6` (48px of a 280px screen) on
every section. Dropping to `px-4` below `sm` would buy 16px back for every row,
but `SiteHeader` and `SiteFooter` set their own gutters, so changing this page
alone would misalign the logo with the content edge. That is a site-wide change,
not a directory one.

### Site-wide eyebrow contrast — CORRECTED 2026-08-09, the old table was wrong

**The figures previously recorded here were wrong, and their conclusions were
backwards.** Re-measured from the live tokens, resolving `oklch()` through a
canvas (Chromium returns `oklch()` unconverted, so a naive `getComputedStyle`
regex yields garbage; that is the likely source of the original error):

`--color-gold` resolves to `rgb(200, 157, 72)`, `--color-navy` to
`rgb(14, 31, 57)`.

| Gold text on | Previously recorded | Actually | AA at 14px semibold |
| --- | --- | --- | --- |
| `--color-navy` | 3.52:1, fails | **6.57:1** | **passes** |
| `--color-cream` | 4.80:1, passes | **2.31:1** | **fails badly** |
| `--color-cream-warm` | 3.93:1, fails | **2.10:1** | **fails badly** |

Two other figures in the contrast section above were also wrong: navy on
`--color-gold` (the partner badge) is **6.57:1**, not 3.52:1 (contrast is
symmetric, so it is the same pair), and cream on `--color-gold-deep` is
**5.11:1**, not 12.52:1. Both still pass; only the numbers were off.

**The practical implication is the opposite of what was recorded.** A gold
eyebrow on **navy is fine**. A gold eyebrow on **cream or cream-warm is the
real failure**, at roughly 2:1. Anyone who had "fixed" this by following the old
table would have moved eyebrows onto cream, which is the worst ground for them.

This page is unaffected either way: its only eyebrow ("Community directory")
sits on navy at 6.57:1, and the one gold-on-cream use is `--color-gold-deep` in
the empty state, which measures 5.02:1 and passes. **The site-wide audit of the
23 eyebrow instances still needs doing, but against these numbers, not the old
ones**, and the question is now "which of them sit on cream", not "all of them
fail".

## The page shipped broken in production, 2026-08-10 — and why

The client opened `/find-pet-care` on prod and got "The directory is not loading
right now" while `/admin/directory` listed all 19 rows. The page was not
half-working; it had been serving that error state to every visitor.

Nothing was wrong with the data or the API. Measured at the time:

| Check | Result |
| --- | --- |
| `GET /directory` on prod | **200, 19 rows, 0.3s** |
| `https://metropaws.ph/find-pet-care` | `X-Nextjs-Prerender: 1`, `X-Vercel-Cache: HIT`, `Age: 3070` |
| Listings in that HTML | **0** |

So the failure was baked into a **cached prerender**. The chain:

1. The backend is on **Render's free plan** — it spins down after ~15 min idle
   and a cold start takes 30–60s (`backend/docs/HOSTING_AND_DATA_SAFETY_RECOMMENDATION.md`).
2. `PUBLIC_CONTENT_TIMEOUT_MS` was **5000**. No 5s ceiling survives that.
3. A page with `revalidate: 3600` regenerates in the **background**, triggered by
   a visitor arriving after the window closes — typically long after the last
   member closed the app, so the regenerating request is the one that has to wake
   the container. It timed out.
4. The render still *succeeded* — it returned `DirectoryUnavailable` — so Next
   cached that HTML as the page and served it for the next hour. **A failure to
   fetch became the published page.**
5. The next regeneration found the backend asleep again. Steady state: broken.

**The "no hardcoded fallback" decision above did not cause this, but it is why
this page is where the bug became visible.** The same timeout was failing
site-wide; the homepage was quietly serving its six hardcoded fallback FAQs
instead of the ten the client wrote in admin (verified: prod `/faqs` returns
"Why Join MetroPaws?", the live HTML contained "Is MetroPaws free?"). A fallback
hid the fault everywhere else, which is how it survived QA — every page looked
populated.

### What changed

- **`lib/public-content.ts` now makes two attempts**, 5s then 25s, behind one
  `fetchPublicContent(path)` used by the directory, FAQ, and plan fetchers (which
  also dropped three copies of the `BACKEND_URL` constant). The first attempt
  keeps a warm backend fast and doubles as the alarm clock; the second rides out
  the cold start it just triggered. A 4xx/5xx is not retried — that is an answer,
  not a sleeping container. Nobody waits on this: a background regeneration keeps
  serving the previous page while it works.
- **A failure no longer renders a dead end.** `app/api/directory/route.ts` is a
  same-origin route (`maxDuration = 60`) and `components/directory-recovery.tsx`
  calls it on mount whenever the server render came back empty-handed. The
  visitor gets the real listings even while the cached HTML says otherwise, and
  the wake-up means the next regeneration lands on a backend that is already up.
  A successful call also populates the shared fetch cache, so the page can
  re-prerender correctly whether or not the backend is awake at that moment.
- The route returns **503 with `Cache-Control: no-store`** on failure, and
  `s-maxage=300` on success so one wake-up serves everyone arriving in the next
  five minutes rather than each visitor starting the container.
- `DirectoryUnavailable` gained a **"Try again"** button (the retry moved from a
  sentence asking the visitor to come back later into one tap) and the loading
  state **says the wait can take up to a minute** — an unqualified spinner tells
  someone whose pet needs a vet to give up at five seconds.

The prerendered success path is unchanged: when the fetch works, the HTML ships
with all 19 listings, no client fetch, no spinner, nothing for a crawler to miss.

### Verified 2026-08-10

Against a stub backend seeded with the real prod payload, plus a final build
against prod itself:

| Scenario | Result |
| --- | --- |
| Backend answers in 12s (past the old 5s ceiling) | **19 listings prerendered**; stub log shows the abort at 4.8s and the retry succeeding at 12s |
| Build against prod backend | `/find-pet-care` prerenders 19 listings + "19 places"; homepage prerenders the **real DB FAQs**, not the fallback |
| Page prerendered from a failure, backend then reachable | `GET /api/directory` → 200, 19 rows, `s-maxage=300` — the heal path a visitor's browser takes |
| Backend down, no cached data | `GET /api/directory` → **503, `no-store`** — a failure is never cached |
| Backend down at build | Page prerenders the recovery state, not a dead end |

`npx tsc --noEmit` clean, `next build` clean, ESLint clean on all eight touched
files. `/find-pet-care` is still `○` static with the 1h window; `/api/directory`
is `ƒ` dynamic.

### This is a mitigation, not the cure

The cure is the backend not sleeping. The hosting doc already recommends Render's
paid Starter plan (~US$7/mo) and this is the second feature to be bitten by the
free plan's spin-down. Until that happens, a visitor who arrives while the
container is cold and the cached page is a failure waits on the heal fetch —
correct, but up to ~25s. **Do not "solve" that with a keep-alive ping:** the free
plan's 750 monthly instance-hours barely covers one always-on service (~730h),
so pinging it awake would spend the entire allowance and risk taking the API down
outright.

## Also found during QA, NOT fixed (pre-existing, site-wide)

**`SiteHeader` breaks between roughly 768px and 900px.** The desktop nav appears
at `md:` (768px) but does not fit: the logo collides with "About", "Get the App"
wraps to three lines, and "Sign up" is clipped off the right edge (the CTA
cluster measures to x=861 inside an 834px container). Verified identical on
`/getting-started` and `/about`, so it predates this feature and affects every
page. The likely fix is moving the desktop nav to `lg:` so tablets get the
hamburger, but that changes the header everywhere and is a design call.

## Deploy checklist

1. **`directory_providers` already exists on PROD** — created accidentally on
   2026-08-08 when `main.py` was imported locally while `.env` pointed at prod
   (`create_all` runs at import). Empty table, additive, nothing else touched.
   No action needed, but do not be surprised to find it there.
2. Deploy the backend image (`.\deploy.ps1`) — new router, no new env vars, no
   `migrate.py` entry (new table, so `create_all` handles it).
3. Run `python seed_directory.py` against **prod** (dev is already seeded with
   all 19, all `is_partner=false`).
4. Deploy the website. `/find-pet-care` is statically prerendered with the
   standard 1h ISR window; admin edits purge it immediately via
   `revalidateAdminAndPublic`.

**Local gotcha:** Next persists its fetch cache in `.next/cache/fetch-cache`
across builds, so a rebuild can prerender `/find-pet-care` from stale data.
`rm -rf .next/cache/fetch-cache` before rebuilding when testing data changes.

## Verified on dev (2026-08-08)

- Public `GET /directory` returns only published rows, partners first then A→Z,
  and carries no payout fields.
- Admin create / partial update / delete; 422 on an unknown service slug, 404 on
  a missing id, 401 without a token.
- Browser end-to-end: create through the dialog → appears on `/find-pet-care`;
  unpublish → disappears; delete → gone. Confirms `revalidatePath` reaches the
  public page.
- Accent-insensitive search ("las pinas" matches "Las Piñas"), filter chips,
  empty state, and the generated Maps URL for a listing with no `map_url`.
- `npx next build` clean; no console errors and no horizontal overflow at
  1440 / 834 / 390px.

## Decisions taken 2026-08-08

- Public URL is **`/find-pet-care`**, not `/directory`.
- **All 19 seed rows ship as community listings** (`is_partner = false`). The
  badge exists in admin for the day a real partnership is signed; until then no
  partnership claim is made that isn't true.
