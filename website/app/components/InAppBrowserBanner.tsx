"use client";

import { useEffect, useState } from "react";

function detectInAppBrowser(): { detected: boolean; isIOS: boolean; app: string } {
  if (typeof navigator === "undefined") return { detected: false, isIOS: false, app: "" };

  const ua = navigator.userAgent;
  const isIOS = /iPhone|iPad|iPod/.test(ua);

  if (/FBAN|FBAV|FB_IAB|FBIOS/.test(ua)) return { detected: true, isIOS, app: "Facebook" };
  if (/Instagram/.test(ua)) return { detected: true, isIOS, app: "Instagram" };

  return { detected: false, isIOS, app: "" };
}

export default function InAppBrowserBanner() {
  const [info, setInfo] = useState<{ detected: boolean; isIOS: boolean; app: string } | null>(null);

  useEffect(() => {
    setInfo(detectInAppBrowser());
  }, []);

  if (!info?.detected) return null;

  const instructions = info.isIOS
    ? `Tap the ${info.app === "Instagram" ? "⋯" : "⋮"} menu → "Open in Safari"`
    : `Tap the ⋮ menu → "Open in Chrome"`;

  return (
    <div
      style={{
        position: "fixed",
        top: 0,
        left: 0,
        right: 0,
        zIndex: 9999,
        background: "#1a1a1a",
        borderBottom: "2px solid #D4AF37",
        padding: "12px 16px",
        display: "flex",
        alignItems: "center",
        gap: "10px",
        fontFamily: "sans-serif",
      }}
    >
      {/* Dog paw icon */}
      <span style={{ fontSize: "20px", flexShrink: 0 }}>🐾</span>

      <div style={{ flex: 1 }}>
        <p style={{ margin: 0, fontSize: "13px", fontWeight: 700, color: "#D4AF37", lineHeight: 1.3 }}>
          Buttons not working?
        </p>
        <p style={{ margin: 0, fontSize: "12px", color: "#e5e5e5", lineHeight: 1.4 }}>
          {instructions} for the full experience.
        </p>
      </div>
    </div>
  );
}
