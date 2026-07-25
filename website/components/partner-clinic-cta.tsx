import Link from "next/link";

const PARTNER_INQUIRY_URL =
  "https://www.facebook.com/people/Metropaws/61588899502470/";

export function PartnerClinicCta() {
  return (
    <section
      id="partner"
      aria-label="Partner clinic inquiry"
      className="bg-(--color-navy) py-20 md:py-28"
    >
      <div className="max-w-6xl mx-auto px-6 text-center">
        <p className="text-sm font-semibold uppercase tracking-widest text-(--color-gold)">
          For Clinics
        </p>
        <h2 className="text-2xl md:text-3xl font-bold text-(--color-surface) tracking-tight leading-tight mt-3 max-w-xl mx-auto">
          Bring MetroPaws to your clinic
        </h2>
        <p className="text-sm text-(--color-ink-faint) leading-relaxed mt-4 max-w-[52ch] mx-auto">
          Join a growing network of Metro Manila clinics offering digital
          membership cards, benefit tracking, and QR-based check-ins, with no new
          hardware required.
        </p>
        <div className="mt-8">
          <Link
            href={PARTNER_INQUIRY_URL}
            target="_blank"
            rel="noopener noreferrer"
            className="inline-block bg-(--color-gold) text-(--color-navy) text-sm font-semibold rounded-lg px-8 py-3 hover:brightness-105 transition-all"
          >
            Get in Touch
          </Link>
        </div>
      </div>
    </section>
  );
}
