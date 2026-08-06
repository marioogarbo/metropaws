/**
 * What a member can actually pay with today.
 *
 * Checkout runs through PayMongo, where QR Ph is the live method: one code that
 * any QR Ph participant app can scan. The names below are the apps PayMongo
 * surfaces on the checkout screen, kept as text on purpose. We hold no licence
 * to reproduce their logos, and an approximated logo is worse than a wordmark.
 *
 * Card and the separate wallet buttons stay switched off until PayMongo
 * activates them on the account, so nothing on the site should promise them.
 */
export const QR_PH_APPS = [
  "GCash",
  "Maya",
  "BPI",
  "GoTyme",
  "Home Credit",
] as const;

export const QR_PH_FALLBACK_LABEL = "and any bank app that supports QR Ph";

/** Roughly how long a checkout code stays valid. PayMongo sets this, not us. */
export const CHECKOUT_WINDOW_LABEL = "about 30 minutes";
