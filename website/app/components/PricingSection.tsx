"use client";

import { useEffect, useState } from "react";
import { Check, RefreshCw } from "lucide-react";
import Link from "next/link";
import { listPlans } from "@/lib/api";
import type { Plan } from "@/lib/api";

type TierKey = "standard" | "silver" | "gold";

function getTierKey(index: number, total: number, isFeatured: boolean): TierKey {
  if (isFeatured) return "gold";
  const center = Math.floor(total / 2);
  return index < center ? "standard" : "silver";
}

function reorderWithFeaturedCenter(plans: Plan[]): Plan[] {
  if (plans.length <= 1) return plans;
  const featuredIdx = plans.findIndex((p) => p.is_featured);
  if (featuredIdx === -1) return plans;
  const featured = plans[featuredIdx];
  const others = plans.filter((_, i) => i !== featuredIdx);
  const center = Math.floor(plans.length / 2);
  const result = [...others];
  result.splice(center, 0, featured);
  return result;
}

const TIER_BADGE: Record<TierKey, { label: string; bg: string; fg: string }> = {
  standard: { label: "Standard", bg: "var(--navy-light)", fg: "var(--navy)" },
  silver: { label: "Silver", bg: "oklch(76% 0.012 242)", fg: "var(--navy-deep)" },
  gold: { label: "Gold", bg: "var(--gold)", fg: "var(--navy-deep)" },
};

const SILVER_BG: React.CSSProperties = {
  background:
    "linear-gradient(145deg, oklch(90% 0.004 240) 0%, oklch(84% 0.007 248) 50%, oklch(90% 0.004 240) 100%)",
  border: "1px solid oklch(76% 0.012 242)",
};

const SILVER_CTA: React.CSSProperties = { background: "rgba(255,255,255,0.32)" };

function SectionShell({ children }: { children: React.ReactNode }) {
  return (
    <section className="px-5 md:px-8 py-12 md:py-20 bg-(--surface)">
      <div className="max-w-5xl mx-auto">{children}</div>
    </section>
  );
}

export default function PricingSection() {
  const [plans, setPlans] = useState<Plan[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(false);
  const [billing, setBilling] = useState<"annual" | "monthly">("annual");

  function fetchPlans() {
    setLoading(true);
    setError(false);
    listPlans()
      .then((data) =>
        setPlans(
          data
            .filter((p) => p.is_active)
            .sort((a, b) => a.sort_order - b.sort_order)
        )
      )
      .catch(() => setError(true))
      .finally(() => setLoading(false));
  }

  useEffect(() => {
    fetchPlans();
  }, []);

  if (loading) {
    return (
      <SectionShell>
        <div className="h-5 w-28 rounded-full bg-(--grey-light) animate-pulse mb-3" />
        <div className="h-8 w-48 rounded-xl bg-(--grey-light) animate-pulse mb-4" />
        <div className="h-4 w-80 rounded-lg bg-(--grey-light) animate-pulse mb-10" />
        <div className="grid grid-cols-1 md:grid-cols-3 gap-4 md:gap-5">
          {[1, 2, 3].map((i) => (
            <div key={i} className="rounded-2xl bg-(--grey-light) animate-pulse h-80" />
          ))}
        </div>
      </SectionShell>
    );
  }

  if (error) {
    return (
      <SectionShell>
        <p className="text-xs font-extrabold tracking-widest uppercase text-(--gold-muted) mb-3">
          Membership
        </p>
        <h2 className="font-(family-name:--font-baloo2) text-3xl md:text-4xl font-extrabold text-(--text) mb-3">
          Plans & Pricing
        </h2>
        <div className="rounded-2xl border border-(--grey-light) p-8 flex flex-col items-center gap-4 text-center">
          <p className="text-(--grey) text-base">Couldn&apos;t load pricing plans right now.</p>
          <button
            onClick={fetchPlans}
            className="inline-flex items-center gap-2 px-5 py-2.5 min-h-11 rounded-xl border border-(--navy) text-(--navy) font-semibold text-sm hover:bg-(--navy-light) transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-(--navy)/40"
          >
            <RefreshCw className="w-4 h-4" />
            Try again
          </button>
        </div>
      </SectionShell>
    );
  }

  if (plans.length === 0) {
    return (
      <SectionShell>
        <p className="text-xs font-extrabold tracking-widest uppercase text-(--gold-muted) mb-3">
          Membership
        </p>
        <h2 className="font-(family-name:--font-baloo2) text-3xl md:text-4xl font-extrabold text-(--text) mb-3">
          Plans & Pricing
        </h2>
        <div className="rounded-2xl border border-(--grey-light) p-8 text-center">
          <p className="text-(--grey) text-base">Pricing plans coming soon.</p>
        </div>
      </SectionShell>
    );
  }

  return (
    <SectionShell>
      {/* Section header */}
      <div className="mb-10 md:mb-14 flex flex-col sm:flex-row sm:items-end justify-between gap-6">
        <div>
          <p className="text-xs font-extrabold tracking-widest uppercase text-(--gold-muted) mb-3">
            Membership
          </p>
          <h2 className="font-(family-name:--font-baloo2) text-3xl md:text-4xl font-extrabold text-(--text) mb-3">
            Plans & Pricing
          </h2>
          <p className="text-(--grey) text-base max-w-lg">
            Choose the coverage that fits your pet&apos;s needs. No payment required to register
            — billing is handled at your partner clinic.
          </p>
        </div>

        {/* Billing toggle */}
        <div className="flex items-center gap-1 p-1 rounded-xl bg-white border border-(--grey-light) shrink-0 self-start sm:self-auto">
          <button
            onClick={() => setBilling("monthly")}
            className={`px-4 py-2 rounded-lg text-sm font-semibold transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-(--navy)/40 ${
              billing === "monthly"
                ? "bg-(--surface) text-(--text) shadow-sm"
                : "text-(--grey) hover:text-(--text)"
            }`}
          >
            Monthly
          </button>
          <button
            onClick={() => setBilling("annual")}
            className={`px-4 py-2 rounded-lg text-sm font-semibold transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-(--navy)/40 ${
              billing === "annual"
                ? "bg-(--surface) text-(--text) shadow-sm"
                : "text-(--grey) hover:text-(--text)"
            }`}
          >
            Annual
            {billing !== "annual" && (
              <span className="ml-1.5 px-1.5 py-0.5 rounded-md bg-(--gold-light) text-(--gold-muted) text-[10px] font-bold">
                SAVE
              </span>
            )}
          </button>
        </div>
      </div>

      {/* Plan cards */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-4 md:gap-5">
        {reorderWithFeaturedCenter(plans).map((plan, index) => {
          const tier = getTierKey(index, plans.length, plan.is_featured);
          const badge = TIER_BADGE[tier];

          return (
            <div
              key={plan.id}
              className={`rounded-2xl p-6 sm:p-7 flex flex-col transition-all duration-200 ${
                tier === "gold"
                  ? "bg-(--navy-deep) shadow-2xl md:-translate-y-2 md:scale-[1.02]"
                  : tier === "silver"
                  ? "shadow-md hover:shadow-xl"
                  : "bg-white border border-(--grey-light) shadow-sm hover:shadow-md"
              }`}
              style={tier === "silver" ? SILVER_BG : undefined}
            >
              {/* Tier badge row */}
              <div className="flex items-center justify-between gap-2 mb-5">
                <span
                  className="px-2.5 py-1 rounded-full text-[10px] font-extrabold tracking-wider uppercase"
                  style={{ background: badge.bg, color: badge.fg }}
                >
                  {badge.label}
                </span>
                {plan.is_featured && tier !== "gold" && (
                  <span className="px-2.5 py-1 rounded-full bg-(--gold-light) text-(--gold-muted) text-[10px] font-extrabold tracking-wider uppercase">
                    Popular
                  </span>
                )}
                {plan.is_featured && tier === "gold" && (
                  <span className="px-2.5 py-1 rounded-full text-[10px] font-extrabold tracking-wider uppercase"
                    style={{ background: "rgba(201,168,67,0.18)", color: "var(--gold)" }}>
                    Most Popular
                  </span>
                )}
              </div>

              {/* Plan name */}
              <div className="mb-6">
                <h3
                  className={`font-(family-name:--font-baloo2) text-xl font-extrabold leading-tight mb-4 ${
                    tier === "gold"
                      ? "text-white"
                      : tier === "silver"
                      ? "text-(--navy-deep)"
                      : "text-(--text)"
                  }`}
                >
                  {plan.name}
                </h3>

                {/* Price */}
                <div className="flex items-baseline gap-1">
                  <span
                    className={`font-(family-name:--font-baloo2) font-extrabold text-3xl ${
                      tier === "gold"
                        ? "text-white"
                        : tier === "silver"
                        ? "text-(--navy-deep)"
                        : "text-(--text)"
                    }`}
                  >
                    {billing === "monthly" && plan.price_monthly
                      ? `₱${plan.price_monthly.toLocaleString()}`
                      : `₱${plan.price.toLocaleString()}`}
                  </span>
                  <span
                    className={`text-sm ${
                      tier === "gold"
                        ? "text-white/70"
                        : "text-(--grey)"
                    }`}
                  >
                    {billing === "monthly" && plan.price_monthly ? "/mo" : "/year"}
                  </span>
                </div>

                {billing === "monthly" && plan.price_monthly ? (
                  <p
                    className={`text-xs mt-0.5 ${
                      tier === "gold" ? "text-white/60" : "text-(--grey)"
                    }`}
                  >
                    ₱{plan.price.toLocaleString()} billed annually
                  </p>
                ) : plan.price_monthly ? (
                  <p
                    className={`text-xs mt-0.5 ${
                      tier === "gold" ? "text-white/60" : "text-(--grey)"
                    }`}
                  >
                    or ₱{plan.price_monthly.toLocaleString()}/mo
                  </p>
                ) : null}

                {plan.tagline && (
                  <p
                    className={`text-sm mt-2 ${
                      tier === "gold"
                        ? "text-(--gold)"
                        : tier === "silver"
                        ? "text-(--navy)"
                        : "text-(--grey)"
                    }`}
                  >
                    {plan.tagline}
                  </p>
                )}
              </div>

              {/* Features */}
              <ul className="flex flex-col gap-2.5 mb-8 flex-1">
                {plan.features.map((feature) => (
                  <li key={feature} className="flex items-start gap-2.5">
                    <Check
                      className={`w-4 h-4 shrink-0 mt-0.5 ${
                        tier === "gold" ? "text-(--gold)" : "text-(--navy)"
                      }`}
                      strokeWidth={2.5}
                    />
                    <span
                      className={`text-sm leading-snug ${
                        tier === "gold"
                          ? "text-white/90"
                          : tier === "silver"
                          ? "text-(--navy)"
                          : "text-(--grey)"
                      }`}
                    >
                      {feature}
                    </span>
                  </li>
                ))}
              </ul>

              {/* CTA */}
              <Link
                href={`/register?plan=${plan.id}`}
                className={`w-full py-3.5 rounded-xl font-bold text-sm text-center min-h-11 flex items-center justify-center transition-colors focus-visible:outline-none focus-visible:ring-2 ${
                  tier === "gold"
                    ? "bg-(--gold) text-(--navy-deep) hover:bg-(--gold-muted) focus-visible:ring-(--gold)/50"
                    : tier === "silver"
                    ? "border border-(--navy)/30 text-(--navy-deep) hover:bg-white/50 focus-visible:ring-(--navy)/40"
                    : "border border-(--navy) text-(--navy) hover:bg-(--navy-light) focus-visible:ring-(--navy)/40"
                }`}
                style={tier === "silver" ? SILVER_CTA : undefined}
              >
                {tier === "gold" ? `Join the Pack →` : `Start with ${plan.name} →`}
              </Link>
            </div>
          );
        })}
      </div>

      <p className="text-center text-xs text-(--grey) mt-8">
        Billing is handled at your partner clinic — MetroPaws never charges you directly.
      </p>
    </SectionShell>
  );
}
