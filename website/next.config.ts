import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  devIndicators: false,
  output: "standalone",
  // Don't let ESLint style nits (e.g. <a> vs <Link>, unescaped apostrophes)
  // fail the production build/deploy — lint is run separately via `npm run
  // lint`. Type errors still block the build, so correctness is preserved.
  eslint: { ignoreDuringBuilds: true },
};

export default nextConfig;
