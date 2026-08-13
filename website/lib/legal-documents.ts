/**
 * Switch for the two member documents the client pulled on 2026-08-03: the
 * Membership Agreement (served by /terms-of-service — that page doubles as the
 * agreement) and the Member Manual PDF. Both were republished on 2026-08-13
 * from the revised documents — Agreement Rev. 5A and Member Manual Rev. 3C —
 * so the flags are off.
 *
 * Why the URLs stay alive rather than 404ing when a document is pulled: the
 * Android app on Google Play links to both from its sign-up consent checkbox,
 * its registration screen and the Account section of the dashboard. Those links
 * are compiled into installs we can't change, so removing the routes would put
 * dead links inside a live app's consent flow. Under revision, both paths serve
 * a notice page instead.
 *
 * To pull a document again: flip its flag to true and redeploy. The footer
 * link, the sign-up checkbox, the privacy-policy cross-link and the PDF rewrite
 * in next.config.ts all follow the flag — nothing else needs touching.
 */
export const AGREEMENT_UNDER_REVISION = false;
export const MANUAL_UNDER_REVISION = false;

/** Public path the app and the site footer use for the Member Manual PDF. */
export const MEMBER_MANUAL_PATH = "/docs/member-manual.pdf";

/** Page that answers MEMBER_MANUAL_PATH while the manual is under revision. */
export const MANUAL_NOTICE_PATH = "/member-manual";

/** Where to send members who need the terms in the meantime. */
export const DOCUMENT_REVISION_CONTACT = "csr@metropaws.ph";

/**
 * Recorded as `agreement_version` on new members while only the Privacy Policy
 * is presented at sign-up. Deliberately not the real agreement version — these
 * members never saw the Membership Agreement, and the acceptance record has to
 * say so.
 */
export const PRIVACY_ONLY_CONSENT_VERSION = "2026-08-privacy-only";
