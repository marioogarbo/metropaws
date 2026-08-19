# 2026-08-19 — Pet-friendly redesign of the auth screens

Brief: "redesign the login screens, make it pet friendly", with a marked-up
screenshot showing envelope/lock field icons, scattered paw prints and a gold
Sign In button.

Rebuilt all three auth screens — `login_screen.dart`, `register_screen.dart`
(email gate + step 1), `forgot_password_screen.dart` — plus the shared header,
and added `core/widgets/mp_paw_backdrop.dart`. Not on Play; see
[`mobile-unreleased.md`](../features/mobile-unreleased.md) §5.

## The keeper: three defects, and what caught each

Every one of them analysed clean. `flutter analyze` reported **21 issues before
and after** the whole change — the same 21, all pre-existing dead code in
`register_screen.dart`.

1. **A keyboard check that could never fire.** The header was meant to collapse
   to a band while typing, freeing the room the form needs. It read correctly and
   compiled, and did nothing. `Scaffold` **removes the bottom view inset from the
   MediaQuery it hands its body** when `resizeToAvoidBottomInset` is on, so
   `MediaQuery.viewInsetsOf(context).bottom` inside any body widget is `0`
   forever. The fix is to read it in the build method that *returns* the
   Scaffold and pass the result down — hence
   `MpBrandPhotoStrip.keyboardIsUp(context)` plus a `compact` flag, rather than
   the strip detecting its own state. Caught by screenshotting the keyboard on a
   device; nothing in the code looks wrong.

2. **A verification that failed open — again.** Asked whether holding the field
   label still cost the field its accessible name, a `uiautomator dump` piped
   through a grep for `text=` / `content-desc=` returned nothing for either
   field, and that silence was read as "no accessible name". It was the grep:
   Flutter maps `InputDecoration.labelText` to the EditText's **`hint`**
   attribute, which the grep never looked at. Dumping the raw node showed
   `class="android.widget.EditText" … hint="Email address"` all along. Same
   shape as the `strings` failure in
   [`2026-08-19-play-release-1-5-0.md`](./2026-08-19-play-release-1-5-0.md): a
   check that reads nothing is indistinguishable from a check that passes. The
   design conclusion survived on other grounds; the stated reason for it was
   wrong and is corrected in `mp_text_field.dart`.

3. **The client found the one thing not tested.** The paw trail is positioned in
   *fractions of the box it paints into*, and that box is the form area — which
   the keyboard shortens twice over (the inset, plus the header collapsing). So
   the whole gait compressed, stride and print size together. Every screenshot
   taken of the trail had been with the keyboard **down**. Now the backdrop
   remembers the tallest box seen at the current width and paints into that
   inside a `ClipRect`, so the keyboard crops the trail instead of squeezing it;
   verified by cropping the same slice of trail measured from the top of the
   cream field in both states and comparing at 9× contrast — identical size,
   shape and offset.

## Two contrast defects that were already live

Neither was introduced by this work.

- **`AppColors.gold` on the cream surface is ~2.7:1** (`mobile/CLAUDE.md`
  already records 2.7:1 on white). "Forgot password?" and "Join now" were both
  gold on cream and had been failing since those screens were written. Secondary
  links are navy now, which also makes login consistent with register, which was
  already using `cs.primary`.
- **Dark status-bar icons over the photo.** The auth screens carry no AppBar, so
  Flutter has no background to derive the style from and they inherited whatever
  the previous screen set. Fixed with an `AnnotatedRegion` in the strip — the
  same device `payment_result_screen` already uses for the same reason.

## Deliberate deviations from the client's mockup

Recorded because they will look like oversights in a diff.

- **Sign In stays navy, not gold.** `mobile/PRODUCT.md` reserves gold for money
  and high-value actions and names login explicitly as navy fill. There is no
  money moment on an auth screen, so gold is kept off it entirely.
- **Paw *tracks*, not scattered paw prints.** Randomly-angled paws are the
  reflex move for a pet app. One trail with a consistent heading, alternating to
  either side of the line of travel, tapering as it recedes, does a job: it
  leads from the heading down toward the primary action. It also had to be drawn
  larger than first attempted — at 34px the pad and toes read as a cluster of
  separate circles on a real screen rather than a paw.
- **The greeting sits on the cream, not on the photo.** Large white text over a
  bright yard is a contrast gamble; on cream it is ~15:1 and satisfies the
  typography mandate for free. The photo carries the brand lockup and one line.

## Also fixed, found while reviewing

- **The header was a different height on each screen** — `× 0.30` on login,
  `× 0.24` on the other two (250dp vs 200dp on this device). Inherited, not
  introduced. It matters here specifically because *all three screens use the
  same photograph*, so the difference reads as one image being resized, and
  login pushes straight to forgot-password where you watch it happen. Now one
  rule, `MpBrandPhotoStrip.heightFor(context)`, called once per screen; measured
  identical at y=910 of 3120 on both.
- **The form was top-aligned**, leaving a third of a tall phone empty below the
  last link and pushing the fields away from the thumb. `MpCentredScroll`
  centres while the content fits and degrades to a plain scroll view when it
  does not.
- **A field with a leading icon cannot animate its label.** Flutter indents the
  input text past a `prefixIcon` but floats the label to the *container* edge,
  so on focus the label slides up **and ~40dp left, across the icon**;
  `InputDecoration` cannot align the two positions. `always` — label
  permanently in the notch — is the only option that neither moves nor
  disappears. `never` is worse: the label is hidden the moment the field takes
  focus, leaving an icon and a bare cursor.

## Verified on device vs not

Physical SM S947B (`R5GL217V63Z`), 1440×3120 @ density 600 → 832dp tall.

- Verified: login at rest, focused, and mid-typing; header collapse with the
  keyboard up; login at a simulated **320dp** (`wm size 960x2400`,
  `wm density 480`, reset after) where the 36sp heading steps down to 28sp and
  still fits on one line; register's email gate; forgot-password request state;
  header heights equal across screens; paw-trail geometry stable under the
  keyboard.
- **Not** verified on device: the forgot-password **success** state and register
  **step 1** as rendered (step 1 needs the local backend). Both changed only in
  heading weight and field icons, and step 1 keeps its own scroll view.

## Operational notes

- **Do not run `dart format` on a directory here.** The repo is not uniformly
  formatted with the current Dart version — one directory pass reformatted 13
  untouched files and turned a 43-line change to `register_screen.dart` into
  485. Format only the files actually edited; the first attempt was reverted and
  redone for exactly this reason.
- **`adb shell input tap` coordinates go stale the moment a layout changes.**
  Two taps landed on the wrong control after the header height changed by 37px,
  once submitting the form by accident. Re-screenshot and re-measure between
  layout edits rather than reusing coordinates.
- Heredocs through the Bash tool mangled backslashes (a Dart regex and an
  escaped apostrophe); writing the edit script to a file and running it worked.

## Open

- **Does the paw trail move with the page, or stay pinned to the screen?** It no
  longer deforms, but it still translates upward with the cream field when the
  header collapses. Both behaviours are defensible; pinning needs the backdrop
  to know how far the header shrank. Awaiting the client's preference — asked,
  not guessed.
- **Graphics requested, not yet supplied.** `pet-care-login.jpg`,
  `pet-care-register.jpg` and `pet-care-no-text.jpg` are the **same** golden
  retriever photograph, so the three screens are near-indistinguishable and a
  cat never appears anywhere in the flow — even though the brand mark itself has
  a dog *and* a cat inside the paw. Also: `pet-care-dog.png` is **not** a usable
  cutout (the background is only partly erased, leaving a hard rectangular
  edge), so the decorative corner cutout that `mobile/PRODUCT.md` specifies for
  the forgot-password page cannot be built from the current assets.
