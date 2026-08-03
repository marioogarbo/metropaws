/**
 * Single source of truth for how a member installs the MetroPaws app.
 *
 * Android is the only platform that ships today, and it ships through Google
 * Play alone — the direct APK route was retired, so nothing on the site should
 * offer a file download. iOS is advertised as coming soon, which is why there
 * is deliberately no App Store URL here: add one and turn the iOS badges into
 * links on the day the listing goes live.
 */

// Live Google Play listing. The plain HTTPS form deep-links into the Play Store
// app on Android and falls back to the web listing on desktop — unlike
// market:// which breaks outside Android.
export const PLAY_STORE_URL =
  "https://play.google.com/store/apps/details?id=com.metropaws.mobile";

// Conservative floor so we never wrongly tell an eligible member their phone
// is too old. Essentially every active Android device meets this.
export const ANDROID_MIN_VERSION = "Android 6.0 or later";

// Every iOS surface reads this, so the wording changes in one place.
export const IOS_STATUS_LABEL = "Coming soon";
