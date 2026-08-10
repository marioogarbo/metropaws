/**
 * Fetch policy for database-backed copy on public pages (FAQs, plans, directory).
 *
 * The pages are rendered ahead of time and served from the edge, so the backend
 * is touched by a background regeneration rather than by each visitor. Every
 * caller pairs this with a fallback, so a backend that is down, asleep, or slow
 * costs nobody a blank section.
 */

const BACKEND_URL =
  process.env.NEXT_PUBLIC_BACKEND_URL ?? "https://metropaws-backend.onrender.com";

/** How long a rendered page is served before a background refresh. */
export const PUBLIC_CONTENT_REVALIDATE_SECONDS = 3600;

/** First attempt. A backend that is already up answers in well under a second. */
const WARM_TIMEOUT_MS = 5000;

/**
 * Second attempt, which exists because the first one is usually just the alarm
 * clock.
 *
 * The backend runs on Render's free plan: it spins down after ~15 minutes idle
 * and a cold start takes 30-60s (see
 * `backend/docs/HOSTING_AND_DATA_SAFETY_RECOMMENDATION.md`). A public page
 * regenerates at most once an hour, in the background, typically long after the
 * last member closed the app — so the request that regenerates it is nearly
 * always the one that has to wake the container, and no 5s ceiling could ever
 * survive that.
 *
 * That was not hypothetical. It is why `/find-pet-care` served "the directory is
 * not loading right now" in production while `GET /directory` answered all 19
 * rows in 0.3s, and why the homepage was showing its six hardcoded fallback FAQs
 * instead of the ten the client had written in admin.
 *
 * Nobody is waiting on this: a background regeneration keeps serving the
 * previously rendered page while it works, and both attempts together stay
 * inside a serverless function's budget.
 */
const COLD_START_TIMEOUT_MS = 25000;

/**
 * GET a public content endpoint, giving a sleeping backend time to wake up.
 *
 * Returns null when the content could not be had, which each caller answers in
 * its own way: a hardcoded fallback for stable marketing copy, an honest error
 * state for the directory's operational data.
 */
export async function fetchPublicContent(
  path: string,
  cache: NextFetchRequestConfig = {
    revalidate: PUBLIC_CONTENT_REVALIDATE_SECONDS,
  },
): Promise<Response | null> {
  for (const timeoutMs of [WARM_TIMEOUT_MS, COLD_START_TIMEOUT_MS]) {
    try {
      const response = await fetch(`${BACKEND_URL}${path}`, {
        next: cache,
        signal: AbortSignal.timeout(timeoutMs),
      });
      // A 4xx or 5xx is an answer, not a sleeping container. Retrying would
      // spend the second timeout to be told the same thing.
      return response.ok ? response : null;
    } catch {
      // Timed out, or the connection failed. Fall through to the longer attempt,
      // by which point the first one has had the container starting for 5s.
    }
  }
  return null;
}
