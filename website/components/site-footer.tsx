import Image from "next/image";
import Link from "next/link";
import { Phone, Mail, MapPin } from "lucide-react";
import { PLAY_STORE_URL } from "@/lib/app-download";
import {
  AGREEMENT_UNDER_REVISION,
  MANUAL_UNDER_REVISION,
  MEMBER_MANUAL_PATH,
} from "@/lib/legal-documents";

function FacebookIcon({ className }: { className?: string }) {
  return (
    <svg
      xmlns="http://www.w3.org/2000/svg"
      viewBox="0 0 24 24"
      fill="currentColor"
      className={className}
      aria-hidden="true"
    >
      <path d="M18 2h-3a5 5 0 0 0-5 5v3H7v4h3v8h4v-8h3l1-4h-4V7a1 1 0 0 1 1-1h3z" />
    </svg>
  );
}

type FooterVariant = "navy" | "photo";

interface SiteFooterProps {
  variant?: FooterVariant;
}

const contactItems = [
  { icon: Phone, label: "0920-922-4486", href: "tel:09209224486" },
  { icon: Mail, label: "csr@metropaws.ph", href: "mailto:csr@metropaws.ph" },
  {
    icon: FacebookIcon,
    label: "MetroPaws",
    href: "https://www.facebook.com/people/Metropaws/61588899502470/",
  },
];

const navigateLinks = [
  { label: "Home", href: "/" },
  { label: "Plans & Pricing", href: "/#pricing" },
  { label: "Getting Started", href: "/getting-started" },
  { label: "Find Pet Care", href: "/find-pet-care" },
  { label: "Founding 50", href: "/#founding" },
  { label: "Get the App", href: PLAY_STORE_URL },
  { label: "FAQ", href: "/#faq" },
  { label: "Register", href: "/register" },
];

const companyLinks = [
  { label: "About Us", href: "/about" },
  { label: "Our Mission", href: "/about#mission" },
  { label: "Our Values", href: "/about#values" },
  { label: "Staff Login", href: "/admin/login", muted: false },
];

function FooterContent() {
  return (
    <>
      <div className="max-w-6xl mx-auto px-6 py-16 md:py-20">
        {/*
          Desktop (md+): 4-column grid — logo 2fr, Navigate 1fr, Company 1fr, Contact 2fr.
          Mobile: 2-col grid. Logo and Contact span full width; Navigate and Company
          share a side-by-side row.
        */}
        <div className="grid grid-cols-2 gap-x-8 gap-y-10 md:grid-cols-[2fr_1fr_1fr_2fr] md:gap-x-12 md:gap-y-0">
          {/* Logo */}
          <div className="col-span-2 md:col-span-1 flex flex-col items-start">
            <Image
              src="/logo-full-white-metro.png"
              alt="MetroPaws Wellness Club"
              width={240}
              height={68}
              className="h-16 w-auto"
            />
          </div>

          {/* Navigate */}
          <div className="flex flex-col items-start">
            <span className="text-(--color-gold) text-sm font-semibold uppercase tracking-widest mb-2">
              Navigate
            </span>
            {navigateLinks.map(({ label, href }) => (
              <Link
                key={href}
                href={href}
                className="text-white/90 text-sm py-2 hover:text-(--color-gold) transition-colors duration-150"
              >
                {label}
              </Link>
            ))}
          </div>

          {/* Company */}
          <div className="flex flex-col items-start">
            <span className="text-(--color-gold) text-sm font-semibold uppercase tracking-widest mb-2">
              Company
            </span>
            {companyLinks.map(({ label, href, muted }) => (
              <Link
                key={href}
                href={href}
                className={[
                  "text-sm py-2 transition-colors duration-150",
                  muted
                    ? "text-white/50 hover:text-white/70"
                    : "text-white/90 hover:text-(--color-gold)",
                ].join(" ")}
              >
                {label}
              </Link>
            ))}
          </div>

          {/* Contact */}
          <div className="col-span-2 md:col-span-1 flex flex-col items-start">
            <span className="text-(--color-gold) text-sm font-semibold uppercase tracking-widest mb-2">
              Contact Us
            </span>
            {contactItems.map(({ icon: Icon, label, href }) => (
              <Link
                key={href}
                href={href}
                target={href.startsWith("http") ? "_blank" : undefined}
                rel={href.startsWith("http") ? "noopener noreferrer" : undefined}
                className="flex items-center gap-2.5 text-white/90 text-sm py-2 hover:text-(--color-gold) transition-colors duration-150 group"
              >
                <Icon className="w-4 h-4 shrink-0 text-white/70 group-hover:text-(--color-gold) transition-colors duration-150" />
                {label}
              </Link>
            ))}
            <div className="flex items-start gap-2.5 mt-3">
              <MapPin className="w-4 h-4 shrink-0 text-white/70 mt-0.5" />
              <address className="not-italic text-white/90 text-sm leading-relaxed">
                18 Apollo III, Moonwalk Vill.,
                <br />
                Talon Singko, Las Piñas City 1747
              </address>
            </div>
          </div>
        </div>
      </div>

      <div className="border-t border-white/10">
        <div className="max-w-6xl mx-auto px-6 py-5 flex flex-col md:flex-row items-center justify-between gap-2">
          <p className="text-white/90 text-sm text-center md:text-left">
            © 2026 MetroPaws Wellness Club. All rights reserved.
          </p>
          {/* Documents under revision are pulled from the footer rather than
              linked to their notice page — no point pointing members at a
              placeholder. Privacy Policy always stays. */}
          <div className="flex items-center gap-5">
            {!MANUAL_UNDER_REVISION && (
              <a
                href={MEMBER_MANUAL_PATH}
                target="_blank"
                rel="noopener noreferrer"
                className="text-white/90 text-sm hover:text-(--color-gold) transition-colors duration-150"
              >
                Member Manual
              </a>
            )}
            <Link
              href="/privacy-policy"
              target="_blank"
              rel="noopener noreferrer"
              className="text-white/90 text-sm hover:text-(--color-gold) transition-colors duration-150"
            >
              Privacy Policy
            </Link>
            {!AGREEMENT_UNDER_REVISION && (
              <Link
                href="/terms-of-service"
                target="_blank"
                rel="noopener noreferrer"
                className="text-white/90 text-sm hover:text-(--color-gold) transition-colors duration-150"
              >
                Membership Agreement
              </Link>
            )}
          </div>
        </div>
      </div>
    </>
  );
}

export function SiteFooter({ variant = "navy" }: SiteFooterProps) {
  if (variant === "photo") {
    return (
      <footer className="relative">
        <Image
          src="/hero-background.png"
          alt=""
          fill
          sizes="100vw"
          className="object-cover object-center"
          aria-hidden="true"
        />
        <div
          aria-hidden="true"
          className="absolute inset-0"
          style={{ background: "oklch(0.22 0.052 258 / 0.76)" }}
        />
        <div className="relative z-10">
          <FooterContent />
        </div>
      </footer>
    );
  }

  return (
    <footer className="bg-(--color-navy)">
      <FooterContent />
    </footer>
  );
}
