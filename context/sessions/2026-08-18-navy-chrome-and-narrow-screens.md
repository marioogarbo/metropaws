# 2026-08-18 — Navy app chrome, narrow screens, and the pet card

Mobile only. Three pieces of work: a colour/structure pass on Home and the app
chrome, a responsiveness pass for narrow screens, and a partial redesign of the
Home pet card. All on `main`, none released.

The headline finding is methodological and worth keeping: **the first two
commits were written from static analysis and caught none of the defects that
actually mattered.** Six real bugs surfaced only once the app was rendered on a
device at a narrow width. One of them — a `Stack` overlap — is invisible to any
amount of code reading, because `Positioned` siblings contribute nothing to a
sibling's layout constraints, so nothing about the code looks wrong.

---

## 1. Navy chrome and a 60/30/10 colour pass (`3fa57b8`)

The Home screen had no structural break between "who you are" and "your pets",
and the accent had drifted into doing the primary colour's job: **gold appeared
about ten times on one screen while navy appeared once.** That is roughly
70/5/25, not 60/30/10, which is why nothing read as ranked.

- `appBarTheme` is navy app-wide; Home opens with a navy header block (greeting,
  first name, Founding badge, PawPoints) with a rounded foot; the nav capsule is
  navy. That trio carries the 30% band.
- **Six screens were already overriding the app bar to navy by hand**
  (notifications, paw_points, reimbursement, payout_details, pet_profile,
  deploy_service). The white bar was the outlier; the theme now matches what the
  app was already doing, and those local overrides are harmless duplicates.
- Gold stepped down off meter fills, section eyebrows, pagination dots and the
  greeting paw. It is now spent only on money and actions.

### Contrast facts, measured

| Pair | Ratio | Verdict |
| --- | --- | --- |
| `gold #B89A3E` on `navy #263258` | **2.9:1** | fails even the 3:1 UI floor |
| `gold` on white | **2.7:1** | fails for text |
| `grey #8B8FA8` on navy | 3.96:1 | fails 4.5:1 for the 10sp nav label |
| `onNavyMuted #BFC5DC` on navy | 4.6:1 | passes — the new token |
| white on navy | 12.7:1 | the active nav tab |
| cream `#F8F7F4` on navy | 7.4:1 | the Claim circle's ring |

**Gold on navy is the trap.** It reads on the near-black tier cards
(`0xFF111219`) and not on navy, which is why the active nav tab is white and the
raised Claim circle is delineated by a cream ring rather than by the gold itself.
Recorded in `mobile/CLAUDE.md`.

Fixed along the way: the Founding badge was gold-on-white at 2.7:1; the Home
card's wallet balances and claim link the same; PawPoints' "History & Rewards"
(3.9:1) and "pts" (2.9:1).

**Do not set `systemOverlayStyle` in `appBarTheme`.** Flutter derives the status
bar style per AppBar from its own background brightness, which is correct for the
navy bars *and* for `subscription_screen`, which paints its own light bar.
Pinning it breaks that screen. Verified by pinning it, then removing it.

---

## 2. Narrow screens (`2ded560`, `c28a2d9`, `392e92e`)

Target floor **320dp**. Not an exotic device: that is an ordinary 360dp handset
at Samsung's largest "Screen zoom", which raises density and shrinks effective dp
width for every app, and Samsung is rolling the same control out per-app. Galaxy
Z Fold cover displays sit just above it — roughly 329dp (Fold 3/4/5), 344dp (Fold
6), 360dp (Fold 7). The Z Flip's **closed** cover (~260dp) is out of scope, by
client decision.

`Breakpoints` and a `ResponsiveContext` extension live in `mobile/lib/theme.dart`
(a breakpoint is a design token, and that file is the stated single source of
truth). `isTight` keys off **width OR text scale**, because Screen zoom moves
both at once and branching on width alone leaves a 411dp phone at 1.5× font scale
broken.

### Verified on device

Display overridden on the physical Samsung and **restored afterwards**:

```
adb shell wm size 904x2316 && adb shell wm density 440   # 329dp, Fold cover
adb shell wm size 960x2400 && adb shell wm density 480   # 320dp, the floor
adb shell wm size reset    && adb shell wm density reset
```

Swept clean at 329dp: login, Events, Account, Plans, reimbursement Submit and My
Claims. Defects found and fixed:

1. **The PawPoints balance truncated to "1,8…"** on the Benefits hub — the worst
   of them, since it is the member's points. Cause was **flex distribution, not
   width**: the balance sat in an `Expanded` and the trailing label in a
   `Flexible`, and *both default to `flex: 1`*, so `Row` split free space 50/50
   regardless of need. The label wanted 44dp and was handed half the row.
2. **`"METROPAWS STANDARD MEMBE✕"`** on the Digital Pawprint sheet — the brand
   label rendering *underneath* the close button. A `Stack` with a centred `Row`
   and a `Positioned` button; the label had no idea the button existed. Rebuilt
   as a `Row` with a leading 44px spacer mirroring the button.
3. **Form error text clipped to one line** — "Password must be at least 8
   charact…". Flutter caps `errorText` at one line and `errorMaxLines` was set
   **nowhere in the codebase**, so every form in the app truncated its validation
   messages. Now 3 on both themes.
4. "History & Rewards" → "Rewards" when tight (measured: ~92dp available, ~107dp
   needed).
5. "Receipt / reference no. (optional)" → "Receipt / ref. no. (optional)"; the
   clip was hiding the one word that says the field is skippable.
6. The wallet meter's peso figure was the unconstrained child of its `Row`, so it
   overflowed rather than ellipsising.

### Decided against

**No hamburger and no hidden nav items.** Hiding primary navigation to reclaim
~30px is a bad trade for an audience documented as spanning a wide age range and
mixed digital comfort. On a bottom bar the label *is* the affordance. Tightening
the insets (16→8 outer, 4→2 per tab, icon 25→23) bought ~9dp per tab, which was
the difference between "Account" reading in full and ellipsising. Verified in
full at both 329dp and 320dp.

---

## 3. The Home pet card — partly kept, partly reset away

**`main` is at `c7f5894`.** A later commit was force-pushed away; see below.

Kept:

- **The card now states the plan** (`21a73f2`). It previously showed none, which
  also left "Upgrade plan" at its foot instructing the member to upgrade from an
  unnamed thing — and falsified `mobile/CLAUDE.md`, which asserted "every pet
  card already carries its own `TierBadge`" as the stated reason for removing the
  tier from the Home header. It did not, so tier had disappeared from Home
  entirely. The note was corrected rather than left as a rule the code ignored.
- **No expiry date on the card** (`6e3d2b6`, client decision). The status line is
  reserved for the two cases that are warnings rather than dates: `Expired`, and
  the server's verbatim `membershipStatusLabel` for monthly members, who are not
  covered while vesting and would be implied to be by a bare tier badge.
  **Never "Renews on"** — nothing bills automatically, there is no scheduler
  behind the API and no saved card, so promising a renewal is a false statement
  about the member's money.
- **Relayout** (`c7f5894`): one divider instead of three, two-line meters, tier
  badge inline, "File a claim" and "Upgrade plan" sharing a `Wrap`, avatar 52→60.
  About 140dp shorter, which is what put the pagination dots back on screen — on
  a carousel built for swiping between pets you previously could not see one
  whole pet at a time. The unlock was the *string*, not the layout:
  `"₱2,000.00 left of ₱2,000.00"` is 27 characters and cannot share a line with
  the pool name at any width this app runs at, which is what kept forcing the
  label and figure onto separate rows. `"₱2,000.00 left"` fits at 329dp.

### Reset away: the meter redesign (`250b08b`)

Client feedback: *"the progress bar doesn't look like a progress bar, it looks
like a line."* Accurate — at 100% a 6dp fill spanning the full width over a track
at 15% opacity is a divider. An attempt (12dp track, 28% ink, fill inset 2dp so a
rim survives at 100%, 14sp balance) was built and verified on both a light
Standard and a dark De Luxe card, then **rejected and removed from history by
force-push**. The commit is recoverable by hash (`250b08b`) but is not on any
branch.

**The original complaint therefore still stands: the meter bar is 6dp and reads
as a rule at 100%.** Open.

That commit also carried a guard for pets whose breed is the literal string
`"None"` — one card renders `"Dog · None"` today. Also open, and unrelated to the
bar.

---

## Working practice, for the next session

- **Build plain `flutter build apk --debug`** (defaults to `ENV=local` →
  `http://localhost:8000`) and rely on `adb reverse tcp:8000 tcp:8000` against the
  locally-running backend. Do **not** rebuild with `--dart-define=ENV=dev`; that
  was tried and rejected — the fix was to start the local API and the tunnel.
  Check `adb reverse --list` before blaming the app for a connection error.
- The installed app is a sideloaded debug build (`installerPackageName=null`), so
  `adb install -r` replaces it in place and keeps the session. It is not the Play
  build, so no signature clash — but re-check rather than assume, per
  [`../features/android-distribution.md`](../features/android-distribution.md).
- Screenshots: `adb shell screencap -p /sdcard/x.png` then `adb pull`. In Git Bash
  set `MSYS_NO_PATHCONV=1` or the device path is rewritten to a Windows path.
- The Account footer prints the env (`MetroPaws v1.4.1 (9) · local`) — the fastest
  way to confirm which backend a build points at.

## Still untested at narrow width

Add Pet (the densest flow in the app — a four-step form with photo pickers and a
plan step), Pet Profile, PawPoints, Notifications, and the 10 flagged rows in
`mobile/lib/features/clinic/screens/clinic_scanner_screen.dart` (skipped
deliberately: clinic staff are on tablets).

A narrow-layout regression test would catch this whole class automatically, but
it belongs in `mobile/test/`, which is outside the filesystem scope
`mobile/CLAUDE.md` grants. Lifting that restriction is worth considering.
