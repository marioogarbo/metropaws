/**
 * Single source of truth for the two ways a member can install the Android app.
 *
 * Google Play carries the reviewed, auto-updating release. The direct APK runs
 * ahead of it while newer builds wait on a Play release, so both routes stay
 * offered. Update these values every time a new APK is uploaded so the badge,
 * the /download page, and the version label never drift from the actual file.
 */

// Live Google Play listing. The plain HTTPS form deep-links into the Play Store
// app on Android and falls back to the web listing on desktop — unlike
// market:// which breaks outside Android.
export const PLAY_STORE_URL =
  "https://play.google.com/store/apps/details?id=com.metropaws.mobile";

// Direct-download link to the current release APK.
// Hosted on Google Drive (uc?export=download forces a file download rather
// than the Drive preview page). Swap this for a Supabase Storage / GitHub
// Release URL if the host changes — nothing else needs to change.
export const APK_HREF =
  "https://drive.google.com/uc?export=download&id=1KT2Qi_xCdNsl0njdd54kkzbB9wdHRAto";

// Marketing version of the uploaded APK — keep in sync with mobile pubspec.yaml.
// Bumping this without replacing the file behind APK_HREF makes the site
// advertise a version it doesn't actually serve: upload first, then bump.
export const APK_VERSION = "1.4.0";

// Conservative floor so we never wrongly tell an eligible member their phone
// is too old. Essentially every active Android device meets this.
export const ANDROID_MIN_VERSION = "Android 6.0 or later";
