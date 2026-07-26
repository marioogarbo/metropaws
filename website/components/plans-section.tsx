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
      "Digital Pet Passport",
      "₱2,000 Preventive Wellness Wallet",
      "₱300 Emergency Wallet",
      "Paw Points Rewards",
      "Wellness Reminders",
      "Community Access",
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
    tagline: "More Care. More Flexibility. More Value.",
    features: [
      "Everything in Standard",
      "₱4,000 Preventive Wellness Wallet",
      "₱900 Emergency Wallet",
      "Higher Paw Points earning",
      "Priority member processing",
      "Member promos and event access",
    ],
    is_featured: true,
    is_active: true,
    sort_order: 1,
  },
  {
    id: "fallback-premium",
    name: "Premium",
    price: 9999,
    price_monthly: 900,
    tagline: "Premier Pet Wellness Experience",
    features: [
      "Everything in Deluxe",
      "₱7,000 Preventive Wellness Wallet",
      "₱1,500 Emergency Wallet",
      "Highest Paw Points earning",
      "VIP community access",
      "Concierge-style member support",
      "Premium member recognition",
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
