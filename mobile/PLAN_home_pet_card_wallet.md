# Implementation Plan — Replace session progress bars on the Home pet card with the Benefit Wallet

> **For the implementing agent (Claude Sonnet):** This plan was prepared on the Fable model
> after reading the actual code. All product decisions are already made — do NOT re-derive,
> redesign, or expand scope. Execute the steps in order. Where a code sketch is given, adapt
> it to the surrounding style rather than pasting blindly.
>
> **Before writing any code, read:**
> 1. `mobile/CLAUDE.md` (the whole file — hard rules apply)
> 2. `mobile/.impeccable.md` (design tokens & principles)
>
> All work is inside ONE file unless stated otherwise:
> `lib/features/member/screens/member_dashboard_screen.dart` (~5,000 lines — use targeted
> reads/greps, do not read it whole).

---

## 1. Context — why this change

Booking/sessions are on **standby** (no partner clinics; the Book tab is hidden behind the
`booking_enabled` flag, default `false`). The primary member benefit is now the
**reimbursement Benefit Wallet**: one shared peso pool per pet per plan year
(`WalletPet.remainingCentavos`). Members pay the clinic out of pocket, then file a claim.

The Home tab's tier-skinned pet card (`_DigitalIdCard`) still shows **session progress
bars** (`_SessionProgressRow` over `pet.petServices`) — outdated in the flag-off world.

**The card's job stays the same: "what is my membership worth right now for this pet?"
The answer changed from sessions to pesos.**

### Decisions already made (do not revisit)

| Decision | Ruling |
|---|---|
| What replaces the session bars | A **wallet summary row**: "₱X left of ₱Y" + slim progress bar (same visual language as sessions, peso-denominated) |
| History element | ONE claim-status line, only when something is live (rules in §5.3) |
| Quick action | A quiet **"File a claim"** text link on the card |
| Keep on card | Pet identity header, verified badge, tier skin, QR / "Show Digital Pawprint" CTA, options menu — all unchanged |
| Session bars | **NOT deleted** — kept behind `bookingEnabled` (booking code is standby, never dead; see CLAUDE.md) |
| PawPoints, pet vitals, photo-slot nudges | NOT on the card (they live elsewhere on Home) |
| Grooming-eligibility line | OUT OF SCOPE (needs a backend field; phase 2) |
| New BLoC / new endpoint | NONE — reuse `MemberBloc` + existing `ReimbursementsLoadRequested` |
| New widget file | NONE — the wallet row is a private widget in `member_dashboard_screen.dart`, because it must paint with the tier-skin colors (`onCard`/`accent`), which the Benefits hub's `WalletPetCard` cannot do. Drift risk is controlled by both reading the same `WalletPet` fields and formatting via `pesoFromCentavos` |

---

## 2. Existing code map (verified anchors)

| Thing | Where |
|---|---|
| Shell + tabs (`IndexedStack`: Home 0, Book/Events 1, **Benefits 2**, Account 3) | `_MemberShellState.build`, ~line 189 |
| `_HomeTab` state accumulation (`_member`, `_pawPointsBalance`, `_bookings`) with strict `listenWhen`/`buildWhen` filters | `_HomeTabState`, ~lines 225–315 |
| On `MemberLoaded` the Home listener dispatches `PawPointsBalanceLoadRequested` (+ `BookingsLoadRequested` if flag on) | ~line 272–278 |
| `_Dashboard` (receives `member`, `pawPointsBalance`, `bookings`, `onNavigateToTab`, `bookingEnabled`) | constructed ~line 288 |
| `_DigitalIdCard` construction inside the pet pager | ~line 1020 (`qrToken: pets[i].id, member, pet, onShowQr, onOpenProfile, onOptions, onSubscribe`) |
| Sessions block on the card (`if (petServices.isNotEmpty) ... _SessionProgressRow` / else empty-state) | ~lines 2032–2130 |
| `_SessionProgressRow` (the bar visual to imitate) | ~line 2594 |
| Stagger animations `_staggerCtrl` / `_rowFades` / `_rowSlides` sized from `petServices` | `_DigitalIdCardState.initState` (just after ~line 1762) |
| Wallet + claims load (parallel fetch, emits `ReimbursementLoaded(wallet, claims)`) | `member_bloc.dart` `_onReimbursementsLoad`, line 263 |
| `WalletPet` (petId, walletCentavos, pendingCentavos, usedCentavos, remainingCentavos), `Reimbursement` (petId, status, statusLabel, approvedAmountCentavos, paidAt…), `pesoFromCentavos()` | `core/models/reimbursement.dart` |
| Push-route pattern sharing the bloc (`BlocProvider.value` + `ReimbursementScreen(initialTab: …)`) | `benefits_screen.dart` `_openReimbursements`, line 90 |
| Pet plan fields (`planType`, `planActivatedAt`, `hasActivePlan`) | `core/models/pet.dart` |

---

## 3. Step 1 — Plumb wallet + claims into the Home tab

In `_HomeTabState`:

1. Add fields alongside the existing ones:
   ```dart
   Wallet? _wallet;
   List<Reimbursement>? _claims;
   ```
   (Import `../../../core/models/reimbursement.dart` if the file doesn't already import it.)

2. In the `BlocConsumer` **listener**, where `MemberLoaded` already dispatches
   `PawPointsBalanceLoadRequested`, also dispatch:
   ```dart
   context.read<MemberBloc>().add(ReimbursementsLoadRequested());
   ```

3. Add `s is ReimbursementLoaded` to **`buildWhen`** (do NOT add `ReimbursementLoading`
   or `ReimbursementFailure` — the comment above those filters explains why: every bloc
   emission used to rebuild the whole dashboard tree. On failure the card simply shows no
   wallet row; that is the intended quiet fallback).

4. In the **builder**, capture the state like the others:
   ```dart
   if (state is ReimbursementLoaded) { _wallet = state.wallet; _claims = state.claims; }
   ```

5. Pass `wallet: _wallet, claims: _claims` into `_Dashboard`, and add those two
   parameters to `_Dashboard` itself.

**Known side effect (accepted):** `ReimbursementsLoadRequested` emits `ReimbursementLoading`
then `ReimbursementLoaded` on the shared `MemberBloc`; the Benefits tab listens for those and
will refresh its data. That's harmless (fresh data). Do not "fix" it.

---

## 4. Step 2 — Pass per-pet data into `_DigitalIdCard`

At the `_DigitalIdCard` construction (~line 1020), for each `pets[i]`:

```dart
walletPet: wallet?.pets.where((w) => w.petId == pets[i].id).firstOrNull,
petClaims: claims?.where((c) => c.petId == pets[i].id).toList() ?? const [],
bookingEnabled: bookingEnabled,
onOpenBenefits: () => onNavigateToTab(2),          // Benefits tab index
onFileClaim: () => _openReimbursementScreen(context, initialTab: 1),
onOpenClaims: () => _openReimbursementScreen(context, initialTab: 0),
```

Add the corresponding fields to `_DigitalIdCard` (`WalletPet? walletPet`,
`List<Reimbursement> petClaims`, `bool bookingEnabled`, and the three callbacks —
nullable like the existing ones).

`_openReimbursementScreen` is a small helper in `_Dashboard` (or wherever the other
navigation helpers live) copying the pattern from `benefits_screen.dart:90`:

```dart
final bloc = context.read<MemberBloc>();
await Navigator.push(context, MaterialPageRoute(
  builder: (_) => BlocProvider.value(
    value: bloc,
    child: ReimbursementScreen(initialTab: initialTab),
  ),
));
```

After returning, dispatch `ReimbursementsLoadRequested()` again (mirrors the Benefits hub's
"refresh wallet after returning") — guard with `mounted`.

Check the imports at the top of `member_dashboard_screen.dart`; add the
`reimbursement_screen.dart` import if missing.

---

## 5. Step 3 — Rework the card body (the core change)

Replace the current sessions block (~lines 2032–2130) with this structure:

```
if (hasPlan) {
  Divider
  Padding(16, 12, 16, 2) column:
    [A] Wallet summary row        — only if walletPet != null
    [B] Claim status line         — only if a live claim exists (rules below)
    [C] "File a claim" link       — only if walletPet != null && remaining > 0
    [D] LEGACY sessions rows      — only if bookingEnabled && petServices.isNotEmpty
} else {
  [E] existing "No active plan" empty state, with updated copy + existing Subscribe CTA
}
```

If `hasPlan` and `walletPet == null` (wallet still loading or fetch failed) and nothing in
[B]/[D] applies, render nothing below the header — no spinner, no placeholder. The card
height is measured (`_MeasureSize` + `OverflowBox`) and animates when data arrives.

### 5.1 [A] Wallet summary row — `_WalletSummaryRow`

New **private** widget in this file, modeled directly on `_SessionProgressRow`
(~line 2594): same paddings, same 8px-tall rounded track
(`onCardMuted.withValues(alpha: 0.15)` background, `accent` fill), same
`TweenAnimationBuilder` 700ms easeOutCubic fill animation, same tabular figures.

Props: `WalletPet walletPet`, `Color onCard`, `Color onCardMuted`, `Color accent`,
`VoidCallback? onTap`, and optionally `DateTime? planActivatedAt` for the depleted caption.

Content:
- Left label: `Benefit Wallet` (labelMedium, w600, `onCard`) — where the service name was.
- Right value: `RichText` — `pesoFromCentavos(remainingCentavos)` in `accent` w800
  (muted like the depleted-session treatment when remaining == 0), followed by
  ` left of ${pesoFromCentavos(walletCentavos)}` in `onCardMuted` labelSmall.
  Both spans keep `FontFeature.tabularFigures()`.
- Bar progress = `remainingCentavos / walletCentavos` (guard divide-by-zero: if
  `walletCentavos == 0`, skip the whole row — a plan with no wallet has nothing to show).
- **Depleted state** (`remainingCentavos == 0 && walletCentavos > 0`): add a caption line
  under the bar, bodySmall in `onCardMuted`:
  `Wallet fully used — resets when your plan renews` and, if `planActivatedAt != null`,
  append ` on {formatted planActivatedAt + 365 days}` (use the date formatting style already
  used in this file — grep for an existing `MMM` / month-name formatter and match it).
- Wrap in `Semantics(label: 'Benefit Wallet: {peso} remaining of {peso}')` like the
  session row does.
- Whole row tappable → `onOpenBenefits` (wrap with the shared `ScaleButton` from
  `core/widgets/scale_button.dart` — the app's standard tap feedback; min 44px height).

### 5.2 Peso display note

`pesoFromCentavos` renders `₱5,000.00`. Keep it as-is — do NOT write a new formatter
(consistency with Benefits hub beats brevity).

### 5.3 [B] Claim status line

One line max. Compute from `petClaims` with this priority (first match wins):

1. Any `status == 'needs_info'` → `Action needed on a claim` — tap opens **My Claims**
   (`onOpenClaims`). Use the gold/accent color for this one — it's actionable.
2. Any `status == 'pending' || status == 'under_review'` → `1 claim in review` /
   `N claims in review` (count them) — `onCardMuted`, tap → `onOpenClaims`.
3. Any `status == 'approved'` (not yet paid) → `{peso approvedAmountCentavos} approved — payout on the way` — tap → `onOpenClaims`.
4. Any `status == 'paid'` with `paidAt` within the last **14 days** →
   `{peso} paid back` — tap → `onOpenClaims`.
5. Otherwise: render nothing.

Visual: a small row — a leading 16px icon (`Icons.receipt_long_outlined`, or
`Icons.error_outline_rounded` for the needs_info case) + bodySmall text, colored per
above. 44px min touch height, `Semantics` button label. Keep it visually quieter than the
wallet row — it's a status whisper, not a second hero.

### 5.4 [C] "File a claim" link

A text-button-style link (labelMedium w700 in `skin.accent`, no filled background —
must not compete with the gold "Show Digital Pawprint" CTA lower on the card).
Text: `File a claim`. Leading icon `Icons.add_circle_outline` 16px optional.
Tap → `onFileClaim`. Min 44px touch target. Show only when
`walletPet != null && walletPet.remainingCentavos > 0`.

Layout tip: [B] and [C] can share one row (status line left, link right) when both are
present; stack them if space is tight on small widths. Keep total added height modest —
this card sits in a pager measured by `_MeasureSize`.

### 5.5 [D] Legacy sessions rows

Keep the existing `petServices.map(... _SessionProgressRow ...)` block **verbatim**, but
gate it with `widget.bookingEnabled &&`. Do not delete `_SessionProgressRow` — when
booking returns via the flag, sessions render again below the wallet.

### 5.6 [E] No-plan empty state

Keep the structure and Subscribe CTA. Update the copy only:

- Title: `No active plan` (unchanged)
- Body: replace `Ask clinic staff at your next visit to activate a membership plan.` with:
  `Subscribe to unlock {PetName}'s Benefit Wallet and claim back clinic costs.`
  (use the existing `_capFirst(widget.pet?.name ?? 'your pet')` helper).
- The other branch's copy (`No sessions assigned` / `Ask clinic staff to assign sessions…`)
  **disappears** — in the new structure a pet with a plan never shows a sessions-empty
  state (the wallet block is the content). Delete only that dead copy branch, nothing else.
- Also check ~line 1533 (`_NoPetsCard`?): the string `…track sessions at partner clinics.`
  — update to `…and claim back clinic costs.` phrasing to match the new world.

### 5.7 Stagger animations

`_DigitalIdCardState.initState` sizes `_rowFades`/`_rowSlides` from `petServices`. With
sessions hidden, either (a) size the lists from the count of rows actually rendered
(wallet row + status line + link + visible session rows), or (b) simpler and acceptable:
leave the stagger lists for session rows only and render the wallet block without
entrance animation (the card itself already animates in). Prefer (b) if (a) gets fiddly.
Do not crash on index-out-of-range — the existing code already guards with
`i < _rowFades.length` fallbacks; keep that pattern.

---

## 6. Hard constraints (from CLAUDE.md — non-negotiable)

- NO hardcoded colors/sizes outside the skin/`Theme.of(context)` system already used inside
  this card. The tier-skin colors (`skin.accent`, `onCard`, `onCardMuted`) ARE the correct
  source on this card — match how `_SessionProgressRow` consumes them.
- NO new dependency, NO new BLoC, NO direct `http` — everything already exists.
- NO deleting files or booking/session code (standby, not dead).
- 44×44 min touch targets on every new tappable.
- All money stays integer centavos until display via `pesoFromCentavos`.
- Test in BOTH light and dark themes and on all three tier skins (Standard bronze /
  De Luxe gold / Premium black) plus the no-plan neutral card — contrast of the new text
  must hold on each (use `skin.accent`, never raw `AppColors.gold`, exactly like the
  session rows did — the comment at ~line 2598 explains why).

---

## 7. Verification checklist (run all)

1. `flutter analyze` — zero new warnings (watch for unused imports/fields).
2. Build & run on an emulator (dev env). Verify:
   - Pet WITH plan + wallet: wallet row shows `₱X left of ₱Y`, bar animates, tap → Benefits tab.
   - "File a claim" → ReimbursementScreen Submit tab; submitting a claim, then returning →
     home card wallet number decreases (pending counts against remaining).
   - Pet with a `needs_info` claim shows the action line; tap → My Claims.
   - Pet WITHOUT plan: updated subscribe copy + CTA still navigates to plan selection.
   - Wallet fetch failure (e.g. airplane-mode relaunch after cached login): card renders
     header + QR only, no crash, no raw error.
   - Multi-pet member: swiping the pager shows each pet's own wallet numbers.
   - Dark mode + each tier skin: legible everywhere.
   - Booking flag ON (flip `app_settings.booking_enabled` on the dev DB or temporarily
     hardcode `_bookingEnabled = true` locally — REVERT before commit): session rows
     reappear below the wallet block.
3. QR flow untouched: "Show Digital Pawprint" still opens the QR sheet.

## 8. Final step — update `mobile/CLAUDE.md`

Per its own immutable rule, add a short note to the Key Business Logic section: the Home
pet card now shows the per-pet Benefit Wallet summary + latest claim status (data via
`ReimbursementsLoadRequested` on the shared `MemberBloc`, dispatched from `_HomeTab` on
`MemberLoaded`); session progress rows render only when `booking_enabled` is on.

## 9. Out of scope — do NOT do

- Grooming 90-day eligibility line (needs backend support; noted for phase 2).
- Any change to the Benefits hub, `WalletPetCard`, `ReimbursementScreen`, backend, or nav bar.
- PawPoints on the card, renewal-date logic beyond the depleted caption, push notifications.
- Refactors of the pager, skins, QR sheet, or bloc structure.
