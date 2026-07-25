"use client";

import { useId, useState } from "react";
import Link from "next/link";
import { Check } from "lucide-react";
import { cn } from "@/lib/utils";
import type { Plan } from "@/types/plan";

type BillingCycle = "monthly" | "annual";

const TIER_BADGE: Record<Plan["name"], string> = {
  Standard: "Standard",
  Deluxe: "Gold",
  Premium: "Platinum",
};

const CTA_LABEL: Record<Plan["name"], string> = {
  Standard: "Start with Standard",
  Deluxe: "Join the Pack",
  Premium: "Start with Premium",
};

function formatPeso(value: number): string {
  return `₱${value.toLocaleString("en-PH")}`;
}

export function PricingCards({ plans }: { plans: Plan[] }) {
  const [cycle, setCycle] = useState<BillingCycle>("annual");
  const groupId = useId();

  return (
    <>
      <div className="flex justify-center md:justify-end mb-10">
        <BillingToggle cycle={cycle} onChange={setCycle} groupId={groupId} />
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6 lg:gap-5 items-stretch">
        {plans.map((plan) => (
          <PricingCard key={plan.id} plan={plan} cycle={cycle} />
        ))}
      </div>
    </>
  );
}

function BillingToggle({
  cycle,
  onChange,
  groupId,
}: {
  cycle: BillingCycle;
  onChange: (next: BillingCycle) => void;
  groupId: string;
}) {
  return (
    <div
      role="radiogroup"
      aria-label="Billing cycle"
      className="relative inline-grid grid-cols-2 items-center bg-(--color-surface) border border-(--color-ink-faint) rounded-full p-1"
    >
      <span
        aria-hidden="true"
        className={cn(
          "pointer-events-none absolute top-1 left-1 h-[calc(100%-0.5rem)] w-[calc(50%-0.25rem)] rounded-full bg-(--color-navy) transition-transform duration-300 ease-[cubic-bezier(0.22,1,0.36,1)]",
          cycle === "annual" && "translate-x-full"
        )}
      />
      {(["monthly", "annual"] as const).map((value) => {
        const active = cycle === value;
        return (
          <button
            key={value}
            type="button"
            role="radio"
            aria-checked={active}
            id={`${groupId}-${value}`}
            onClick={() => onChange(value)}
            className={cn(
              "relative z-10 text-sm font-semibold capitalize rounded-full px-5 py-2 transition-colors duration-200 ease-out",
              "focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-(--color-gold) focus-visible:ring-offset-2 focus-visible:ring-offset-(--color-cream)",
              active ? "text-white" : "text-(--color-ink-muted) hover:text-(--color-navy)"
            )}
          >
            {value}
          </button>
        );
      })}
    </div>
  );
}

function PricingCard({ plan, cycle }: { plan: Plan; cycle: BillingCycle }) {
  const featured = plan.is_featured;
  const showMonthly = cycle === "monthly" && plan.price_monthly !== null;
  const headlinePrice = showMonthly ? plan.price_monthly! : plan.price;
  const headlineUnit = showMonthly ? "/mo" : "/year";
  const secondary = showMonthly
    ? `billed at ${formatPeso(plan.price)}/year`
    : plan.price_monthly !== null
      ? `or ${formatPeso(plan.price_monthly)}/mo`
      : null;

  const isPremium = plan.name === "Premium";

  return (
    <article
      style={
        isPremium
          ? {
              backgroundImage:
                "linear-gradient(152deg, var(--color-silver-hi) 0%, var(--color-silver) 38%, var(--color-silver-lo) 68%, var(--color-silver) 100%)",
            }
          : undefined
      }
      className={cn(
        "relative flex flex-col rounded-xl p-8 lg:p-9",
        "transition-transform duration-300 ease-[cubic-bezier(0.22,1,0.36,1)] motion-safe:hover:-translate-y-1",
        featured
          ? "bg-(--color-navy) text-white lg:-my-4 lg:py-12 ring-1 ring-(--color-gold)/15"
          : isPremium
            ? "text-(--color-ink) border border-(--color-silver-edge)"
            : "bg-(--color-surface) text-(--color-ink) border border-(--color-ink-faint)"
      )}
    >
      <header className="flex items-start justify-between gap-3">
        <TierBadge label={TIER_BADGE[plan.name]} featured={featured} variant={plan.name} />
        {featured && (
          <span className="inline-flex items-center text-[10px] font-bold uppercase tracking-widest text-(--color-gold) bg-(--color-gold)/15 rounded-full px-3 py-1">
            Most Popular
          </span>
        )}
      </header>

      <h3
        className={cn(
          "text-xl font-bold tracking-tight mt-6",
          featured ? "text-white" : "text-(--color-navy)"
        )}
      >
        {plan.name}
      </h3>

      <div className="mt-4">
        <div className="flex items-baseline gap-1">
          <span
            className={cn(
              "text-4xl md:text-5xl font-bold tracking-tight tabular-nums transition-opacity duration-200 ease-out",
              featured ? "text-white" : "text-(--color-navy)"
            )}
          >
            {formatPeso(headlinePrice)}
          </span>
          <span
            className={cn(
              "text-sm font-medium",
              featured
                ? "text-white/70"
                : isPremium
                  ? "text-(--color-silver-ink)"
                  : "text-(--color-ink-muted)"
            )}
          >
            {headlineUnit}
          </span>
        </div>
        {secondary && (
          <p
            className={cn(
              "text-sm mt-2",
              featured
                ? "text-white/65"
                : isPremium
                  ? "text-(--color-silver-ink)"
                  : "text-(--color-ink-muted)"
            )}
          >
            {secondary}
          </p>
        )}
      </div>

      {plan.tagline && (
        <p
          className={cn(
            "text-sm font-medium mt-4",
            featured
              ? "text-(--color-gold)"
              : isPremium
                ? "text-(--color-silver-ink)"
                : "text-(--color-ink-muted)"
          )}
        >
          {plan.tagline}
        </p>
      )}

      <ul className="flex flex-col gap-3 mt-7">
        {plan.features.map((feature, index) => (
          <li key={index} className="flex items-start gap-3">
            <Check
              className={cn(
                "w-4 h-4 mt-0.5 shrink-0",
                featured ? "text-(--color-gold)" : "text-(--color-navy)"
              )}
              strokeWidth={2.5}
              aria-hidden="true"
            />
            <span
              className={cn(
                "text-sm leading-relaxed",
                featured ? "text-white/85" : "text-(--color-ink)"
              )}
            >
              {feature}
            </span>
          </li>
        ))}
      </ul>

      <div className="mt-auto pt-8">
        <Link
          href="/register"
          className={cn(
            "inline-flex items-center justify-center w-full text-sm font-semibold rounded-lg px-6 py-3.5 transition-all duration-200 ease-out",
            "focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-(--color-gold) focus-visible:ring-offset-2",
            featured
              ? "bg-(--color-gold) text-(--color-navy) hover:brightness-105 focus-visible:ring-offset-(--color-navy)"
              : "border border-(--color-navy) text-(--color-navy) hover:bg-(--color-navy) hover:text-white focus-visible:ring-offset-(--color-cream)"
          )}
        >
          {CTA_LABEL[plan.name]} →
        </Link>
      </div>
    </article>
  );
}

function TierBadge({
  label,
  featured,
  variant,
}: {
  label: string;
  featured: boolean;
  variant: Plan["name"];
}) {
  const isSilver = variant === "Premium" && !featured;
  const tone = featured
    ? "bg-(--color-gold) text-(--color-navy)"
    : isSilver
      ? "text-(--color-silver-ink) ring-1 ring-inset ring-(--color-silver-edge)/50"
      : "bg-(--color-gold)/15 text-(--color-gold-muted)";

  return (
    <span
      style={
        isSilver
          ? {
              backgroundImage:
                "linear-gradient(160deg, var(--color-silver-hi) 0%, var(--color-silver-lo) 100%)",
            }
          : undefined
      }
      className={cn(
        "inline-flex items-center text-[10px] font-bold uppercase tracking-widest rounded-full px-3 py-1",
        tone
      )}
    >
      {label}
    </span>
  );
}
