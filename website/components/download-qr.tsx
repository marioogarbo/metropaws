"use client";

import { useEffect, useState } from "react";
import QRCode from "react-qr-code";

/**
 * Scan-to-phone QR for the download page. A member browsing on a laptop can
 * point their phone camera at this to open /download directly on the device
 * they'll actually install on. Built from the live origin so it's correct in
 * every environment (localhost, staging, prod) with nothing hardcoded.
 */
export function DownloadQr() {
  const [url, setUrl] = useState<string | null>(null);

  useEffect(() => {
    setUrl(`${window.location.origin}/download`);
  }, []);

  return (
    <div className="flex flex-col items-center gap-3">
      <div className="rounded-2xl bg-white p-4 shadow-[0_1px_2px_oklch(0.24_0.055_258/0.08)]">
        {/* Fixed box avoids layout shift while the origin resolves on mount */}
        <div className="flex size-32 items-center justify-center">
          {url ? (
            <QRCode
              value={url}
              size={128}
              level="M"
              bgColor="#ffffff"
              fgColor="oklch(0.24 0.055 258)"
              style={{ height: "128px", width: "128px" }}
            />
          ) : (
            <div className="size-32 animate-pulse rounded-lg bg-(--color-ink-faint)/40" />
          )}
        </div>
      </div>
      <p className="max-w-[20ch] text-center text-xs text-white/55 leading-snug">
        On a computer? Scan to open this page on your phone.
      </p>
    </div>
  );
}
