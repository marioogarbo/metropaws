import Image from "next/image";
import Link from "next/link";

type FooterProps = {
  variant?: "full" | "minimal";
};

export default function Footer({ variant = "full" }: FooterProps) {
  if (variant === "minimal") {
    return (
      <footer className="border-t border-(--grey-light) bg-white mt-auto">
        <div className="max-w-5xl mx-auto px-5 sm:px-6 md:px-8 py-8 flex flex-col sm:flex-row items-center justify-between gap-4">
          <div className="flex items-center gap-2">
            <Image
              src="/logo-icon.png"
              alt="MetroPaws logo"
              width={24}
              height={24}
              className="object-contain w-6 h-6 shrink-0"
            />
            <span className="text-xs text-(--grey)">
              © 2026 MetroPaws Wellness Club Philippines, Inc.
            </span>
          </div>
          <Link
            href="/"
            className="text-xs text-(--navy) hover:underline transition-colors min-h-11 inline-flex items-center"
          >
            ← Back to home
          </Link>
        </div>
      </footer>
    );
  }

  return (
    <footer className="border-t border-(--grey-light) bg-white">
      <div className="max-w-5xl mx-auto px-5 sm:px-6 md:px-8 py-10 md:py-16 flex flex-col gap-10 md:gap-12">
        {/* Brand Section */}
        <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4 sm:gap-6 pb-8 md:pb-10 border-b border-(--grey-light)">
          <div className="flex items-center gap-2">
            <Image
              src="/logo-icon.png"
              alt="MetroPaws logo"
              width={24}
              height={24}
              className="object-contain w-6 h-6 shrink-0"
            />
            <span className="text-xs text-(--grey) leading-tight">
              © 2026 MetroPaws{" "}<br className="sm:hidden" />Wellness Club Philippines, Inc.
            </span>
          </div>
          <Link
            href="/admin/login"
            className="text-xs text-(--text)/70 hover:text-(--navy) transition-colors whitespace-nowrap min-h-[44px] inline-flex items-center rounded focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-(--navy)/40"
          >
            Staff sign in →
          </Link>
        </div>

        {/* Info Cards Grid */}
        <div className="grid grid-cols-1 md:grid-cols-3 gap-6 md:gap-8 pb-8 md:pb-10 border-b border-(--grey-light)">
          <div>
            <p className="font-(family-name:--font-baloo2) font-bold text-(--text) text-sm mb-2">
              Membership
            </p>
            <p className="text-(--grey) text-xs leading-relaxed">
              Your membership lives at the clinic. MetroPaws is free to use — annual
              plan billing is handled directly at your partner clinic.
            </p>
          </div>
          <div>
            <p className="font-(family-name:--font-baloo2) font-bold text-(--text) text-sm mb-2">
              Coverage
            </p>
            <p className="text-(--grey) text-xs leading-relaxed">
              Partner clinics across Metro Manila — Quezon City, Makati, Pasig, and
              more.
            </p>
          </div>
          <div>
            <p className="font-(family-name:--font-baloo2) font-bold text-(--text) text-sm mb-2">
              Get in touch
            </p>
            <div className="flex flex-col gap-1.5">
              <a
                href="tel:09209224486"
                className="text-(--navy) text-xs hover:underline transition-colors"
              >
                0920 922 4486
              </a>
              <a
                href="mailto:csr@metropaws.ph"
                className="text-(--navy) text-xs hover:underline transition-colors"
              >
                csr@metropaws.ph
              </a>
              <Link
                href="https://www.facebook.com/people/Metropaws/61588899502470"
                target="_blank"
                rel="noopener noreferrer"
                className="text-(--navy) text-xs hover:underline transition-colors py-2 -my-2 inline-block focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-(--navy)/40 rounded"
              >
                Message us on Facebook →
              </Link>
            </div>
          </div>
        </div>

        {/* Policy Links */}
        <div className="flex flex-row items-center gap-3 text-xs text-(--grey)">
          <Link
            href="/privacy-policy"
            className="hover:text-(--navy) transition-colors min-h-11 inline-flex items-center rounded focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-(--navy)/40"
          >
            Privacy Policy
          </Link>
          <span>•</span>
          <Link
            href="/terms-of-service"
            className="hover:text-(--navy) transition-colors min-h-11 inline-flex items-center rounded focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-(--navy)/40"
          >
            Terms of Service
          </Link>
        </div>
      </div>
    </footer>
  );
}
