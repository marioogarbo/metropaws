/**
 * Temporary switch for the two member documents the client pulled on
 * 2026-08-03: the Membership Agreement (served by /terms-of-service — the ToS
 * page doubles as the agreement) and the Member Manual PDF. The agreement
 * wording no longer matches the business model and is being rewritten, so
 * neither document should be readable until the new versions land.
 *
 * Why the URLs stay alive instead of 404ing: the Android app on Google Play
 * links to both from its sign-up consent checkbox, its registration screen and
 * the Account section of the dashboard. Those links are compiled into installs
 * we can't change, so removing the routes would put dead links inside a live
 * app's consent flow. Under revision, both paths serve a notice page instead.
 *
 * To restore a document: flip its flag back to false, redeploy, and put the
 * footer link back in front of members. Nothing else needs undoing — the ToS
 * content and the PDF are untouched in the repo.
 */
export const AGREEMENT_UNDER_REVISION = true;
export const MANUAL_UNDER_REVISION = true;

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
