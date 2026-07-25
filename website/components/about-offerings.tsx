const offerings = [
  {
    id: "01",
    name: "The 5K Shield",
    description:
      "Our signature emergency protection providing an annual coverage limit of ₱5,000.",
  },
  {
    id: "02",
    name: "Routine Wellness Packages",
    description:
      'Guaranteed access to professional grooming and essential vaccinations, tracked easily via our digital app or physical "Bone" punch-card.',
  },
  {
    id: "03",
    name: "The 10% Excess Benefit",
    description:
      "For emergency bills exceeding the ₱5,000 outright cap, members receive an exclusive 10% discount on the remaining balance not exceeding 15K at partner clinics.",
  },
  {
    id: "04",
    name: "The Pack Network",
    description:
      'Priority access to a curated circle of "Class A" veterinary partners and groomers across Las Piñas.',
  },
  {
    id: "05",
    name: "The \u201cOffline\u201d Guarantee",
    description:
      'A fail-safe system ensuring your benefits are honored via physical cards and our "Partner Whitelist" even during internet outages or after-hours.',
  },
];

export function AboutOfferings() {
  return (
    <section className="bg-(--color-navy-mid) py-20 md:py-28">
      <div className="max-w-6xl mx-auto px-6">
        <p className="text-sm font-semibold uppercase tracking-widest text-(--color-gold) mp-reveal">
          Our Services
        </p>
        <h2 className="mt-4 text-2xl md:text-3xl font-bold tracking-tight leading-tight text-white mp-reveal">
          What the membership covers.
        </h2>

        <div className="mt-14 divide-y divide-white/[0.14]">
          {offerings.map(({ id, name, description }) => (
            <div
              key={id}
              className="group py-8 flex gap-8 md:gap-14 items-start mp-reveal"
            >
              <span className="text-sm font-semibold text-(--color-gold-muted) tabular-nums shrink-0 mt-0.5 transition-colors duration-200 group-hover:text-(--color-gold)">
                {id}
              </span>
              <div className="transition-transform duration-200 ease-out group-hover:translate-x-1">
                <h3 className="text-lg font-semibold text-white">{name}</h3>
                <p className="mt-2 text-sm leading-relaxed text-white/70 max-w-[62ch] transition-colors duration-200 group-hover:text-white/85">
                  {description}
                </p>
              </div>
            </div>
          ))}
        </div>
      </div>
    </section>
  );
}
