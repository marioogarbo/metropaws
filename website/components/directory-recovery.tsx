"use client";

import { useCallback, useEffect, useState } from "react";
import { LoaderCircle } from "lucide-react";
import { DirectoryList } from "@/components/directory-list";
import { DirectoryEmpty, DirectoryUnavailable } from "@/components/directory-notes";
import type { DirectoryProvider } from "@/types/directory";

/** Same origin, so no CORS to depend on and no backend address in the browser. */
const DIRECTORY_ENDPOINT = "/api/directory";

type RecoveryState =
  | { status: "loading" }
  | { status: "ready"; providers: DirectoryProvider[] }
  | { status: "failed" };

/**
 * Loads the directory from the browser when the server render could not.
 *
 * The page is static with an hour-long revalidate window, so a regeneration that
 * found the backend asleep leaves an error page cached for everyone who arrives
 * afterwards. This is the way out of that: the same three outcomes the page
 * itself renders, decided at view time from live data instead of from whatever
 * the backend was doing when the HTML was built.
 *
 * It is deliberately only reached on the failure path. A visitor whose page was
 * prerendered with listings in it gets those listings in the HTML, with no
 * fetching, no spinner, and nothing for a crawler to miss.
 */
export function DirectoryRecovery() {
  const [state, setState] = useState<RecoveryState>({ status: "loading" });

  const load = useCallback(async () => {
    setState({ status: "loading" });
    try {
      const response = await fetch(DIRECTORY_ENDPOINT);
      if (!response.ok) throw new Error(`Directory responded ${response.status}`);

      const providers = (await response.json()) as DirectoryProvider[];
      if (!Array.isArray(providers)) throw new Error("Directory was not a list");

      setState({ status: "ready", providers });
    } catch {
      setState({ status: "failed" });
    }
  }, []);

  useEffect(() => {
    void load();
  }, [load]);

  if (state.status === "ready") {
    // The same distinction the page draws: an empty list is a published state,
    // not a failure, and it reads very differently to someone standing there.
    return state.providers.length > 0 ? (
      <DirectoryList providers={state.providers} />
    ) : (
      <DirectoryEmpty />
    );
  }

  if (state.status === "failed") return <DirectoryUnavailable onRetry={load} />;

  return <DirectoryLoading />;
}

/**
 * The wait, with the length of it stated.
 *
 * A cold start on the current hosting takes most of a minute, and an unqualified
 * spinner tells someone whose pet needs a vet to give up after five seconds. The
 * sentence is what keeps them here long enough to get the list.
 */
function DirectoryLoading() {
  return (
    <section className="bg-(--color-cream) py-16 md:py-20">
      <div className="max-w-6xl mx-auto px-6">
        <div
          className="rounded-xl border border-(--color-ink-faint) bg-(--color-surface) px-6 py-14 text-center md:px-10"
          role="status"
          aria-live="polite"
        >
          <LoaderCircle
            size={22}
            className="mx-auto animate-spin text-(--color-ink-faint) motion-reduce:animate-none"
            aria-hidden="true"
          />
          <p className="mt-4 text-base font-semibold text-(--color-navy)">
            Loading the directory
          </p>
          <p className="mx-auto mt-3 max-w-[52ch] text-sm text-(--color-ink-muted) leading-relaxed">
            Fetching the current listings. This can take up to a minute if the
            page has been quiet for a while.
          </p>
        </div>
      </div>
    </section>
  );
}
