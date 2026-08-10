import { NextResponse } from "next/server";
import { fetchDirectory } from "@/lib/directory";

/**
 * The browser's own route to the directory, for when the page it loaded has no
 * listings in it.
 *
 * `/find-pet-care` is statically rendered with an hour-long revalidate window,
 * so a regeneration that could not reach the backend bakes the "not loading
 * right now" state into the cached HTML and serves it to every visitor until the
 * window closes — and the next regeneration is just as likely to find the
 * backend asleep again, which is how the page stayed broken for days.
 * `DirectoryRecovery` calls this on mount, so a visitor gets the real listings
 * even while the cached HTML says otherwise.
 *
 * Same-origin on purpose: the browser never needs the backend's address or its
 * CORS configuration, the wait for a cold start happens somewhere with a longer
 * budget than a page render, and a successful call populates the shared fetch
 * cache — so the next regeneration of the page prerenders real listings whether
 * the backend is awake at that moment or not.
 */

/** Room for `fetchDirectory` to ride out a Render cold start (30-60s). */
export const maxDuration = 60;

export async function GET() {
  const directory = await fetchDirectory();

  if (!directory.ok) {
    return NextResponse.json(
      { error: "Directory unavailable" },
      // Never cache a failure. Caching one is the bug this route answers.
      { status: 503, headers: { "Cache-Control": "no-store" } },
    );
  }

  return NextResponse.json(directory.providers, {
    headers: {
      // One wake-up covers everyone who arrives in the next five minutes,
      // rather than each visitor starting the container for themselves.
      "Cache-Control": "public, s-maxage=300, stale-while-revalidate=3600",
    },
  });
}
