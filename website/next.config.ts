import type { NextConfig } from "next";
import { PLAY_STORE_URL } from "./lib/app-download";
import {
  MANUAL_NOTICE_PATH,
  MANUAL_UNDER_REVISION,
  MEMBER_MANUAL_PATH,
} from "./lib/legal-documents";

const nextConfig: NextConfig = {
  devIndicators: false,
  output: "standalone",
  // Don't let ESLint style nits (e.g. <a> vs <Link>, unescaped apostrophes)
  // fail the production build/deploy — lint is run separately via `npm run
  // lint`. Type errors still block the build, so correctness is preserved.
  eslint: { ignoreDuringBuilds: true },

  // /download existed for months and its URL is out in the world — the QR code
  // that page printed, links sent to members, bookmarks. Send those to the Play
  // Store listing rather than a 404.
  //
  // Temporary (307) rather than permanent: an iOS launch is the obvious moment
  // to bring the page back with both store badges, and browsers cache a 308
  // hard enough that anyone who followed one would never reach the new page.
  async redirects() {
    return [
      { source: "/download", destination: PLAY_STORE_URL, permanent: false },
      // The guide started life as payment-only at /how-to-pay before it grew to
      // cover account creation through activation. Temporary (307) for the same
      // reason as above: the scope could move again, and a cached 308 would
      // outlive the decision.
      {
        source: "/how-to-pay",
        destination: "/getting-started",
        permanent: false,
      },
    ];
  },

  // The Member Manual PDF is being rewritten (see lib/legal-documents.ts), but
  // the Android app on Play links straight to the PDF path from its Account
  // section, so that URL must keep resolving. `beforeFiles` is the only phase
  // that runs ahead of the public/ file handler, which is what lets this shadow
  // the still-present PDF instead of serving it. A rewrite, not a redirect, so
  // the app's in-app browser doesn't bounce to a different address.
  async rewrites() {
    return {
      beforeFiles: MANUAL_UNDER_REVISION
        ? [{ source: MEMBER_MANUAL_PATH, destination: MANUAL_NOTICE_PATH }]
        : [],
      afterFiles: [],
      fallback: [],
    };
  },
};

export default nextConfig;
