# Play Store listing art

Generates the Play Store screenshots and feature graphic by compositing **real
device captures** into a branded frame, using the app's own tokens from
`mobile/lib/theme.dart` and the Montserrat weights from
`mobile/assets/fonts/`.

The listing art went stale once already — `website/public/app-*.png` still shows
"Wallet" in the nav, a plan badge in the Home header that was deliberately
removed, and the pre-redesign pet card. This exists so refreshing it is a re-run
rather than a redo.

```bash
python tools/store-art/store_art.py     # reads captures/, writes out/
```

**`out/` and `captures/` are both gitignored**, and `captures/` deliberately so:
a capture contains real member data — the member's name, pet names, benefit
balances — and the Digital Pawprint screen contains a **live, scannable
`qr_token`**. This repository is public. Never commit one.

The same caution applies to what you upload. A pawprint screenshot published on
the Play Store carries a working QR of whatever account it was shot from. The
captures behind the current listing came from the **dev** database, so the token
does not resolve against production — but re-shooting against prod would put a
real member's token in the store listing. Shoot on dev, or blur the QR.

## Capturing

Screenshots must show the **actual app**; Play requires it. Never redraw or
retouch the UI.

1. Build and install a debug APK, and point it at a backend:
   ```bash
   cd mobile && flutter build apk --debug
   adb install -r build/app/outputs/flutter-apk/app-debug.apk
   adb reverse tcp:8000 tcp:8000          # ENV=local -> localhost:8000
   ```
   **`adb reverse` is per-connection.** Wireless debugging changes port on every
   toggle, and a reconnect silently drops the tunnel — the app then shows
   "Could not connect". Re-run it after any reconnect. `adb mdns services` finds
   the new port.

2. Capture at full resolution and save into `captures/` as `home.png`,
   `pawprint.png`, `benefits.png`, `claim.png`, `add-pet.png`:
   ```bash
   adb exec-out screencap -p > tools/store-art/captures/home.png
   ```
   A 1440x3120 device downsamples to 1080x1920 cleanly.

3. Run the script.

## Gotchas that have already cost time

- **The bundled Montserrat has no peso sign.** All five files in
  `mobile/assets/fonts/` carry 232 codepoints and `₱` (U+20B1) is not among
  them, so a headline containing it renders as tofu. Write "PHP", or keep money
  out of the headline. Verified 2026-08-27 with `fontTools`.
- **Scale factor when locating tap targets.** A 1440-wide capture previewed at
  320px is 4.5x, not 4x. Several taps landed on the wrong control before this
  was spotted. Preview at 360 to keep it a clean 4x.
- **The Home pet carousel resets to position 1 on every app start**, and its
  order is not the API's order. Probe it rather than assuming — swiping a fixed
  number of times lands on a different pet than expected.
- **The status bar is cropped** (`crop_top=105`). The clock, battery and any
  stray notification are not part of the product and date the image.
- **Output is 24-bit RGB with no alpha.** Play rejects an alpha channel. The
  existing `website/public/app-*.png` files are RGBA and 432x930 — undersized
  and non-compliant as well as stale.

## Demo data

The captures are only as good as the data in them. Before shooting:

- One pet with a **real name, a real breed and a proper photo**. A long breed
  ellipsizes on the Home card — "Golden Retriever" became "Golden Retriev…", so
  prefer a short one.
- A **birth date**, or the Digital Pawprint reads "0 yrs".
- **Delete test pets.** They appear in the Home carousel and the claim form's pet
  dropdown.
- Headline copy must match what is on screen. A Standard card showing ₱2,000
  cannot carry a "up to PHP 7,000" headline.

Pet fields are editable through the API without touching the database directly:

```bash
TOKEN=$(curl -s -X POST http://localhost:8000/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"…","password":"…"}' | python -c "import sys,json;print(json.load(sys.stdin)['access_token'])")
curl -s http://localhost:8000/pets/ -H "Authorization: Bearer $TOKEN"
curl -s -X PUT "http://localhost:8000/pets/<id>" -H "Authorization: Bearer $TOKEN" \
  -F "breed=Poodle" -F "birth_month=3" -F "birth_year=2023"
```

**`APP_ENV` on the backend defaults to `dev`, which is the shared dev Supabase —
there is no local throwaway database.** Demo data written here is visible to
anyone else on dev. Never point this at prod.

## Sizes

| Asset | Size | Notes |
| --- | --- | --- |
| Phone screenshot | 1080x1920 | 2 minimum, 8 maximum; Google recommends at least 4 |
| Feature graphic | 1024x500 | Required. May be cropped and can carry a play-button overlay, so keep content away from the edges and centre |

## Known defects that keep screens out of the listing

- **`plan_selection_screen.dart` does not format prices.** It interpolates raw
  integers in six places, so the screen renders "₱5999" and "₱9999" with no
  thousands separators. That screen is excluded from the set until it is fixed —
  which also costs the listing its "pay monthly" story.
- **Plan feature strings still say "Wallet"** ("₱4,000 Preventive Wellness
  Wallet"). The app-wide rename did not reach the seed data those strings come
  from. Database rows, so no build is needed.
