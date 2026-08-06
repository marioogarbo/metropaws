import Link from "next/link";
import { ArrowRight } from "lucide-react";
import { QR_PH_APPS, QR_PH_FALLBACK_LABEL } from "@/lib/payment-methods";

/**
 * Sits directly under the plans. At that point the question is not "what are
 * the steps" but "can I pay with my wallet, and what happens next" — so this
 * answers it in one glance and sends the walkthrough to /how-to-pay. A second
 * numbered step grid here would just echo HowItWorksSection two sections up.
 *
 * Cream-warm with a border on both edges is the established interstitial slot
 * (see CoverageTeaser). Navy would bleed into PawPointsSection right below.
 */
export function HowToPayRail() {
  return (
    <section
      id="how-to-pay"
      aria-labelledby="how-to-pay-rail-heading"
      className="bg-(--color-cream-warm) border-y border-(--color-ink-faint) py-12 md:py-14"
    >
      <div className="max-w-6xl mx-auto px-6">
        <div className="mp-reveal flex flex-col gap-8 lg:flex-row lg:items-center lg:justify-between lg:gap-16">
          <div className="lg:max-w-[46ch]">
            <h2
              id="how-to-pay-rail-heading"
              className="text-xl md:text-2xl font-bold text-(--color-navy) tracking-tight leading-tight text-balance"
            >
              Pay with the app you already use.
            </h2>
            <p className="mt-3 text-sm text-(--color-ink-muted) leading-relaxed">
              Pick a plan in the MetroPaws app, then scan one QR Ph code. No card
              needed, and the total at checkout is the total you pay.
            </p>
          </div>

          <div className="shrink-0 lg:text-right">
            {/* Gap only, no hairline separators: with five names the row wraps on
                narrow screens, and a per-item leading border leaves a stray rule
                at the start of every wrapped line. */}
            <ul className="flex flex-wrap items-center gap-x-5 gap-y-2 lg:justify-end">
              {QR_PH_APPS.map((app) => (
                <li
                  key={app}
                  className="text-sm font-semibold text-(--color-navy)"
                >
                  {app}
                </li>
              ))}
            </ul>
            <p className="mt-2 text-sm text-(--color-ink-muted)">
              {QR_PH_FALLBACK_LABEL}
            </p>

            <Link
              href="/getting-started#payment"
              className="group mt-4 inline-flex min-h-11 items-center gap-2 py-2 text-sm font-semibold text-(--color-navy) underline decoration-(--color-gold) decoration-2 underline-offset-4 transition-colors duration-150 ease-out hover:text-(--color-ink) focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-(--color-gold) focus-visible:ring-offset-2 focus-visible:ring-offset-(--color-cream-warm) rounded-sm"
            >
              See how to pay
              <ArrowRight
                className="w-4 h-4 transition-transform duration-150 ease-out group-hover:translate-x-0.5 motion-reduce:transition-none motion-reduce:group-hover:translate-x-0"
                strokeWidth={2}
                aria-hidden="true"
              />
            </Link>
          </div>
        </div>
      </div>
    </section>
  );
}
