"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { Users, Building2, CheckCircle2, Clock } from "lucide-react";
import { cn } from "@/lib/utils";
import type { DashboardSummary } from "@/app/admin/(protected)/dashboard/actions";

const FOUNDING_SLOTS = 50;

function useCountUp(target: number, duration = 700, delay = 0) {
  const [count, setCount] = useState(0);
  useEffect(() => {
    if (target === 0) {
      setCount(0);
      return;
    }
    const t = setTimeout(() => {
      const start = performance.now();
      const tick = (now: number) => {
        const elapsed = now - start;
        const progress = Math.min(elapsed / duration, 1);
        const eased = 1 - Math.pow(1 - progress, 4);
        setCount(Math.round(target * eased));
        if (progress < 1) requestAnimationFrame(tick);
      };
      requestAnimationFrame(tick);
    }, delay);
    return () => clearTimeout(t);
  }, [target, duration, delay]);
  return count;
}

interface KpiTileProps {
  label: string;
  value: string | number;
  sub?: string;
  href?: string;
  icon: React.ReactNode;
  accent?: boolean;
  alert?: boolean;
  delay?: number;
}

export function KpiTile({
  label,
  value,
  sub,
  href,
  icon,
  accent,
  alert,
  delay = 0,
}: KpiTileProps) {
  const numericTarget = typeof value === "number" ? value : 0;
  const animatedCount = useCountUp(numericTarget, 700, delay);
  const displayValue = typeof value === "number" ? animatedCount : value;

  const cardBg = accent
    ? "oklch(0.24 0.055 258)"
    : alert
      ? "oklch(0.96 0.022 65)"
      : "oklch(0.99 0.005 80)";
  const cardBorder = accent
    ? "transparent"
    : alert
      ? "oklch(0.87 0.040 65)"
      : "oklch(0.88 0.010 258)";
  const iconBg = accent
    ? "oklch(0.32 0.050 258)"
    : alert
      ? "oklch(0.90 0.050 65)"
      : "oklch(0.94 0.015 75)";
  const iconColor = accent
    ? "oklch(0.72 0.115 82)"
    : alert
      ? "oklch(0.50 0.105 60)"
      : "oklch(0.48 0.020 258)";
  const valueColor = accent
    ? "oklch(0.72 0.115 82)"
    : alert
      ? "oklch(0.48 0.100 60)"
      : "oklch(0.24 0.055 258)";
  const subColor = accent
    ? "oklch(0.65 0.090 82)"
    : alert
      ? "oklch(0.58 0.065 62)"
      : "oklch(0.60 0.015 258)";
  const labelColor = accent
    ? "oklch(0.65 0.012 258)"
    : alert
      ? "oklch(0.58 0.030 65)"
      : "oklch(0.60 0.015 258)";

  const inner = (
    <div
      className="dash-rise rounded-xl border p-5 flex flex-col gap-3"
      style={{
        background: cardBg,
        borderColor: cardBorder,
        animationDelay: `${delay}ms`,
      }}
    >
      <div className="flex items-start justify-between">
        <div
          className="w-8 h-8 rounded-lg flex items-center justify-center"
          style={{ background: iconBg }}
        >
          <span style={{ color: iconColor }}>{icon}</span>
        </div>
        {sub && (
          <span className="text-xs font-medium tabular-nums" style={{ color: subColor }}>
            {sub}
          </span>
        )}
      </div>
      <div>
        <p
          className="font-bold tabular-nums tracking-tight"
          style={{ fontSize: "28px", lineHeight: 1, color: valueColor }}
        >
          {displayValue}
        </p>
        <p
          className="text-xs font-medium mt-1.5 uppercase tracking-wider"
          style={{ color: labelColor }}
        >
          {label}
        </p>
      </div>
    </div>
  );

  if (href) {
    return (
      <Link
        href={href}
        className={cn(
          "block transition-[transform,box-shadow] duration-200 ease-out hover:-translate-y-0.5",
          accent && "hover:shadow-[0_6px_20px_oklch(0.72_0.115_82/0.18)]",
          alert && "hover:shadow-[0_4px_16px_oklch(0.65_0.090_60/0.12)]",
          !accent && !alert && "hover:shadow-[0_4px_14px_oklch(0.24_0.055_258/0.07)]",
        )}
      >
        {inner}
      </Link>
    );
  }
  return inner;
}

interface Props {
  summary: DashboardSummary;
}

export function DashboardKpi({ summary }: Props) {
  const slotsRemaining = Math.max(0, FOUNDING_SLOTS - summary.foundingApproved);

  return (
    <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
      <KpiTile
        label="Registered Members"
        value={summary.totalMembers}
        icon={<Users size={14} />}
        href="/admin/users"
        delay={0}
      />
      <KpiTile
        label="Founding Approved"
        value={`${summary.foundingApproved} / ${FOUNDING_SLOTS}`}
        sub={slotsRemaining > 0 ? `${slotsRemaining} remaining` : "All slots filled"}
        icon={<CheckCircle2 size={14} />}
        href="/admin/reservations"
        accent
        delay={60}
      />
      <KpiTile
        label="Pending Reviews"
        value={summary.foundingPending}
        sub={summary.foundingPending > 0 ? "action required" : undefined}
        icon={<Clock size={14} />}
        href="/admin/reservations"
        alert={summary.foundingPending > 0}
        delay={120}
      />
      <KpiTile
        label="Partner Clinics"
        value={summary.totalClinics}
        icon={<Building2 size={14} />}
        href="/admin/clinics"
        delay={180}
      />
    </div>
  );
}
