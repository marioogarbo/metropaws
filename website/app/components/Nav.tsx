"use client";
import { useEffect, useState } from "react";
import Image from "next/image";
import Link from "next/link";
import { Menu, X } from "lucide-react";

export default function Nav() {
  const [scrolled, setScrolled] = useState(false);
  const [open, setOpen] = useState(false);

  useEffect(() => {
    const handler = () => setScrolled(window.scrollY > 16);
    handler();
    window.addEventListener("scroll", handler, { passive: true });
    return () => window.removeEventListener("scroll", handler);
  }, []);

  return (
    <div className="sticky top-0 z-50">
      {/* Contact utility bar — desktop only */}
      <div className="hidden md:flex items-center justify-end gap-5 px-8 py-1.5 bg-(--navy) text-white text-xs">
        <a href="tel:09209224486" className="hover:text-(--gold) transition-colors">
          0920 922 4486
        </a>
        <a href="mailto:csr@metropaws.ph" className="hover:text-(--gold) transition-colors">
          csr@metropaws.ph
        </a>
      </div>
      <nav
        className={`flex items-center justify-between px-4 sm:px-5 md:px-8 py-3 sm:py-4 bg-white border-b border-(--grey-light) transition-shadow duration-300 ${
          scrolled ? "shadow-[0_2px_16px_0_rgba(38,50,88,0.10)]" : "shadow-none"
        }`}
      >
        {/* Logo — left */}
        <div className="flex-1">
          <Link href="/" onClick={() => setOpen(false)}>
            <Image
              src="/logo-full.png"
              alt="MetroPaws"
              width={0}
              height={0}
              sizes="(max-width: 640px) 140px, (max-width: 768px) 180px, 200px"
              className="object-contain w-35 sm:w-45 md:w-50 h-auto"
              priority
            />
          </Link>
        </div>

        {/* Nav links — centered */}
        <div className="hidden sm:flex items-center gap-4 sm:gap-6">
          <Link
            href="/about"
            className="text-sm font-medium text-(--text)/65 hover:text-(--navy) transition-colors whitespace-nowrap rounded focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-(--navy)/40"
          >
            About
          </Link>
          <Link
            href="/#pricing"
            className="text-sm font-medium text-(--text)/65 hover:text-(--navy) transition-colors whitespace-nowrap hidden md:inline-block rounded focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-(--navy)/40"
          >
            Pricing
          </Link>
          <Link
            href="/#faq"
            className="text-sm font-medium text-(--text)/65 hover:text-(--navy) transition-colors whitespace-nowrap hidden md:inline-block rounded focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-(--navy)/40"
          >
            FAQ
          </Link>
        </div>

        {/* CTA + hamburger — right */}
        <div className="flex-1 flex items-center justify-end gap-2 sm:gap-3">
          <a
            href="/#founding-50"
            className="inline-flex items-center px-3 sm:px-5 py-2.5 min-h-10 rounded-xl bg-(--gold) text-(--navy) font-semibold text-xs sm:text-sm whitespace-nowrap transition hover:bg-(--gold-dark) hover:scale-[1.02] active:scale-[0.97] shadow-sm focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-(--gold)/60"
          >
            Reserve Your Spot
          </a>
          <button
            className="sm:hidden w-11 h-11 flex items-center justify-center rounded-xl text-(--text)/60 hover:bg-(--grey-light) transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-(--navy)/40"
            onClick={() => setOpen((o) => !o)}
            aria-label={open ? "Close menu" : "Open menu"}
            aria-expanded={open}
          >
            {open ? <X className="w-5 h-5" /> : <Menu className="w-5 h-5" />}
          </button>
        </div>
      </nav>

      {/* Mobile dropdown drawer */}
      <div
        className={`sm:hidden bg-white border-b border-(--grey-light) grid transition-[grid-template-rows] duration-300 ease-out ${
          open ? "grid-rows-[1fr]" : "grid-rows-[0fr]"
        }`}
      >
        <div className="overflow-hidden">
          <div className="px-4 pt-2 pb-5 flex flex-col">
            {/* Utility nav links */}
            <div className="flex flex-col gap-0.5">
              <Link
                href="/about"
                className="flex items-center px-3 min-h-11 rounded-xl text-(--text) font-medium text-sm hover:bg-(--navy-light) transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-(--navy)/40"
                onClick={() => setOpen(false)}
              >
                About
              </Link>
              <Link
                href="/#pricing"
                className="flex items-center px-3 min-h-11 rounded-xl text-(--text) font-medium text-sm hover:bg-(--navy-light) transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-(--navy)/40"
                onClick={() => setOpen(false)}
              >
                Pricing
              </Link>
              <Link
                href="/#faq"
                className="flex items-center px-3 min-h-11 rounded-xl text-(--text) font-medium text-sm hover:bg-(--navy-light) transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-(--navy)/40"
                onClick={() => setOpen(false)}
              >
                FAQ
              </Link>
            </div>

            {/* Divider */}
            <div className="my-3 border-t border-(--grey-light)" />

            {/* Founding 50 — featured card */}
            <a
              href="/#founding-50"
              className="flex items-center justify-between px-4 py-3 rounded-xl bg-(--gold-light) border border-(--gold)/20 hover:bg-(--gold)/15 transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-(--gold)/40 mb-4"
              onClick={() => setOpen(false)}
            >
              <div>
                <p className="font-(family-name:--font-baloo2) font-bold text-(--gold-muted) text-sm leading-tight">
                  Founding 50
                </p>
                <p className="text-(--text)/50 text-[11px] mt-0.5 leading-snug">
                  Limited founding spots open
                </p>
              </div>
              <span className="text-(--gold-muted) font-semibold text-sm shrink-0">
                →
              </span>
            </a>

            {/* Contact links */}
            <div className="flex flex-col gap-0.5 mb-3">
              <a
                href="tel:09209224486"
                className="flex items-center px-3 min-h-11 rounded-xl text-(--text)/70 text-sm hover:bg-(--navy-light) transition-colors"
              >
                0920 922 4486
              </a>
              <a
                href="mailto:csr@metropaws.ph"
                className="flex items-center px-3 min-h-11 rounded-xl text-(--text)/70 text-sm hover:bg-(--navy-light) transition-colors"
              >
                csr@metropaws.ph
              </a>
            </div>

            {/* Primary CTA */}
            <Link
              href="/register"
              className="flex items-center justify-center px-4 min-h-12 rounded-xl bg-(--navy) text-white font-(family-name:--font-baloo2) font-bold text-sm hover:bg-(--navy-dark) active:scale-[0.98] transition-all focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-(--navy)/40"
              onClick={() => setOpen(false)}
            >
              Get Your Pet&apos;s QR ID — Free →
            </Link>
            <p className="text-(--grey) text-[11px] text-center mt-2">
              Free to register · Annual plans available
            </p>
          </div>
        </div>
      </div>
    </div>
  );
}
