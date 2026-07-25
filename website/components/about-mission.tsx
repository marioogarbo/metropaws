export function AboutMission() {
  return (
    <section id="mission" className="bg-(--color-cream) py-24 md:py-32">
      <div className="max-w-6xl mx-auto px-6">
        {/* Section heading */}
        <p className="text-sm font-semibold uppercase tracking-widest text-(--color-gold) mp-reveal">
          Our Purpose
        </p>
        <h2 className="mt-4 text-2xl md:text-3xl font-bold tracking-tight leading-tight text-(--color-navy) mp-reveal">
          Where we&apos;re going and why.
        </h2>

        <div className="mt-14 grid grid-cols-1 md:grid-cols-[1fr_1px_1fr]">
          {/* Mission */}
          <div className="pb-14 md:pb-0 md:pr-16 mp-reveal">
            <p className="text-base font-bold uppercase tracking-widest text-(--color-navy)">
              Mission
            </p>
            <div className="mt-5 w-12 h-0.5 bg-(--color-gold)" />
            <p className="mt-6 text-sm font-medium leading-relaxed text-(--color-ink-muted) max-w-[52ch]">
              Our mission is to bridge the gap between pet owners and quality veterinary
              care. We achieve this by building a trusted network of partner clinics,
              providing predictable and affordable wellness plans, and fostering a
              supportive community for the South&apos;s most dedicated pet parents.
            </p>
          </div>

          {/* Mobile horizontal divider */}
          <div className="md:hidden h-px bg-(--color-ink-faint)" />

          {/* Desktop vertical divider column */}
          <div className="hidden md:block bg-(--color-ink-faint)" />

          {/* Vision */}
          <div className="pt-14 md:pt-0 md:pl-16 mp-reveal">
            <p className="text-base font-bold uppercase tracking-widest text-(--color-navy)">
              Vision
            </p>
            <div className="mt-5 w-12 h-0.5 bg-(--color-gold)" />
            <p className="mt-6 text-sm font-medium leading-relaxed text-(--color-ink-muted) max-w-[52ch]">
              To become the gold standard of proactive pet parenting in the Philippines,
              creating a future where every pet lives a longer, healthier life through
              accessible and community-driven wellness.
            </p>
          </div>
        </div>
      </div>
    </section>
  );
}
