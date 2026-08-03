"use client";

import { useState } from "react";
import Image from "next/image";
import Link from "next/link";
import { X, Menu } from "lucide-react";
import { cn } from "@/lib/utils";
import { PLAY_STORE_URL } from "@/lib/app-download";

// Nav entries are a mix of in-site routes and the Play Store listing, so the
// external ones are told apart by their href rather than by a flag to keep.
const isExternal = (href: string) => href.startsWith("http");

export function SiteHeader() {
  const [barVisible, setBarVisible] = useState(true);
  const [menuOpen, setMenuOpen] = useState(false);

  const navLinks = [
    { label: "About", href: "/about" },
    { label: "Founding", href: "/#founding" },
    { label: "Pricing", href: "/#pricing" },
    { label: "Get the App", href: PLAY_STORE_URL },
    { label: "FAQ", href: "/#faq" },
    { label: "Contact Us", href: "/#contact" },
  ] as const;

  return (
    <header className="sticky top-0 z-50">
      {/* Announcement bar */}
      <div
        className="overflow-hidden transition-all duration-200 ease-out"
        style={{ display: "grid", gridTemplateRows: barVisible ? "1fr" : "0fr" }}
      >
        <div className="min-h-0 overflow-hidden">
          <div className="bg-(--color-navy)">
            {/* Desktop */}
            <div className="hidden md:flex items-center justify-center gap-3 py-3 px-12 relative">
              <button
                onClick={() => setBarVisible(false)}
                className="absolute right-4 top-1/2 -translate-y-1/2 text-white/40 hover:text-white/80 transition-colors p-1 rounded"
                aria-label="Dismiss announcement"
              >
                <X className="w-4 h-4" />
              </button>
              <span className="text-(--color-gold) text-sm font-bold uppercase tracking-widest">
                FOUNDING 50
              </span>
              <span className="text-white/25 text-sm select-none">|</span>
              <span className="text-white/85 text-sm">
                Locked-in pricing for our first 50 families. Spots are open now.
              </span>
              <Link
                href="/#founding"
                className="text-(--color-gold) text-sm font-semibold ml-2 hover:opacity-75 transition-opacity"
              >
                Reserve yours →
              </Link>
            </div>

            {/* Mobile — single condensed line */}
            <div className="md:hidden relative flex items-center justify-center gap-2 px-10 py-2.5">
              <button
                onClick={() => setBarVisible(false)}
                className="absolute right-3 top-1/2 -translate-y-1/2 text-white/40 hover:text-white/80 transition-colors p-1 rounded"
                aria-label="Dismiss announcement"
              >
                <X className="w-3.5 h-3.5" />
              </button>
              <span className="text-(--color-gold) text-xs font-bold uppercase tracking-widest shrink-0">
                FOUNDING 50
              </span>
              <span className="text-white/25 text-xs select-none">·</span>
              <Link
                href="/#founding"
                onClick={() => setMenuOpen(false)}
                className="text-white/80 text-xs font-medium hover:text-(--color-gold) transition-colors truncate"
              >
                Spots open — Reserve yours
              </Link>
            </div>
          </div>
        </div>
      </div>

      {/* Navbar */}
      <nav className="bg-(--color-surface) border-b border-(--color-ink-faint) h-16">
        <div className="max-w-7xl mx-auto px-4 md:px-6 h-full flex items-center justify-between">
          {/* Logo */}
          <Link href="/" className="shrink-0">
            <Image
              src="/logo-full.png"
              alt="MetroPaws Wellness Club"
              width={160}
              height={44}
              className="h-8 md:h-10 w-auto"
              priority
            />
          </Link>

          {/* Desktop nav links */}
          <div className="hidden md:flex items-center gap-8">
            {navLinks.map(({ label, href }) => (
              <Link
                key={label}
                href={href}
                {...(isExternal(href)
                  ? { target: "_blank", rel: "noopener noreferrer" }
                  : {})}
                className="text-sm font-medium text-(--color-ink-muted) hover:text-(--color-navy) transition-colors"
              >
                {label}
              </Link>
            ))}
          </div>

          {/* Desktop CTAs */}
          <div className="hidden md:flex items-center gap-3 shrink-0">
            <Link
              href="/#founding"
              className="inline-flex bg-(--color-gold) text-(--color-navy) text-sm font-semibold rounded-lg px-5 py-2.5 hover:brightness-105 transition-all whitespace-nowrap"
            >
              Reserve Your Spot
            </Link>
            <Link
              href="/register"
              className="text-sm font-medium text-(--color-ink-muted) hover:text-(--color-navy) transition-colors"
            >
              Sign up
            </Link>
          </div>

          {/* Mobile hamburger — logo fills left, this fills right */}
          <button
            className="md:hidden text-(--color-ink-muted) p-2 -mr-2 hover:text-(--color-navy) transition-colors rounded min-w-11 min-h-11 flex items-center justify-center"
            onClick={() => setMenuOpen(!menuOpen)}
            aria-label={menuOpen ? "Close menu" : "Open menu"}
            aria-expanded={menuOpen}
          >
            {menuOpen ? <X className="w-5 h-5" /> : <Menu className="w-5 h-5" />}
          </button>
        </div>

        {/* Mobile dropdown */}
        <div
          className="md:hidden overflow-hidden transition-all duration-200 ease-out"
          style={{ display: "grid", gridTemplateRows: menuOpen ? "1fr" : "0fr" }}
        >
          <div className="min-h-0 overflow-hidden bg-(--color-surface) border-t border-(--color-ink-faint)">
            <div className="flex flex-col px-6 pb-6">
              {navLinks.map(({ label, href }, i) => (
                <Link
                  key={label}
                  href={href}
                  {...(isExternal(href)
                    ? { target: "_blank", rel: "noopener noreferrer" }
                    : {})}
                  onClick={() => setMenuOpen(false)}
                  className={cn(
                    "py-4 text-sm font-medium text-(--color-ink-muted) hover:text-(--color-navy) transition-colors",
                    i < navLinks.length - 1 && "border-b border-(--color-ink-faint)",
                  )}
                >
                  {label}
                </Link>
              ))}
              <Link
                href="/#founding"
                onClick={() => setMenuOpen(false)}
                className="mt-5 bg-(--color-gold) text-(--color-navy) text-sm font-semibold rounded-lg px-5 py-3 hover:brightness-105 transition-all text-center"
              >
                Reserve Your Spot
              </Link>
              <Link
                href="/register"
                onClick={() => setMenuOpen(false)}
                className="mt-3 text-sm font-medium text-(--color-ink-muted) hover:text-(--color-navy) transition-colors text-center"
              >
                or create an account
              </Link>
            </div>
          </div>
        </div>
      </nav>
    </header>
  );
}
