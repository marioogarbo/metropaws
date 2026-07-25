/**
 * Single source of truth for the direct Android APK download.
 *
 * The Play Store listing is still in review, so members install the app
 * directly from the website in the meantime. Update these three values
 * every time a new APK is uploaded so the badge, the /download page, and
 * the version label never drift from the actual file.
 */

// Direct-download link to the current release APK.
// Hosted on Google Drive (uc?export=download forces a file download rather
// than the Drive preview page). Swap this for a Supabase Storage / GitHub
// Release URL if the host changes — nothing else needs to change.
export const APK_HREF =
  "https://drive.google.com/uc?export=download&id=1KT2Qi_xCdNsl0njdd54kkzbB9wdHRAto";

// Marketing version of the uploaded APK — keep in sync with mobile pubspec.yaml.
export const APK_VERSION = "1.3.1";

// Conservative floor so we never wrongly tell an eligible member their phone
// is too old. Essentially every active Android device meets this.
export const ANDROID_MIN_VERSION = "Android 6.0 or later";
