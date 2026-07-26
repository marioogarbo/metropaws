const offerings = [
  {
    id: "01",
    name: "The Preventive Wellness Wallet",
    description:
      "An annual fund for grooming, vaccinations, and check-ups — from ₱2,000 on Standard up to ₱7,000 on Premium — tracked to the peso inside the app.",
  },
  {
    id: "02",
    name: "The Emergency Wallet",
    description:
      "A separate fund set aside for urgent visits — from ₱300 up to ₱1,500 a year — so an emergency never catches you flat-footed.",
  },
  {
    id: "03",
    name: "Use Any Provider",
    description:
      "Stay with the vet or groomer your pet already trusts. Request a scheduled visit and we pay the provider directly, or pay yourself and get reimbursed to GCash or bank.",
  },
  {
    id: "04",
    name: "The Pack Network",
    description:
      'Priority access to a curated circle of "Class A" veterinary partners and groomers across Las Piñas.',
  },
  {
    id: "05",
    name: "The Digital Pet Passport",
    description:
      "Every pet's QR ID, profile, vaccination records, and visit history in one app \u2014 ready to show at any partner clinic check-in.",
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
