import Link from "next/link";
import { PlayStoreIcon } from "@/components/play-store-icon";
import { PLAY_STORE_URL } from "@/lib/app-download";

function AndroidIcon() {
  return (
    <svg width="20" height="20" viewBox="0 0 24 24" fill="white" aria-hidden="true">
      <path d="M6 18c0 .55.45 1 1 1h1v3.5c0 .83.67 1.5 1.5 1.5s1.5-.67 1.5-1.5V19h2v3.5c0 .83.67 1.5 1.5 1.5s1.5-.67 1.5-1.5V19h1c.55 0 1-.45 1-1V8H6v10zM3.5 8C2.67 8 2 8.67 2 9.5v7c0 .83.67 1.5 1.5 1.5S5 17.33 5 16.5v-7C5 8.67 4.33 8 3.5 8zm17 0c-.83 0-1.5.67-1.5 1.5v7c0 .83.67 1.5 1.5 1.5s1.5-.67 1.5-1.5v-7c0-.83-.67-1.5-1.5-1.5zm-4.97-5.84l1.3-1.3c.2-.2.2-.51 0-.71-.2-.2-.51-.2-.71 0l-1.48 1.48C14.15 1.23 13.1 1 12 1c-1.1 0-2.15.23-3.1.63L7.43.15c-.2-.2-.51-.2-.71 0-.2.2-.2.51 0 .71l1.31 1.31C6.97 3.26 6 5.01 6 7h12c0-1.99-.97-3.75-2.47-4.84zM10 5H9V4h1v1zm5 0h-1V4h1v1z" />
    </svg>
  );
}

function ApkDownloadBadge() {
  return (
    <Link
      href="/download"
      className="inline-flex items-center gap-2.5 bg-[oklch(0.18_0.045_258)] border border-white/15 rounded-lg px-4 py-2.5 transition-all duration-200 ease-out hover:border-white/30 hover:bg-[oklch(0.22_0.052_258)] focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[--color-gold] focus-visible:ring-offset-2 focus-visible:ring-offset-[oklch(0.22_0.052_258)]"
      aria-label="Get the MetroPaws app for Android"
    >
      <AndroidIcon />
      <div>
        <div className="text-[9px] text-white/55 font-medium leading-none tracking-wide">
          Download for
        </div>
        <div className="text-sm text-white font-semibold leading-tight mt-0.5">
          Android APK
        </div>
      </div>
    </Link>
  );
}

function PlayStoreBadge() {
  return (
    <a
      href={PLAY_STORE_URL}
      target="_blank"
      rel="noopener noreferrer"
      className="inline-flex items-center gap-2.5 bg-[oklch(0.18_0.045_258)] border border-white/15 rounded-lg px-4 py-2.5 transition-all duration-200 ease-out hover:border-white/30 hover:bg-[oklch(0.22_0.052_258)] focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[--color-gold] focus-visible:ring-offset-2 focus-visible:ring-offset-[oklch(0.22_0.052_258)]"
      aria-label="Get the MetroPaws app on Google Play"
    >
      <PlayStoreIcon />
      <div>
        <div className="text-[9px] text-white/55 font-medium leading-none tracking-wide">
          Get it on
        </div>
        <div className="text-sm text-white font-semibold leading-tight mt-0.5">
          Google Play
        </div>
      </div>
    </a>
  );
}

export function AppStoreButtons() {
  return (
    <div className="flex flex-col gap-2">
      <div className="flex flex-row gap-3 flex-wrap">
        <ApkDownloadBadge />
        <PlayStoreBadge />
      </div>
      <div className="flex flex-col gap-1 max-w-[40ch]">
        <p className="text-[10px] text-white/55 leading-snug">
          Google Play for automatic updates · direct download for the newest
          features first
        </p>
        <p className="text-[10px] text-(--color-gold)/85 leading-snug">
          Pick one — the two versions can&apos;t replace each other.{" "}
          <Link href="/download" className="underline underline-offset-2 hover:text-(--color-gold)">
            Which should I choose?
          </Link>
        </p>
      </div>
    </div>
  );
}
