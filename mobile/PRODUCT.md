# MetroPaws Mobile — Design Context

> Synthesized from codebase exploration + project design brief. Referenced in `CLAUDE.md`.
> Update this file whenever brand or design direction evolves.
> The core brand (colors, typography, principles) matches the project-level `.impeccable.md`.
> This file extends it with Flutter/mobile-native specifics.

---

## Design Context

### Users

**Members** — Filipino pet owners, broad age range (20s–50s), mixed digital comfort levels. This is a native mobile app — they are always on their phone, often at the clinic waiting area or casually at home. Their emotional state is caring and invested. The job to be done: _quickly check my pet's status, show my QR ID, and feel confident in the system._

**Admins (Receptionists)** — Clinic front-desk staff on tablets or phones. Fast-paced, transactional context. The job to be done: _scan a member QR fast, verify their pet, deploy the right service without mistakes._

### Brand Personality

**Premium · Warm · Trustworthy**

Voice: Confident and warm — like a private members' club that also loves animals. Not cold luxury (no sterile minimalism). Not generic fintech. The tone says: _"You and your pet deserve this."_

Emotional goal for members: _pride and belonging_ — "This feels premium and it's mine."
Emotional goal for admins: _authority and speed_ — "I can trust this; it looks legitimate."

**Reference aesthetic — The Physical Membership Kit:**
The design DNA comes directly from the MetroPaws membership unboxing kit: a navy gift box with cream linen interior, gold-foil embossed shield logo, three physical membership card tiers (Standard / De Luxe / Premium), and a gold pet ID tag. The app is the **digital twin** of this physical premium membership experience. Every screen should feel like you're holding that black card.

**Reference brand:** AmEx Black Card meets Grab Philippines — prestige visual language made warm and Filipino-native. Premium without being cold or unapproachable.

### Aesthetic Direction

**Theme:** Light, Dark, and System (device default). System is the default — the app follows the phone's appearance preference. Users can override via Account settings. All three modes maintain full brand fidelity. Spacious, breathing layouts. High contrast for readability across age ranges.

**Visual tone:** Premium and warm. Navy + gold is the only palette — used with deliberate restraint. Gold signals prestige and high-value moments. Navy signals trust and structure. White/light surfaces carry breathing room. Nothing extra. Nothing generic.

**The "Black Card" principle:** The MetroPaws Premium membership card is a near-black card with gold accents. The app's dark mode — and especially the Premium member experience — should evoke this physical card: deep dark surface, gold text for names/labels, gold border or shimmer on the hero card widget.

**Anti-references:**

- Generic fintech / banking apps (cold, corporate, grey gradients)
- Sterile medical / clinic apps (white deserts, clinical blue, no personality)
- Cold charcoal/slate dark modes that lose the navy brand warmth
- Cheap-looking gold (yellow or neon) — MetroPaws gold is `#B89A3E`, a deep antique gold

**⚠️ Mockup Override Rule:** If reference mockups feature glowing effects, gradient text, or any palette outside the design tokens below — **ignore that styling**. Translate into the correct mode's token set. Dark mode layout from mockups is now a valid reference — but still apply the brand token mapping, not the mockup's raw colors.

**Imagery:** Real dogs and cats. No cartoon mascots unless used as micro-illustrations.

### Design Tokens (Flutter equivalents)

```dart
// ── Light Mode ─────────────────────────────────────────────────────────────
const navy       = Color(0xFF263258); // Primary — CTAs, branding, trust signals
const gold       = Color(0xFFB89A3E); // Accent — highlights, joy moments
const surface    = Color(0xFFF8F7F4); // Scaffold background — warm near-white
const textColor  = Color(0xFF1A1E32); // Body text — near-black navy, high contrast
const navyLight  = Color(0xFFEEF0F8); // Chip backgrounds, subtle fills
const goldLight  = Color(0xFFFBF6E9); // Soft gold fills, warning surfaces
const grey       = Color(0xFF8B8FA8); // Secondary/muted text, placeholders, hints
const greyLight  = Color(0xFFE8EAF2); // Borders, dividers, input fills
const white      = Color(0xFFFFFFFF); // Card fills, input fills

// ── Dark Mode ──────────────────────────────────────────────────────────────
// Deep navy-tinted darks — brand warmth preserved, not cold grey
const darkBg       = Color(0xFF0D1220); // Scaffold background — very deep navy
const darkSurface  = Color(0xFF161C2E); // Cards, sections (first elevation)
const darkElevated = Color(0xFF1F2740); // Elevated cards, bottom sheets (second elevation)
const darkBorder   = Color(0xFF2C3452); // Borders, dividers
const darkText     = Color(0xFFEEF0FB); // Primary text — near-white with navy tint
const darkSubtext  = Color(0xFF8890B4); // Secondary/muted text, placeholders
const darkNavyChip = Color(0xFF263258); // navy as chip/tag bg (contrast on darkSurface)
const darkGoldBg   = Color(0xFF261E08); // goldLight equivalent — very dark warm gold
// navy, gold — unchanged; they pop on dark backgrounds

// ── Semantic Mapping (light → dark) ────────────────────────────────────────
// surface      → darkBg         (scaffold)
// white        → darkSurface    (cards, input fills)
// navyLight    → darkElevated   (chip/section bg)
// goldLight    → darkGoldBg     (gold surface tints)
// greyLight    → darkBorder     (borders, dividers)
// text         → darkText       (primary text)
// grey         → darkSubtext    (secondary text)
// navy         → navy           (CTAs, hero cards — unchanged)
// gold         → gold           (accents — unchanged)

// ── Typography — CANONICAL FONT: Montserrat only ───────────────────────────
// Loaded via google_fonts package
// ExtraBold (w800) — display/hero, SemiBold+ numbers and stats
// Bold (w700) — section headings
// SemiBold (w600) — labels, UI copy, buttons
// Regular (w400) — body, paragraph text
// ⚠️ Note: Earlier CLAUDE.md drafts referenced Baloo 2 + Bai Jamjuree — those are INCORRECT.
//    Montserrat is the sole font. CLAUDE.md has been corrected.
```

**Font weight guidance:**

- Display / hero text: `FontWeight.w800` (ExtraBold)
- Section headings: `FontWeight.w700` (Bold)
- Labels / UI copy: `FontWeight.w600` (SemiBold)
- Body / paragraph: `FontWeight.w400` (Regular)
- Minimum readable size: 12sp for captions, 14sp for labels, 16sp for body

---

### Typography Mandate — Go Big and Bold

> **The single most powerful design lever in MetroPaws is type size and weight.** Premium feel is achieved through confident, oversized display text — not decoration, not gradients, not added components.

**The rule: every screen must have one text element that feels shockingly large.** If the heading looks "about right," it is probably too small. When in doubt, size up.

**Mandatory minimums — non-negotiable:**

| Element | Min size | Min weight | Note |
|---------|----------|------------|------|
| Screen / page title | 28sp (`displaySmall`) | Bold 700 | Never use `titleLarge` (18sp) as a screen heading |
| Pet name (any context) | 28sp (`displaySmall`) | ExtraBold 800 | Pet name IS the hero — own the screen |
| Key numbers (sessions, QR) | 36sp (`displayMedium`) | ExtraBold 800 | Numbers must command the eye |
| QR card pet name | 36sp (`displayMedium`) | ExtraBold 800 | The "black card" moment — go bigger |
| Section headings | 20sp (`headlineSmall`) | Bold 700 | |
| Hero / splash text | 48sp (`displayLarge`) | ExtraBold 800 | |

**Contrast ladder — always maintain a dramatic size jump between levels:**

```
Screen title    36–48sp  ExtraBold (800)  ← commands the page
Section head    24–28sp  Bold (700)       ← clear structural break
Sub-label       16–18sp  SemiBold (600)   ← readable grouping marker
Body copy       14–16sp  Regular (400)    ← recedes into background
Metadata        11–12sp  Medium (500)     ← barely-there detail
```

Adjacent hierarchy levels must differ by **at least 8sp**. Never place a 20sp heading above 18sp body — the hierarchy collapses.

**The three commandments:**

1. **Size IS the hierarchy** — never rely on color, weight, or spacing alone to differentiate levels. Two different roles = at least 8sp size difference.

2. **ExtraBold (800) is reserved for the most important text on the screen** — one or two elements maximum. Everything else steps down. Using ExtraBold everywhere destroys its signal.

3. **Never shrink text to fit a container** — reflow the layout, wrap to a second line, or truncate with `TextOverflow.ellipsis`. Reducing font size to make text fit is prohibited — it flattens the hierarchy and reads generic.

**Visual checkpoint after building any screen:**
- Does one text element visually dominate? If not, something is wrong.
- Is the primary heading at least 2–3× the size of body text? If not, scale up.
- Does it feel like a luxury membership card, or a clinic form? If the latter: add size.

---

### Mobile Typography — Premium Hierarchy Scale

**Type scale (use `Theme.of(context).textTheme` — never hardcode sizes):**

| Role | Size | Weight | `textTheme` key | Usage |
|------|------|--------|-----------------|-------|
| Display hero | 48sp | ExtraBold (800) | `displayLarge` | Full-bleed splash / onboarding |
| Display section | 36sp | ExtraBold (800) | `displayMedium` | Screen-level headings, pet name on QR card |
| Headline | 28sp | Bold (700) | `displaySmall` | Dashboard section openers, card titles |
| Title | 24sp | Bold (700) | `headlineMedium` | Sub-section heads, modal titles |
| Subtitle | 20sp | Bold (700) | `headlineSmall` | Card sub-heads, group labels |
| Body large | 16sp | Regular (400) | `bodyLarge` | Primary reading text |
| Body medium | 14sp | Regular (400) | `bodyMedium` | Secondary descriptions, captions |
| Label | 14sp | SemiBold (600) | `labelLarge` | Buttons, input labels, badges |
| Micro | 12sp | Medium (500) | `labelSmall` | Timestamps, metadata, member ID |

**Premium hierarchy rules — non-negotiable:**

1. **Go big on hero text.** Pet names, screen titles, and key numbers (sessions remaining, QR card intro) use `displaySmall` (28sp) minimum — never `titleLarge` (18sp). Size IS the hierarchy signal.
2. **Pair extreme weight contrast.** An ExtraBold 36sp heading next to Regular 14sp descriptor reads luxurious. Never pair adjacent sizes that differ by only 2–4sp.
3. **Let text breathe.** Large type needs proportionally generous surrounding whitespace. A 36sp heading cramped in a card reads cheap; the same heading with 16px+ padding reads premium.
4. **Gold on key numbers.** Sessions count, membership tier badge, and pet name on the QR card use `AppColors.gold` at display size — anchors the emotional highlight of the screen.
5. **Never shrink headings to fit.** Reflow the layout, truncate with `TextOverflow.ellipsis`, or wrap to two lines. Reducing font size to make text fit destroys hierarchy and looks generic.

**Spacing rhythm:** 4px base unit. Cards use 16–20px padding. Screen edges use 16–20px horizontal padding. Generous — never crowded.

**Border radius:**

- Cards / containers: `BorderRadius.circular(16)` (rounded-2xl equivalent)
- Buttons: `BorderRadius.circular(12)` (rounded-xl equivalent)
- Chips / tags / avatars: `BorderRadius.circular(100)` (rounded-full)

**Elevation:** Subtle only. Cards at rest: `elevation: 2` with soft shadow. Primary CTAs: slightly more prominent. No harsh drop shadows.

**Touch targets:** Minimum 44×44px for all interactive elements — non-negotiable for the broad age range.

**Gold CTA rule:** For high-value / premium actions use a **gold-fill button with dark text** instead of the navy button:
- "Deploy Service" (Admin) → gold fill, `AppColors.text` label
- "Show QR / Digital Pawprint" reveal → gold fill
- Primary CTA on Premium member screens → gold fill
- Standard form actions (Login, Register, Save) → navy fill (unchanged)

This mirrors the physical "Gold pen" / "Gold seal" treatment — gold marks moments that matter.

### Premium Membership Tier System

Three visual tiers match the physical membership cards. Every component that surfaces the member's tier (hero card, QR card, Club tab) MUST apply the correct tier treatment.

| Tier | Physical Card | App Surface | Text / Icon Color | Border / Accent |
|------|--------------|-------------|-------------------|-----------------|
| **Standard** | Silver/light card | `white` (light) / `darkSurface` (dark) | `AppColors.text` / `darkText` | `greyLight` border |
| **De Luxe** | Dark metallic card | `Color(0xFF1A1F35)` — dark steel navy | `Colors.white` | `Color(0xFF8A9BC8)` — steel blue shimmer |
| **Premium** | Black card with gold | `Color(0xFF0D0E16)` — near-black | `AppColors.gold` — gold text | `AppColors.gold` with `0.4` opacity glow |

**Tier detection:** Read `member.planType` from the backend. Expected values (case-insensitive match): `"Standard"`, `"De Luxe"` / `"Deluxe"`, `"Premium"`.

**Tier badge component:** A small pill chip displayed on hero cards and the Club tab:
- Standard: `greyLight` bg + `grey` text
- De Luxe: `Color(0xFF1A1F35)` bg + `Color(0xFF8A9BC8)` text
- Premium: `darkGoldBg` bg + `gold` text + thin gold border

**Member ID format:** `MP-XX-YY-ZZ-T` (e.g., `MP-AW-26-05-P` = Premium, `MP-BFR-26-04-S` = Standard). Display this on the Digital ID card widget beneath the member's name, in monospace or SemiBold 12sp.

### Digital ID Card (QR Card) Spec

The QR card on the Member Dashboard is the **"Digital Pawprint"** — the digital twin of the physical membership card. It must feel premium.

**Structure (top to bottom):**

```
┌─────────────────────────────────────────────┐
│  [MetroPaws shield icon]  METROPAWS          │  ← gold icon + gold label on dark surface
│  WELLNESS CLUB                               │
│                                             │
│  [Pet circular photo, 56px]                  │
│  LUNA                                        │  ← pet name, ExtraBold, gold on dark
│  Labrador · 3 yrs                            │  ← breed/age, white/60
│                                             │
│  ┌─────────────────────────────────────┐   │
│  │         [QR code, white bg]         │   │  ← white QR block inside card
│  │                                     │   │
│  └─────────────────────────────────────┘   │
│                                             │
│  DIGITAL ID CODE                            │  ← label, grey/60, 11sp
│  MP-AW-26-05-P                              │  ← member ID, SemiBold 12sp, gold
│  [● ● ● ○ ○]  3 of 5 sessions left         │  ← session dots (filled=used)
└─────────────────────────────────────────────┘
```

**Surface colours by tier:**
- Standard: white card with `greyLight` border
- De Luxe: `Color(0xFF1A1F35)` with steel blue border
- Premium: `Color(0xFF0D0E16)` with `gold.withOpacity(0.4)` border + subtle gold glow shadow

**QR block:** Always white background regardless of tier, with `BorderRadius.circular(12)`. Size: `min(screenWidth * 0.55, 220)`.

**Label beneath QR:** "Show this to clinic staff" → white/50 on dark, grey on light.

### Theme Mode Switching

**Three modes (user-selectable, stored in `flutter_secure_storage`):**

| Mode | Behaviour |
|------|-----------|
| `system` | Follows `MediaQuery.platformBrightness` — **default** |
| `light` | Always light, regardless of OS setting |
| `dark` | Always dark, regardless of OS setting |

**Implementation requirements:**

- Store the user's choice under a dedicated key in `AuthStorage` (or a sibling `ThemeStorage` service) — treat it like any other user preference
- Default value when no preference is stored: `system`
- Expose as a `ThemeMode` enum (`ThemeMode.system`, `.light`, `.dark`) and pass it to `MaterialApp.themeMode`
- `MaterialApp` must declare both `theme: buildLightTheme()` and `darkTheme: buildDarkTheme()` — Flutter resolves the correct one at runtime
- The theme picker UI lives in the Account tab — three options presented as a segmented control or radio list: "Light", "Dark", "System"
- Label the current active item; use a checkmark or filled indicator

**Code pattern for `main.dart`:**

```dart
MaterialApp(
  theme: buildLightTheme(),       // light ThemeData
  darkTheme: buildDarkTheme(),    // dark ThemeData
  themeMode: storedThemeMode,     // ThemeMode.system | .light | .dark
  ...
)
```

**Avoiding `AppColors` static constants in widgets:**

The existing `AppColors` class is a bag of light-mode `const` values. For dark mode to work correctly, widgets MUST NOT reference `AppColors.navy`, `AppColors.surface`, etc. directly for semantic purposes (backgrounds, text colors, borders). Instead:

- Use `Theme.of(context).colorScheme.primary` for navy/primary
- Use `Theme.of(context).colorScheme.secondary` for gold
- Use `Theme.of(context).colorScheme.surface` for card/section fills
- Use `Theme.of(context).colorScheme.onSurface` for body text
- Use `Theme.of(context).colorScheme.outline` for borders
- Use `Theme.of(context).colorScheme.surfaceContainerHighest` for elevated cards / `navyLight` fills

`AppColors` constants remain valid ONLY for brand-fixed colors that never adapt (e.g., the navy on a navy hero card background where navy is always used as the card fill regardless of mode, or the `gold` accent). When in doubt, use `Theme.of(context)`.

### Design Principles

1. **Pet as Hero** — Every member screen centers the pet: name, photo, breed, sessions. The human owner is supporting cast. This is non-negotiable in layout priority.

2. **The Digital Black Card** — The app is the digital twin of a premium physical membership kit. The member should feel like they're holding a luxury card, not using a clinic software. Every UI decision — dark surfaces, gold accents, the QR card design, tier badges — reinforces this premium membership identity. When in doubt, ask: "does this feel like a black card or a receipt?"

3. **Gold Marks What Matters** — Gold (`#B89A3E`) is reserved for premium signals and high-value actions: tier badges, pet names on the ID card, the "Deploy Service" CTA, session counters. Never use gold decoratively or for secondary content — it loses its signal value.

4. **Tier Comes Through Everywhere** — Standard, De Luxe, and Premium members have visually distinct experiences on the hero card, QR card, and Club tab. A Premium member opens the app and immediately sees the black card treatment. A Standard member sees a clean, warm card. Never flatten tiers to the same visual treatment.

5. **Delight All Moments, Especially These** — First pet added, QR display, and service deployed are the three highest-value emotional beats. Each deserves at minimum a joyful color treatment; ideally a micro-animation.

6. **Two Faces, One Brand** — Member UI: premium, celebratory, QR ID prominent, tier-differentiated, sessions visualized. Admin UI: dense, efficient, green "VALID MEMBER" confirmation on scan, gold "Deploy" CTA. Different densities, same brand DNA.

7. **Accessible Warmth** — Broad age range means minimum 44×44px tap targets, no low-contrast text, no critical information conveyed by color alone. Dark mode must maintain WCAG AA contrast — never dark-on-dark.

8. **Graceful Confidence** — Every error, empty, and loading state feels considered — never raw. Use amber/gold tone for warnings (not stark red). Always use the pet's name when available. Always offer a clear next action.

9. **Rich Motion Throughout** — The app should feel alive. Micro-interactions are non-optional. Key moments (first pet added, QR reveal, service deployed) deserve explicit celebration animations. All motion must respect `MediaQuery.disableAnimations`.

10. **Type as Hierarchy, Not Decoration** — Premium feel is achieved through confident typographic scale: large ExtraBold display text (28–36sp) paired with small Regular body text creates instant luxury without added visual noise. Use `displaySmall` or larger for pet names, session counts, and screen titles. Never use `titleLarge` (18sp) as a screen heading — it reads as a component label, not a premium statement.

### Motion & Animation Guidelines

**Philosophy:** Rich — micro-interactions throughout. The app should feel alive and responsive, not static.

**Standard interaction feedback:**

- Button tap: scale down to `0.97` on press, spring back on release (`Curves.easeOutBack`, 150ms)
- Card tap: brief scale `0.98` + subtle shadow increase
- List items: staggered `FadeTransition` + `SlideTransition` on first load (bottom-up, 60–80ms stagger)

**Screen transitions:**

- Route push: `SlideTransition` left-to-right (forward), right-to-left (back). Duration 280ms `Curves.easeInOutCubic`
- Modal sheets: bottom slide in, 300ms `Curves.easeOutQuart`

**Celebration moments (non-negotiable):**

- First pet added → confetti burst or animated gold checkmark, then auto-transition to pet profile
- QR ID reveal on dashboard → fade-in with subtle scale-up (QR code "appears" rather than just renders)
- Service deployed successfully (Admin) → green "VALID MEMBER ✓" stamp animation sweeps in, gold "DEPLOY" button flashes success, then auto-dismiss after 1.5s
- QR scan succeeds (Admin) → brief green ring pulse around QR frame, then "VALID MEMBER" badge slides down

**Loading states:**

- `CircularProgressIndicator` tinted navy (`AppColors.navy`)
- Skeleton shimmer for data-loading cards (grey-light bg, animated lighter shimmer sweep)

**Accessibility:** Always check `MediaQuery.of(context).disableAnimations`. When true, skip all transitions and show final state immediately.

---

### Admin Scanner Screen Spec

The admin side is used by clinic staff to scan a member's QR code and deploy services. Reference mockups show a two-state flow.

**Pre-scan state:** Clean camera viewfinder with a rounded scan frame, navy overlay outside the frame, brief instruction label below ("Scan member QR code").

**Post-scan — "VALID MEMBER" state:**
- Green `Color(0xFF22C55E)` banner at the top: shield-check icon + "VALID MEMBER" in ExtraBold white
- Member info card (white/darkSurface depending on mode):
  - Circular pet photo (64px) + pet name (ExtraBold) + tier badge
  - Member full name + member ID in grey
  - Services list with remaining session counts
- **"DEPLOY PSK SHIELD"** gold-fill button at bottom — `AppColors.gold` bg, `AppColors.text` (near-black) bold label, full width, 56px height
- On success: button transitions to green "Deployed ✓", auto-resets after 2s

**Invalid QR state:** Red `Color(0xFFEF4444)` banner: "INVALID QR" + retry button.

### Premium Copy & Vocabulary

Use these specific terms consistently — they reinforce the premium brand identity and match the physical materials:

| Physical term | Digital equivalent | Usage context |
|---|---|---|
| Digital Pawprint | The QR code / Digital ID | QR card label, marketing copy |
| PSK Shield | The service session | Deploy button, session counter |
| Black Card Protocol | Premium membership tier | Premium-tier UI labels |
| MetroPaws Wellness Club | Full club name | Club tab header, welcome screen |
| Member ID | `MP-XX-YY-ZZ-T` format code | Displayed under QR, account tab |
| Founding 50 | Early adopter badge | Special badge on hero card if applicable |

**Never use:** "credits", "points", "balance", "subscription". Always: "sessions", "plan", "membership", "shield".

---

### Tech Stack (Mobile)

- **Framework:** Flutter (Dart SDK ^3.11.5)
- **State Management:** BLoC (`flutter_bloc ^8.1.6`) — one BLoC per feature
- **Fonts:** Google Fonts via `google_fonts ^6.2.1` — `Montserrat`
- **HTTP:** `http ^1.2.0` via `core/services/api_service.dart`
- **Auth Storage:** `flutter_secure_storage ^9.2.2` — JWT token and role
- **Theme Preference:** stored in `flutter_secure_storage` under key `theme_mode` — values: `"system"` (default), `"light"`, `"dark"`
- **QR Display:** `qr_flutter ^4.1.0`
- **Icons:** Material Icons (`uses-material-design: true`)
- **Theme:** Defined in `lib/theme.dart` — exports `buildLightTheme()` and `buildDarkTheme()`

### Feature Structure

```
lib/
├── main.dart                     # App entry, MaterialApp (theme + darkTheme + themeMode), routing
├── theme.dart                    # ThemeData — buildLightTheme() + buildDarkTheme()
├── core/
│   ├── constants/api_constants.dart   # Base URL and endpoint strings
│   ├── models/                        # Pure Dart model classes (fromJson/toJson)
│   ├── services/api_service.dart      # All HTTP calls — single source of truth
│   ├── services/auth_storage.dart     # Secure token + role read/write
│   ├── services/theme_storage.dart    # Theme mode preference read/write (system/light/dark)
│   └── widgets/                       # Shared UI atoms: MpButton, MpTextField, PetAvatar
└── features/
    ├── auth/        # Login + Register screens + AuthBloc
    ├── member/      # Dashboard + Pet profile screens + MemberBloc
    └── admin/       # QR Scanner + Deploy service screens + AdminBloc
```

### Mobile Layout Guidelines

**Safe areas:** Always respect `SafeArea`. Use `MediaQuery.of(context).padding` for manual overrides.

**Scrolling:** Prefer `SingleChildScrollView` for short forms, `ListView.builder` for dynamic lists. Never hardcode heights that would clip on small screens.

**Keyboard avoidance:** Wrap forms in `SingleChildScrollView` with `resizeToAvoidBottomInset: true` on the `Scaffold`.

**Screen width:** Design for 375px minimum (iPhone SE / small Android). Do not hardcode widths — use `double.infinity` or `MediaQuery` proportions.

**Bottom navigation:** Not currently implemented. If added, use `BottomNavigationBar` with navy selected color and gold indicator.

---

## Website Design Reference

> Source: `metropaws/website/` — the live Next.js web app. These pages are the canonical visual reference for auth flows and brand expression. Mobile screens should mirror these patterns faithfully, adapted to native Flutter conventions.

### Shared Design DNA (Web → Mobile)

- **Font:** Montserrat throughout — same as mobile. ExtraBold (800) for hero headlines, Bold (700) for section headings, SemiBold (600) for labels/UI, Regular (400) for body.
- **Color tokens:** Identical to Flutter tokens. `--navy #263258`, `--gold #B89A3E`, `--surface #F8F7F4`, `--text #1A1E32`, `--navy-light #EEF0F8`, `--gold-light #FBF6E9`, `--grey #8B8FA8`, `--grey-light #E8EAF2`, `--navy-dark #1A2245`, `--error #D97706`, `--error-light #FFFBEB`.
- **Radius:** Cards = 16px (`rounded-2xl`), Buttons = 12px (`rounded-xl`), Pills/Chips = full (`rounded-full`).
- **Spacing:** 4px base. Card padding 16–20px. Screen edges 16–20px horizontal.

---

### Landing Page (`/`)

**Layout:**

- White nav bar with logo (left) + "Sign In" (outlined navy) and "Join Now" (navy filled) buttons (right).
- Full-bleed hero photo with `navy/25` overlay. White headline (ExtraBold), `/80` white subtext, gold CTA button ("Get Your Pet's QR ID →").
- Navy credibility strip: gold numbers + white/60 label text — "1,200+ pet families", "15 clinics", "4.9 ★".
- Features section on `surface` bg: lead card is navy full-bleed with `MemberCardMockup` on left + copy on right. Supporting features in white/gold-light cards.
- "Founding 50" section: navy bg with gold headlines, image panel right.
- "How it works" on white bg: large faded navy step numbers (01, 02, 03), bold headings.

**Member Card Mockup** (the digital ID card shown in marketing):

- White card, `rounded-4xl`, `shadow-2xl`, border `grey-light`.
- App bar: "My Pet ID" label (SemiBold, dark) + initials avatar (navy-light bg, navy text).
- Navy inner card: pet emoji avatar (white/20 bg) + name (ExtraBold) + breed/age (`white/65`).
- White QR block inside navy card, `rounded-xl`.
- Sessions indicator: row of small dots — white for used, `white/30` for remaining.
- Vaccination verified badge: navy-light bg, navy shield-check icon, small text.

**Mobile adaptation:** Use the member card mockup as the reference for the `MemberDashboard` QR card widget. Match the navy card → white QR block → session dots structure exactly.

---

### Login Page (`/login`)

**Layout (desktop):** Split panel — form panel (left, `surface` bg, flex-1) + photo panel (right, 40–50% width, `pet-care-login.jpg` with `navy/40` overlay + bottom quote overlay).

**Layout (mobile/phone):** Single column. A brand photo strip at the top (`h-36`, full width, `navy/55` overlay with bold white tagline at bottom-left), then form below.

**Form structure:**

1. Logo (links to home), `mb-8`.
2. `h1` — "Welcome back!" (ExtraBold, 30sp equivalent) + grey subtitle.
3. Email field → Password field (with show/hide toggle via Eye/EyeOff icons at right).
4. "Forgot password?" link — top-right of password label row, `text-xs`, grey, taps to `/forgot-password`.
5. Error state: `error-light` bg + `error/40` border + `⚠` icon prefix, `rounded-xl`.
6. "Sign In" button — full width, navy, white text, `rounded-xl`, `py-3.5` (≥44px).
7. "Don't have an account? Sign Up" — centered, grey text + navy bold link.

**Staff variant:** `?staff=1` query param changes heading to "Staff Sign In" and subtitle copy. Same form structure.

**Mobile adaptation (Flutter):** Auth screens should use the full-column mobile layout (no split panel). Top area: brand photo with navy overlay and tagline (can use a `Stack` with `Image` + `ColoredBox` + `Text`). Form scrollable below. Replicate field order, error state, and button style exactly.

---

### Register Page (`/register`)

**Layout:** Same split panel as login (photo panel uses `pet-care-register.jpg`). Mobile: same brand strip pattern.

**3-Step wizard** with a `StepDot` progress indicator:

- Dots connected by horizontal lines. Active dot: navy filled + white number. Done dot: navy filled + checkmark. Inactive dot: grey-light border + grey number.
- Line between steps transitions from `grey-light` → `navy` as steps complete.

**Step 1 — "Fur Parent Details":**

- First Name + Last Name in a 2-column grid.
- Email → Phone (with `+63` locked prefix, 10-digit PH number, validates `startsWith("9")`).
- Address (`textarea`, optional).
- Password (show/hide toggle).
- Error state (same pattern as login).
- Privacy Policy + Terms links (grey, xs, navy bold for links).
- CTA: "Next: Add Your Pet →" (navy, full width).
- Footer: "Already a member? Sign In".

**Step 2 — "Pet's Pawprint ID":**

- Pet Name (required), Species (optional), Breed, Age (years), Weight (kg), Notes.
- Pet photo upload: tappable area with preview, 5MB / JPG/PNG/WebP limit, clear error text.

**Step 3 — Vaccination Record:**

- File upload for vaccination card (JPG/PNG/PDF, 5MB), optional — can skip.
- CTA: "Finish & Go to Dashboard →".

**Success state:** Celebratory, no form visible. This is a key delight moment — use gold/warm treatment.

**Mobile adaptation (Flutter):** Implement the same 3-step flow in the `RegisterScreen`. Use a `Row` of step indicators at the top. Show one step's form at a time (not a `PageView` with swipe — use explicit "Next" to prevent accidental navigation). Match field order and validation rules exactly (phone `+63` prefix, 10-digit, starts with 9).

---

### Forgot Password Page (`/forgot-password`)

**Layout:** Centered single column, max-width ~375px, `surface` bg. Decorative dog cutout image (`opacity-20`) pinned to bottom-right corner — gives warmth without distraction.

**Request state:**

1. Logo (links to home, `mb-10`).
2. Key emoji (`🔑`) in a `gold-light` circle (`w-16 h-16`).
3. `h1` — "Reset your password" (ExtraBold, 24sp equivalent).
4. Grey subtitle: "Enter your email and we'll send you a link to set a new password."
5. Email field → error state → "Send Reset Link" button (navy, full width).
6. "Remember your password? Sign In" footer.

**Success state (after email sent):**

1. Mail icon in `gold-light` circle (replaces key emoji).
2. `h1` — "Check your inbox".
3. Subtitle confirms the email address in `font-semibold text-(--text)`.
4. Info box (`navy-light` bg, `rounded-2xl`): two tip rows — "💡 Tip: Link expires in 1 hour" + "📁 Check your spam folder."
5. "Back to Sign In" (navy filled) + "Try Another Email" (navy outlined) — stacked buttons.

**Mobile adaptation (Flutter):** Match the gold-light icon circle pattern for success/info states. The info box with tips is a useful pattern for any instructional/confirmation screen — use `navy-light` (`navyLight` token) bg with `rounded-16` container.

---

### Cross-Cutting UI Patterns (from Web → Apply in Mobile)

| Pattern                | Web implementation                                                      | Flutter equivalent                                                                                                    |
| ---------------------- | ----------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------- |
| **Text field**         | White bg, `grey-light` border, `navy` focus ring + ring/20 glow         | `InputDecoration` with `greyLight` border, `navy` `focusedBorder`                                                     |
| **Primary button**     | Navy bg, white bold text, `rounded-xl`, `py-3.5`, `disabled:opacity-60` | `ElevatedButton` navy bg, `BorderRadius.circular(12)`, min height 48px, `0.6` opacity when disabled                   |
| **Outlined button**    | `border navy`, navy text, `rounded-xl`                                  | `OutlinedButton` with navy `side` + navy text                                                                         |
| **Error state**        | `error-light` bg + `error/40` border + `⚠` icon + message               | `Container` with `goldLight` bg, amber border, `⚠` `Icon`, message `Text` — use `Color(0xFFD97706)` for error/warning |
| **Show/hide password** | Eye icon button at right edge of password field                         | `suffixIcon` `IconButton` with `Icons.visibility` / `Icons.visibility_off`                                            |
| **Logo**               | `logo-full.png`, `object-contain`, links home                           | `assets/images/logo-full.png` in an `Image.asset`, taps to home. Source: `updated-assets/Metro Paws Logo 13.04.2026 Curves-01 PNG.png` |
| **Step indicator**     | Dots + lines, navy filled = active, checkmark = done                    | Custom `Row` of `Container` circles + `Divider` lines; navy = active, grey-light = inactive                           |
| **Phone prefix**       | `+63` as a locked left label inside the field                           | `prefixText: '+63 '` in `InputDecoration`, grey prefix style                                                          |
| **Info/tip box**       | `navy-light` bg, `rounded-2xl`, emoji + text rows                       | `Container` with `navyLight` bg, `BorderRadius.circular(16)`, `Column` of `Row`s                                      |
| **Gold icon circle**   | `gold-light` bg circle, icon inside                                     | `CircleAvatar` with `goldLight` bg, icon child                                                                        |
| **Decorative image**   | Low-opacity pet photo, pinned corner, `pointer-events-none`             | `Positioned` `Opacity` widget with `Image.asset`, `IgnorePointer` wrapper                                             |

---

## Brand Assets

> **Source of truth:** `C:\Users\mario\Documents\mario\Projects\metropaws\updated-assets\`
>
> These are the **official, up-to-date brand files**. They supersede anything currently in `mobile/assets/images/`. When updating or adding assets, ALWAYS copy from `updated-assets/` — never rename or modify the originals.

### Logo

| File | Description | Flutter usage |
|------|-------------|---------------|
| `Metro Paws Logo 13.04.2026 Curves-01 PNG.png` | Primary logo — full color, transparent bg | Preferred for all in-app use. Copy to `assets/images/logo-full.png`. |
| `Metro Paws Logo 13.04.2026 Curves-02 PNG.png` | Secondary logo variant — alternate lockup | Fallback / alternate orientation. Copy to `assets/images/logo-alt.png`. |

**Logo usage rules:**
- On **navy backgrounds** (brand strip, QR card header): use the PNG with `color: AppColors.white` + `colorBlendMode: BlendMode.srcIn` to render white — or use the logo's own white-on-transparent version if available.
- On **light/surface backgrounds**: use the logo as-is (full color).
- Minimum display height: **40px** in content; **56px** for hero/onboarding; **120px+** for full-bleed brand strips.
- Never stretch or distort the logo.

### Hero / Background Images

| File | Description | Flutter usage |
|------|-------------|---------------|
| `Pet Care Dog.png` | Hero illustration — golden retriever, transparent bg | Onboarding, empty states, decorative pet illustration |
| `Pet Care with Text.jpg` | Hero photo with tagline text baked in | Avoid — text not adjustable; use `Pet Care No Text.jpg` instead |
| `Pet Care No Text.jpg` | Clean hero photo, no overlay text | Login/register background strip, onboarding hero |
| `Pet Care Story.jpg` | Story-format crop of pet care image | Social / story panels only — not for in-app use |

**Hero image usage rule:** Always use `Pet Care No Text.jpg` as the source for any in-app photo strip or background. Apply overlay and copy in Flutter — never rely on baked-in text from the `with Text` variant.

Copy destination: `assets/images/pet-care-login.jpg` (already referenced in code).

### Membership & Campaign Assets

| File | Description | Flutter usage |
|------|-------------|---------------|
| `Digital ID.jpg` | Physical Digital ID card — visual reference | Reference only — use as design mockup for the QR card widget |
| `Digital ID NO TEXT.jpg` | Digital ID without text overlay | Reference only |
| `Founding 50.jpg` | Founding 50 campaign hero image | Founding 50 badge / promotional section |
| `New Standard NO TEXT.jpg` | New Standard membership card — no text | Reference for Standard tier card design |

### Usage Checklist (copy before coding)

When building any screen that needs brand assets:

1. **Check `updated-assets/`** for the latest file — do not use anything directly from `assets/images/` without verifying it matches the source.
2. **Copy the file** from `updated-assets/` to `mobile/assets/images/` under its canonical name (see table above).
3. **Reference the canonical name** in Flutter code — never reference `updated-assets/` paths directly (they are outside the Flutter project boundary).
4. **Declare the asset** in `pubspec.yaml` under `flutter: assets:` if it is new.
