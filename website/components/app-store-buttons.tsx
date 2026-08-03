import Link from "next/link";
import { Apple } from "lucide-react";
import { PlayStoreIcon } from "@/components/play-store-icon";
import { IOS_STATUS_LABEL, PLAY_STORE_URL } from "@/lib/app-download";

/**
 * Both badges carry their own opaque navy fill. The hero behind them is a photo
 * under a left-to-right scrim, so anything translucent here lands on whatever
 * the photo happens to be doing and stops being readable.
 */
const badgeShell =
  "inline-flex items-center gap-2.5 rounded-lg px-4 py-2.5 border bg-[oklch(0.18_0.045_258)]";
const badgeCaption =
  "text-[9px] font-medium leading-none tracking-wide";
const badgeLabel = "text-sm font-semibold leading-tight mt-0.5";

function PlayStoreBadge() {
  return (
    <a
      href={PLAY_STORE_URL}
      target="_blank"
      rel="noopener noreferrer"
      className={`${badgeShell} border-white/15 transition-all duration-200 ease-out hover:border-white/30 hover:bg-[oklch(0.22_0.052_258)] focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[--color-gold] focus-visible:ring-offset-2 focus-visible:ring-offset-[oklch(0.22_0.052_258)]`}
      aria-label="Get the MetroPaws app on Google Play"
    >
      <PlayStoreIcon />
      <div>
        <div className={`${badgeCaption} text-white/55`}>Get it on</div>
        <div className={`${badgeLabel} text-white`}>Google Play</div>
      </div>
    </a>
  );
}

/**
 * Deliberately not a link or a button — the iOS app does not exist yet, so
 * there is nowhere to send anyone. It sits beside Google Play to answer the
 * "is there an iPhone version?" question before it gets asked.
 */
function AppStoreBadge() {
  return (
    <div className={`${badgeShell} border-dashed border-white/25`}>
      <Apple className="w-5 h-5 text-white/70" strokeWidth={2} aria-hidden="true" />
      <div>
        <div className={`${badgeCaption} text-(--color-gold)`}>
          {IOS_STATUS_LABEL}
        </div>
        <div className={`${badgeLabel} text-white/75`}>App Store</div>
      </div>
    </div>
  );
}

export function AppStoreButtons() {
  return (
    <div className="flex flex-col gap-2">
      <div className="flex flex-row gap-3 flex-wrap">
        <PlayStoreBadge />
        <AppStoreBadge />
      </div>
      <p className="text-[10px] text-white/75 leading-snug max-w-[40ch] [text-shadow:0_1px_3px_oklch(0.18_0.045_258/0.7)]">
        Free on Google Play, with automatic updates ·{" "}
        <Link
          href="/download"
          className="text-white underline underline-offset-2 transition-colors hover:text-(--color-gold)"
        >
          How to install
        </Link>
      </p>
    </div>
  );
}
