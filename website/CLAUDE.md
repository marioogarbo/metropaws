# Project: MetroPaws Website

## Tech Stack

- **Framework**: Next.js 15 (App Router, Turbopack)
- **Language**: TypeScript
- **Styling**: Tailwind CSS v4
- **UI Library**: shadcn/ui (style: `radix-nova`, base color: `neutral`)
- **Icons**: lucide-react
- **Notifications**: sonner
- **React**: v19

## Project Structure

```
app/           # Next.js App Router pages and layouts
components/
  ui/          # shadcn/ui components
lib/
  utils.ts     # cn() utility (clsx + tailwind-merge)
public/        # Static assets
```

## Available shadcn/ui Components

The following components are installed in `components/ui/`:

| Component | Path                     |
| --------- | ------------------------ |
| Button    | `@/components/ui/button` |
| Input     | `@/components/ui/input`  |

## Installing More shadcn/ui Components

```bash
npx shadcn@latest add <component-name>
```

Examples:

```bash
npx shadcn@latest add card
npx shadcn@latest add dialog
npx shadcn@latest add select
npx shadcn@latest add form
npx shadcn@latest add table
```

Browse all available components at: https://ui.shadcn.com/docs/components

## Common Commands

```bash
npm run dev      # Start dev server (Turbopack)
npm run build    # Production build
npm run lint     # Run ESLint
```

## Conventions

- Imports use `@/` path aliases (e.g. `@/components/ui/button`)
- Components are server components by default (`rsc: true`); add `"use client"` when needed
- Use `cn()` from `@/lib/utils` to merge class names
- Toast notifications via `sonner`

## Design System

MetroPaws uses the `/impeccable` skill for all frontend design work. Context files at the project root:

- **PRODUCT.md** — register (brand), users, brand personality, anti-references, design principles
- **DESIGN.md** — color palette (navy + gold + cream, OKLCH), Montserrat typography, tokens, component patterns

### Design Constraints

| Constraint       | Value                                      |
| ---------------- | ------------------------------------------ |
| Theme            | Light mode only — no dark mode variants    |
| Font             | Montserrat (400/500/600/700)               |
| Max body text    | 14px (`text-sm`)                           |
| Viewport         | Mobile and Desktop responsive              |
| Accessibility    | WCAG AA                                    |
| Color strategy   | Committed — navy 40-60%, gold accent only  |

### Key Design Principles

1. **Quiet authority** — premium through restraint, not loudness
2. **Show the product** — QR ID and membership card are the story, not "pet wellness" abstractly
3. **Exclusivity through scarcity** — Founding 50 signals rarity without gimmicks
4. **Trust through transparency** — pricing and coverage always unambiguous
5. **Filipino context** — Las Piñas, Metro Manila; not imported Western SaaS aesthetics

### Anti-references

- E-commerce pet shops (product grids, sale badges, discount visual language)
- Generic vet clinic sites (clinical white + teal, stock stethoscope photos)

### Available Commands

| Command | When to use |
| ------- | ----------- |
| `/impeccable craft [feature]` | Shape and build a feature end-to-end |
| `/impeccable shape [feature]` | Plan UX/UI before writing code |
| `/impeccable critique` | UX review with heuristic scoring |
| `/impeccable polish` | Final quality pass before shipping |
| `/impeccable audit` | Accessibility, performance, responsive checks |
| `/impeccable adapt` | Responsive/mobile adjustments |
| `/impeccable typeset` | Typography improvements |
| `/impeccable colorize` | Add strategic color |
| `/impeccable animate` | Add purposeful motion |

Always load context before design work: `node .claude/skills/impeccable/scripts/load-context.mjs`

---

## TypeScript Clean Code

All TypeScript code in this project follows Robert C. Martin's Clean Code principles. The following skills are available in `.claude/skills/typescript/`:

| Skill                   | Path                                                       | When to apply                                                       |
| ----------------------- | ---------------------------------------------------------- | ------------------------------------------------------------------- |
| `typescript-clean-code` | `.claude/skills/typescript/typescript-clean-code/SKILL.md` | Writing, fixing, or refactoring any TypeScript — master reference   |
| `clean-names`           | `.claude/skills/typescript/clean-names/SKILL.md`           | Naming or renaming variables, functions, classes, interfaces        |
| `clean-functions`       | `.claude/skills/typescript/clean-functions/SKILL.md`       | Functions with 4+ args, flag params, dead exports                   |
| `clean-comments`        | `.claude/skills/typescript/clean-comments/SKILL.md`        | Comments, TSDoc, commented-out code                                 |
| `clean-general`         | `.claude/skills/typescript/clean-general/SKILL.md`         | DRY violations, magic numbers, long if/else chains, unclear intent  |
| `clean-tests`           | `.claude/skills/typescript/clean-tests/SKILL.md`           | Writing or fixing tests — coverage, boundaries, one assert per test |
| `boy-scout`             | `.claude/skills/typescript/boy-scout/SKILL.md`             | Any edit — leave code cleaner than you found it                     |

### Key Rules Summary

- **Naming**: Descriptive names; no single-letter vars, no Hungarian notation (`strName`), no `I`-prefixed interfaces
- **Functions**: Max 3 arguments (use typed objects for more); no flag params; no output arguments; no dead functions
- **Comments**: No metadata, no redundant comments, never commit commented-out code
- **General**: DRY — no duplication; no magic numbers; prefer polymorphism over if/else chains; no obscured intent
- **Boy Scout**: Always leave touched code cleaner than you found it
