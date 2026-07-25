const values = [
  {
    name: "Pioneering Spirit",
    description:
      "We lead the market by creating innovative solutions that prioritize prevention over emergency.",
  },
  {
    name: "Partnership First",
    description:
      'We grow only when our partners and our members grow. We are a "win-win-win" ecosystem.',
  },
  {
    name: "Proactive Care",
    description:
      "We believe the best vet visit is the one where your pet stays healthy, not just the one where they get cured.",
  },
  {
    name: "Premium Service",
    description:
      'From our headquarters to our digital "Pet Pass," we provide a world-class experience for the modern Filipino family.',
  },
];

function ValueCell({
  name,
  description,
  index,
}: {
  name: string;
  description: string;
  index: number;
}) {
  return (
    <div className="py-8 px-0 md:py-12 md:px-10 mp-reveal">
      <p className="text-3xl font-bold leading-none tracking-tight text-(--color-gold)">
        0{index + 1}
      </p>
      <h3 className="mt-5 text-xl font-bold tracking-tight text-(--color-navy)">
        {name}
      </h3>
      <p className="mt-3 text-sm leading-relaxed text-(--color-ink-muted) max-w-[46ch]">
        {description}
      </p>
    </div>
  );
}

export function AboutValues() {
  return (
    <section id="values" className="bg-(--color-cream-warm) py-20 md:py-28">
      <div className="max-w-6xl mx-auto px-6">
        <p className="text-sm font-semibold uppercase tracking-widest text-(--color-gold) mp-reveal">
          What We Stand For
        </p>
        <h2 className="mt-4 text-2xl md:text-3xl font-bold tracking-tight leading-tight text-(--color-navy) mp-reveal">
          The 4 P&apos;s.
        </h2>

        <div className="mt-12">
          {/* Row 1 */}
          <div className="grid grid-cols-1 md:grid-cols-[1fr_1px_1fr]">
            <ValueCell
              name={values[0].name}
              description={values[0].description}
              index={0}
            />
            {/* Mobile divider */}
            <div className="md:hidden h-px bg-(--color-ink-faint)" />
            {/* Desktop vertical divider */}
            <div className="hidden md:block bg-(--color-ink-faint)" />
            <ValueCell
              name={values[1].name}
              description={values[1].description}
              index={1}
            />
          </div>

          {/* Horizontal divider between rows */}
          <div className="h-px bg-(--color-ink-faint)" />

          {/* Row 2 */}
          <div className="grid grid-cols-1 md:grid-cols-[1fr_1px_1fr]">
            <ValueCell
              name={values[2].name}
              description={values[2].description}
              index={2}
            />
            {/* Mobile divider */}
            <div className="md:hidden h-px bg-(--color-ink-faint)" />
            {/* Desktop vertical divider */}
            <div className="hidden md:block bg-(--color-ink-faint)" />
            <ValueCell
              name={values[3].name}
              description={values[3].description}
              index={3}
            />
          </div>
        </div>
      </div>
    </section>
  );
}
