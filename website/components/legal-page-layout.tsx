"use client";

import { useState, useEffect } from "react";
import Link from "next/link";
import { ChevronDown, ArrowUp } from "lucide-react";
import { cn } from "@/lib/utils";

interface TocSection {
  id: string;
  title: string;
}

interface LegalPageLayoutProps {
  eyebrow: string;
  title: string;
  lastUpdated: string;
  sections: TocSection[];
  crossLink: { label: string; href: string };
  children: React.ReactNode;
}

export function LegalPageLayout({
  eyebrow,
  title,
  lastUpdated,
  sections,
  crossLink,
  children,
}: LegalPageLayoutProps) {
  const [activeId, setActiveId] = useState<string>(sections[0]?.id ?? "");
  const [mobileTocOpen, setMobileTocOpen] = useState(false);
  const [showBackToTop, setShowBackToTop] = useState(false);

  useEffect(() => {
    const observer = new IntersectionObserver(
      (entries) => {
        entries.forEach((entry) => {
          if (entry.isIntersecting) {
            setActiveId(entry.target.id);
          }
        });
      },
      { rootMargin: "-10% 0% -80% 0%", threshold: 0 },
    );

    sections.forEach(({ id }) => {
      const el = document.getElementById(id);
      if (el) observer.observe(el);
    });

    return () => observer.disconnect();
  }, [sections]);

  useEffect(() => {
    const onScroll = () => setShowBackToTop(window.scrollY > 300);
    window.addEventListener("scroll", onScroll, { passive: true });
    return () => window.removeEventListener("scroll", onScroll);
  }, []);

  return (
    <div className="bg-(--color-cream) flex-1">
      {/* Page header */}
      <div className="bg-(--color-surface) border-b border-(--color-ink-faint)">
        <div className="max-w-6xl mx-auto px-6 py-12 md:py-16">
          <p className="text-sm font-semibold uppercase tracking-widest text-(--color-gold) mb-3">
            {eyebrow}
          </p>
          <h1 className="text-3xl md:text-4xl font-bold text-(--color-navy) tracking-tight leading-tight mb-3">
            {title}
          </h1>
          <p className="text-sm text-(--color-ink-muted)">
            Last updated: {lastUpdated}
          </p>
        </div>
      </div>

      {/* Mobile TOC — sticky below header */}
      <div className="md:hidden bg-(--color-surface) border-b border-(--color-ink-faint) sticky top-16 z-40">
        <button
          onClick={() => setMobileTocOpen((v) => !v)}
          className="w-full flex items-center justify-between px-6 py-3.5 text-sm font-medium text-(--color-ink)"
          aria-expanded={mobileTocOpen}
          aria-controls="mobile-toc"
        >
          <span>Jump to section</span>
          <ChevronDown
            className={cn(
              "w-4 h-4 text-(--color-ink-muted) transition-transform duration-200 ease-out",
              mobileTocOpen && "rotate-180",
            )}
          />
        </button>
        <div
          id="mobile-toc"
          className="overflow-hidden transition-all duration-200 ease-out"
          style={{ display: "grid", gridTemplateRows: mobileTocOpen ? "1fr" : "0fr" }}
        >
          <div className="min-h-0 overflow-hidden">
            <nav
              className="flex flex-col pb-4 px-6 gap-0.5"
              aria-label="Page sections"
            >
              {sections.map(({ id, title }) => (
                <a
                  key={id}
                  href={`#${id}`}
                  onClick={() => setMobileTocOpen(false)}
                  className={cn(
                    "text-sm py-2 transition-colors duration-150",
                    activeId === id
                      ? "text-(--color-navy) font-semibold"
                      : "text-(--color-ink-muted) hover:text-(--color-navy)",
                  )}
                >
                  {title}
                </a>
              ))}
            </nav>
          </div>
        </div>
      </div>

      {/* Content + sidebar */}
      <div className="max-w-6xl mx-auto px-6 py-12 md:py-16">
        <div className="md:grid md:grid-cols-[220px_1fr] md:gap-16 lg:gap-20">
          {/* Desktop sidebar TOC */}
          <aside className="hidden md:block">
            <nav
              className="sticky top-24 flex flex-col gap-0.5"
              aria-label="Page sections"
            >
              <p className="text-xs font-semibold uppercase tracking-widest text-(--color-gold) mb-4">
                Contents
              </p>
              {sections.map(({ id, title }) => (
                <a
                  key={id}
                  href={`#${id}`}
                  className={cn(
                    "text-sm py-1.5 leading-snug transition-colors duration-150 pr-2",
                    activeId === id
                      ? "text-(--color-navy) font-semibold"
                      : "text-(--color-ink-muted) hover:text-(--color-navy)",
                  )}
                >
                  {title}
                </a>
              ))}
              <div className="mt-8 pt-6 border-t border-(--color-ink-faint)">
                <Link
                  href={crossLink.href}
                  className="text-sm text-(--color-ink-muted) hover:text-(--color-navy) transition-colors leading-snug"
                >
                  {crossLink.label} →
                </Link>
              </div>
            </nav>
          </aside>

          {/* Document */}
          <article className="min-w-0">
            {children}
            <div className="md:hidden mt-12 pt-6 border-t border-(--color-ink-faint)">
              <Link
                href={crossLink.href}
                className="text-sm text-(--color-ink-muted) hover:text-(--color-navy) transition-colors"
              >
                {crossLink.label} →
              </Link>
            </div>
          </article>
        </div>
      </div>

      {/* Back to top — mobile */}
      <button
        onClick={() => window.scrollTo({ top: 0, behavior: "smooth" })}
        aria-label="Back to top"
        className={cn(
          "md:hidden fixed bottom-6 right-6 z-50 bg-(--color-navy) text-white rounded-full w-11 h-11 flex items-center justify-center transition-all duration-200 ease-out",
          showBackToTop
            ? "opacity-100 translate-y-0"
            : "opacity-0 translate-y-2 pointer-events-none",
        )}
      >
        <ArrowUp className="w-4 h-4" />
      </button>
    </div>
  );
}
