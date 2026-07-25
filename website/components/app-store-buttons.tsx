import Link from "next/link";

function AndroidIcon() {
  return (
    <svg width="20" height="20" viewBox="0 0 24 24" fill="white" aria-hidden="true">
      <path d="M6 18c0 .55.45 1 1 1h1v3.5c0 .83.67 1.5 1.5 1.5s1.5-.67 1.5-1.5V19h2v3.5c0 .83.67 1.5 1.5 1.5s1.5-.67 1.5-1.5V19h1c.55 0 1-.45 1-1V8H6v10zM3.5 8C2.67 8 2 8.67 2 9.5v7c0 .83.67 1.5 1.5 1.5S5 17.33 5 16.5v-7C5 8.67 4.33 8 3.5 8zm17 0c-.83 0-1.5.67-1.5 1.5v7c0 .83.67 1.5 1.5 1.5s1.5-.67 1.5-1.5v-7c0-.83-.67-1.5-1.5-1.5zm-4.97-5.84l1.3-1.3c.2-.2.2-.51 0-.71-.2-.2-.51-.2-.71 0l-1.48 1.48C14.15 1.23 13.1 1 12 1c-1.1 0-2.15.23-3.1.63L7.43.15c-.2-.2-.51-.2-.71 0-.2.2-.2.51 0 .71l1.31 1.31C6.97 3.26 6 5.01 6 7h12c0-1.99-.97-3.75-2.47-4.84zM10 5H9V4h1v1zm5 0h-1V4h1v1z" />
    </svg>
  );
}

function AppleIcon() {
  return (
    <svg width="20" height="20" viewBox="0 0 24 24" fill="white" aria-hidden="true">
      <path d="M18.71 19.5c-.83 1.24-1.71 2.45-3.05 2.47-1.34.03-1.77-.79-3.29-.79-1.53 0-2 .77-3.27.82-1.31.05-2.3-1.32-3.14-2.53C4.25 17 2.94 12.45 4.7 9.39c.87-1.52 2.43-2.48 4.12-2.51 1.28-.02 2.5.87 3.29.87.78 0 2.26-1.07 3.8-.91.65.03 2.47.26 3.64 1.98-.09.06-2.17 1.28-2.15 3.81.03 3.02 2.65 4.03 2.68 4.04-.03.07-.42 1.44-1.38 2.83M13 3.5c.73-.83 1.94-1.46 2.94-1.5.13 1.17-.34 2.35-1.04 3.19-.69.85-1.83 1.51-2.95 1.42-.15-1.15.41-2.35 1.05-3.11z" />
    </svg>
  );
}

function PlayStoreIcon() {
  return (
    <svg width="18" height="20" viewBox="0 0 18 20" fill="none" aria-hidden="true">
      <path
        d="M0.426 0.18C0.16.432 0 .826 0 1.337v17.326c0 .511.16.905.426 1.157l.06.058L10.104 10v-.178L.487.12z"
        fill="#4285F4"
      />
      <path
        d="M13.356 13.37l-3.252-3.37v-.178l3.252-3.37.073.042 3.855 2.19c1.1.625 1.1 1.649 0 2.274l-3.855 2.19z"
        fill="#FBBC04"
      />
      <path
        d="M13.43 13.328L10.104 10 0.426 19.82c.362.383.958.43 1.623.049L13.43 13.328z"
        fill="#EA4335"
      />
      <path
        d="M13.43 6.672L2.049.131C1.384-.25.788-.203.426.18L10.104 10z"
        fill="#34A853"
      />
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

function PlayStoreComingSoon() {
  return (
    <div
      role="img"
      aria-label="Google Play Store – coming soon"
      className="inline-flex items-center gap-2.5 bg-[oklch(0.18_0.045_258)] border border-white/15 rounded-lg px-4 py-2.5 cursor-not-allowed select-none"
    >
      <PlayStoreIcon />
      <div>
        <div className="text-[9px] text-white/55 font-medium leading-none tracking-wide">
          Coming soon on
        </div>
        <div className="text-sm text-white font-semibold leading-tight mt-0.5">Google Play</div>
      </div>
    </div>
  );
}

function AppStoreComingSoon() {
  return (
    <div
      role="img"
      aria-label="iOS App Store – coming soon"
      className="inline-flex items-center gap-2.5 bg-[oklch(0.18_0.045_258)] border border-white/8 rounded-lg px-4 py-2.5 opacity-40 cursor-not-allowed select-none"
    >
      <AppleIcon />
      <div>
        <div className="text-[9px] text-white/55 font-medium leading-none tracking-wide">
          Coming soon on
        </div>
        <div className="text-sm text-white font-semibold leading-tight mt-0.5">App Store</div>
      </div>
    </div>
  );
}

export function AppStoreButtons() {
  return (
    <div className="flex flex-col gap-2">
      <div className="flex flex-row gap-3 flex-wrap">
        <ApkDownloadBadge />
        <PlayStoreComingSoon />
        {/* <AppStoreComingSoon /> */}
      </div>
      <p className="text-[10px] text-white/55 leading-snug max-w-[38ch]">
        Android now — quick download with step-by-step install instructions
      </p>
    </div>
  );
}
