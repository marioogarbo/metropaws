import Link from "next/link";
import { SERVICE_FILTERS } from "@/lib/directory-taxonomy";

/**
 * Homepage route into the pet-care directory.
 *
 * Replaces the former "Bring MetroPaws to your clinic" block (client decision,
 * 2026-08-08). That section pitched a partner network that does not exist yet:
 * `clinic_partners` and `reimbursement_providers` are both empty, so "join a
 * growing network of Metro Manila clinics" was a claim with nothing behind it.
 * The Facebook contact it linked to is still reachable from the footer and the
 * FAQ, so clinics that want to reach MetroPaws still can.
 *
 * Body copy uses `--color-silver` rather than the site's usual
 * `--color-ink-faint` on navy: the faint token is 3.23:1, under WCAG AA.
 */
export function DirectoryCta() {
  return (
    <section
      id="directory"
      aria-labelledby="directory-cta-heading"
      className="bg-(--color-navy) py-20 md:py-28"
    >
      <div className="max-w-6xl mx-auto px-6 text-center">
        <p className="text-sm font-semibold uppercase tracking-widest text-(--color-gold)">
          Around Las Piñas
        </p>
        <h2
          id="directory-cta-heading"
          className="text-2xl md:text-3xl font-bold text-(--color-surface) tracking-tight leading-tight mt-3 max-w-xl mx-auto text-balance"
        >
          Find pet care near you
        </h2>
        <p className="text-sm text-(--color-silver) leading-relaxed mt-4 max-w-[54ch] mx-auto">
          Addresses, phone numbers, and opening hours for pet care around Las
          Piñas, gathered in one list so you are not hunting for a number at the
          moment you need one. Free to use whether or not you are a member.
        </p>

        {/* The same four groupings the directory filters by, so the section
            says what is actually in the list before anyone clicks. */}
        <ul className="mt-7 flex flex-wrap items-center justify-center gap-2">
          {SERVICE_FILTERS.map(({ id, label }) => (
            <li key={id}>
              <span className="inline-block rounded-full border border-white/20 px-3.5 py-1.5 text-xs font-medium text-(--color-silver)">
                {label}
              </span>
            </li>
          ))}
        </ul>

        <div className="mt-8">
          <Link
            href="/find-pet-care"
            className="inline-flex min-h-11 items-center gap-2 bg-(--color-gold) text-(--color-navy) text-sm font-semibold rounded-lg px-8 hover:brightness-105 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-(--color-surface) transition-all"
          >
            Browse the directory
            <span aria-hidden="true">→</span>
          </Link>
        </div>
      </div>
    </section>
  );
}
