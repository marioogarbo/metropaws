import type { Plan } from "@/types/plan";
import { PricingCards } from "@/components/pricing-cards";

const BACKEND_URL =
  process.env.NEXT_PUBLIC_BACKEND_URL ?? "https://metropaws-backend.onrender.com";

const FALLBACK_PLANS: Plan[] = [
  {
    id: "fallback-standard",
    name: "Standard",
    price: 2999,
    price_monthly: 300,
    tagline: "Smart Pet Parenting Starts Here",
    features: [
      "Professional veterinary care — up to 2 consultations a year",
      "Annual vaccines with deworming and kennel cough",
      "Grooming privileges — up to 15% member savings",
      "Laboratory savings — up to 10% member savings",
      "Emergency assistance — 10% off the initial gate fee, once a year",
      "Digital Pet Passport, reminders & PawPoints rewards",
    ],
    is_featured: false,
    is_active: true,
    sort_order: 0,
  },
  {
    id: "fallback-deluxe",
    name: "Deluxe",
    price: 5999,
    price_monthly: 600,
    tagline: "The Complete Preventive Care Membership",
    features: [
      "Enhanced veterinary support — up to 4 consultations a year",
      "Annual vaccines with deworming and kennel cough",
      "One emergency case a year — gate fee plus basic stabilization",
      "Laboratory savings — up to 10% member savings",
      "Complimentary grooming — 2 sessions a year",
      "Enhanced PawPoints & priority member processing",
    ],
    is_featured: true,
    is_active: true,
    sort_order: 1,
  },
  {
    id: "fallback-premium",
    name: "Premium",
    price: 10999,
    price_monthly: 1200,
    tagline: "The Premier Pet Parenting Membership",
    features: [
      "Unlimited veterinary consultations (per program terms)",
      "Premium grooming — 4 complimentary sessions a year",
      "Annual diagnostic screening — includes CBC blood test",
      "Emergency Bridge — first ₱5,000 covered, plus 10% on bills up to ₱15,000",
      "Digital Pet Passport Premium, Elite PawPoints & concierge support",
    ],
    is_featured: false,
    is_active: true,
    sort_order: 2,
  },
];

async function fetchPlans(): Promise<Plan[]> {
  try {
    const response = await fetch(`${BACKEND_URL}/plans`, {
      next: { revalidate: 3600 },
    });
    if (!response.ok) {
      return FALLBACK_PLANS;
    }
    const data = (await response.json()) as Plan[];
    if (!Array.isArray(data) || data.length === 0) {
      return FALLBACK_PLANS;
    }
    return [...data]
      .filter((plan) => plan.is_active)
      .sort((a, b) => a.sort_order - b.sort_order);
  } catch {
    return FALLBACK_PLANS;
  }
}

export async function PlansSection() {
  const plans = await fetchPlans();

  return (
    <section
      id="pricing"
      className="bg-(--color-cream) py-20 md:py-28"
    >
      <div className="max-w-6xl mx-auto px-6">
        <div className="mb-14 mp-reveal">
          <p className="text-sm font-semibold uppercase tracking-widest text-(--color-gold)">
            Membership
          </p>
          <h2 className="text-3xl md:text-5xl font-bold text-(--color-navy) tracking-tight leading-tight mt-3">
            Plans &amp; Pricing
          </h2>
          <p className="text-sm text-(--color-ink-muted) leading-relaxed mt-4 max-w-[52ch]">
            Choose the membership that fits your pet. Free to register; pay only
            when you activate a plan, then claim your benefits anywhere.
          </p>
        </div>

        <div className="mp-reveal">
          <PricingCards plans={plans} />
        </div>

        <p className="text-sm text-(--color-ink-muted) text-center mt-10 max-w-[60ch] mx-auto leading-relaxed">
          All plans renew annually. Cancel or change tier any time before renewal.
        </p>
      </div>
    </section>
  );
}
