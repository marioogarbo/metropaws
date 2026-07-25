# Design System — MetroPaws

## Overview

Light mode only. Premium brand register. Montserrat throughout. Body text capped at 14px (text-sm). The palette pairs deep navy authority with muted gold restraint against a warm cream ground — not clinical, not loud, not imported SaaS.

---

## Color

### Strategy

**Committed** — deep navy carries 40-60% of every surface. Gold is a single intentional accent, used for primary CTAs, price figures, and section labels only. Cream is the ground. No teal. No generic blues. No white-on-white cards.

### Palette

```
--color-navy:        oklch(0.24 0.055 258)   /* Primary brand surface, hero, dark sections */
--color-navy-mid:    oklch(0.32 0.050 258)   /* Elevated navy panels, card backgrounds */
--color-gold:        oklch(0.72 0.115 82)    /* Primary CTA, accent labels, price figures */
--color-gold-muted:  oklch(0.65 0.090 82)    /* Secondary gold, subheadings in dark context */
--color-cream:       oklch(0.97 0.010 80)    /* Page background, section background */
--color-cream-warm:  oklch(0.94 0.015 75)    /* Slightly deeper cream for contrast panels */
--color-ink:         oklch(0.20 0.030 258)   /* Body text on light surfaces */
--color-ink-muted:   oklch(0.48 0.020 258)   /* Secondary text, captions, metadata */
--color-ink-faint:   oklch(0.72 0.010 258)   /* Dividers, placeholder text, disabled */
--color-surface:     oklch(0.99 0.005 80)    /* Navbar, card surfaces on cream ground */
```

### Usage rules

- Gold appears on: primary buttons, price numbers, section eyebrow labels, the "MOST POPULAR" badge, stat figures
- Gold never appears as: body text color, border color, decorative fills, icon fills
- Navy appears on: hero backgrounds, dark panel sections, featured pricing card, form backgrounds
- Cream appears on: page background, light section backgrounds, light pricing cards
- No `#000` or `#fff` anywhere — all neutrals are tinted toward the brand hue

---

## Typography

### Font

**Montserrat** — Google Fonts, weights 400/500/600/700. No system fallback reliance; load via `next/font/google`.

```tsx
import { Montserrat } from "next/font/google";

const montserrat = Montserrat({
  subsets: ["latin"],
  weight: ["400", "500", "600", "700"],
  variable: "--font-sans",
});
```

### Scale

Body text is capped at **14px (text-sm)**. Headings use the scale below for hierarchy, but are set in Montserrat 700. No size above the heading scale.

| Token        | Size       | Weight | Use                                      |
|--------------|------------|--------|------------------------------------------|
| `text-sm`    | 14px       | 400    | Body copy, list items, descriptions      |
| `text-sm`    | 14px       | 500    | Button labels, nav links, badge text     |
| `text-sm`    | 14px       | 600    | Form labels, table headers, callout text |
| `text-base`  | 16px       | 600    | Card subheadings, section eyebrows       |
| `text-xl`    | 20px       | 700    | Card titles, price amounts               |
| `text-2xl`   | 24px       | 700    | Section headings (mobile)                |
| `text-3xl`   | 30px       | 700    | Section headings (desktop)               |
| `text-5xl`   | 48px       | 700    | Hero headline (mobile)                   |
| `text-6xl`   | 60px       | 700    | Hero headline (desktop)                  |

### Rules

- Body line length: max 65ch on desktop, unconstrained on mobile
- Line height: `leading-relaxed` (1.625) for body; `leading-tight` (1.25) for headings
- Letter spacing: `tracking-tight` for headings; default for body
- Eyebrow labels: `text-sm font-semibold uppercase tracking-widest` in gold
- No italic anywhere in the UI
- No text decorations other than underline on inline links

---

## Elevation & Borders

### Philosophy

Elevation through color contrast, not drop shadows. Cards on cream use a 1px border; cards on navy use no border (color contrast is sufficient). No `box-shadow` on interactive elements except focus rings.

### Rules

- `border border-[--color-ink-faint]` — light surface cards
- No border on navy-background cards
- `ring-2 ring-[--color-gold]` — focus ring style
- No drop shadows for decoration
- Border radius: `rounded-xl` (16px) for cards, `rounded-lg` (12px) for buttons/inputs, `rounded-full` for badges

---

## Spacing

Spacing creates rhythm. Sections breathe. Cards don't crowd.

| Context                         | Token           |
|---------------------------------|-----------------|
| Section vertical padding        | `py-20 md:py-28` |
| Section inner container         | `max-w-6xl mx-auto px-6` |
| Card internal padding           | `p-8`           |
| Card gap in a grid              | `gap-6`         |
| Heading-to-body gap             | `mt-4`          |
| Body-to-CTA gap                 | `mt-8`          |
| Nav height                      | `h-16`          |

---

## Components

### Buttons

**Primary (gold)**: `bg-[--color-gold] text-[--color-navy] text-sm font-semibold rounded-lg px-6 py-3 hover:brightness-105 transition-all`

**Secondary (outline)**: `border border-[--color-ink] text-[--color-ink] text-sm font-semibold rounded-lg px-6 py-3 hover:bg-[--color-ink]/5 transition-all`

**Ghost**: `text-[--color-ink] text-sm font-medium hover:text-[--color-navy] transition-colors`

CTA buttons are full-width on mobile, auto-width on desktop. Never use rounded-full on CTA buttons (too casual for the premium tone).

### Pricing Cards

Three-column layout. Featured (Deluxe) card uses navy background with gold CTA. Flanking cards use cream with ink outline. Featured card is visually taller or lifted via padding, not shadow.

### Accordion (FAQ)

Minimal. Divider lines only — no card wrappers, no background fills on questions. Chevron icon rotates 180° on open. `transition-transform duration-200 ease-out`.

### Navbar

Sticky, white surface (`bg-[--color-surface]`), 1px bottom border in `--color-ink-faint`. Logo left. Nav links right. "Join Free" primary button. Collapses to hamburger at `md` breakpoint.

### Section eyebrows

`text-sm font-semibold uppercase tracking-widest text-[--color-gold]` — always above section headings. Short (2-4 words). Never a full sentence.

---

## Motion

- **Easing**: `ease-out` for all transitions. No bounce, no elastic, no spring.
- **Duration**: 150-200ms for micro-interactions (hover, focus). 250-300ms for reveals.
- **What moves**: opacity + translate-y for section reveals. Color transitions for hover states.
- **What never moves**: layout properties (`width`, `height`, `padding`).
- **Reduced motion**: wrap scroll reveals in `@media (prefers-reduced-motion: no-preference)`.

---

## Responsive Behavior

| Breakpoint | Behavior                                              |
|------------|-------------------------------------------------------|
| Mobile     | Single column. Full-width CTAs. Hero stacked layout.  |
| `md` (768px) | Two-column grids. Horizontal nav.                   |
| `lg` (1024px) | Three-column pricing. Hero side-by-side layout.   |
| `xl` (1280px) | Max container width locks. Increased section padding.|

Touch targets: minimum 44x44px on all interactive elements. Tap spacing between adjacent buttons: 8px minimum.

---

## Image Treatment

- Hero: full-bleed with `object-cover object-center`. Text overlay on left half (desktop), below image (mobile).
- Pet photos: warm, natural lighting. Never stock-photo generic. Always golden retriever or specific pet, never abstract "pet icon."
- Split-panel sections: image occupies 40-50% of the panel width; never cropped to a circle or decorative shape.

---

## What not to do

- No gradient text
- No glassmorphism
- No side-stripe colored borders on cards
- No teal, mint, or generic healthcare blue
- No identical-icon feature card grids
- No em dashes in copy (use commas, colons, or parentheses)
- No dark mode tokens or `.dark` variants
- No font sizes above the heading scale
- No body text larger than 14px (text-sm)
