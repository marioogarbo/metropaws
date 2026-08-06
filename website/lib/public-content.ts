/**
 * Fetch policy for database-backed copy on public pages (FAQs, plans).
 *
 * The pages are rendered ahead of time and served from the edge, so the backend
 * is touched by a background regeneration rather than by each visitor. Every
 * caller pairs this with a hardcoded fallback and a try/catch, so a backend that
 * is down, asleep, or slow costs nobody a blank section.
 */

/** How long a rendered page is served before a background refresh. */
export const PUBLIC_CONTENT_REVALIDATE_SECONDS = 3600;

/**
 * Ceiling on a single content fetch. Render puts the backend to sleep when idle,
 * and a cold start with no timeout would stall a production build until it woke
 * up. Failing fast means we render the fallback instead of waiting.
 */
export const PUBLIC_CONTENT_TIMEOUT_MS = 5000;
