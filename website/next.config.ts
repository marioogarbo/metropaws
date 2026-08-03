import type { NextConfig } from "next";
import { PLAY_STORE_URL } from "./lib/app-download";

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
    ];
  },
};

export default nextConfig;
