"use client";

import { Wallet, BadgeCheck, Receipt, Activity } from "lucide-react";
import { KpiTile } from "@/components/admin/dashboard-kpi";
import type { BusinessKpis } from "@/app/admin/(protected)/dashboard/actions";

function formatPeso(value: number): string {
  return `₱${value.toLocaleString("en-PH")}`;
}

const PLAN_TONE: Record<string, string> = {
  Standard: "oklch(0.60 0.015 258)",
  Deluxe: "oklch(0.72 0.115 82)",
  Premium: "oklch(0.24 0.055 258)",
};

const NAVY = "oklch(0.24 0.055 258)";
const INK_MUTED = "oklch(0.60 0.015 258)";
const CARD_BG = "oklch(0.99 0.005 80)";
const CARD_BORDER = "oklch(0.88 0.010 258)";

function Panel({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <div
      className="rounded-xl border p-5 flex flex-col gap-4"
      style={{ background: CARD_BG, borderColor: CARD_BORDER }}
    >
      <p
        className="text-xs font-semibold uppercase tracking-wider"
        style={{ color: INK_MUTED }}
      >
        {title}
      </p>
      {children}
    </div>
  );
}

function PlanMixPanel({ kpis }: { kpis: BusinessKpis }) {
  const total = kpis.members.active_memberships;
  const rows = [...kpis.plan_mix].sort((a, b) => b.count - a.count);

  return (
    <Panel title="Plan mix">
      {rows.length === 0 ? (
        <p className="text-sm" style={{ color: INK_MUTED }}>
          No activated memberships yet.
        </p>
      ) : (
        <div className="flex flex-col gap-3">
          {rows.map((row) => {
            const pct = total > 0 ? Math.round((row.count / total) * 100) : 0;
            const tone = PLAN_TONE[row.plan] ?? INK_MUTED;
            return (
              <div key={row.plan} className="flex flex-col gap-1">
                <div className="flex items-baseline justify-between">
                  <span className="text-sm font-semibold" style={{ color: NAVY }}>
                    {row.plan}
                  </span>
                  <span
                    className="text-xs font-medium tabular-nums"
                    style={{ color: INK_MUTED }}
                  >
                    {row.count} · {pct}%
                  </span>
                </div>
                <div
                  className="h-1.5 w-full rounded-full overflow-hidden"
                  style={{ background: "oklch(0.94 0.010 258)" }}
                >
                  <div
                    className="h-full rounded-full"
                    style={{ width: `${pct}%`, background: tone }}
                  />
                </div>
              </div>
            );
          })}
        </div>
      )}
    </Panel>
  );
}

const CLAIM_STATUS_LABELS: Record<string, string> = {
  pending: "Pending",
  under_review: "Under review",
  needs_info: "Needs info",
  approved: "Approved",
  rejected: "Rejected",
  paid: "Paid",
};

const CLAIM_STATUS_ORDER = [
  "pending",
  "under_review",
  "needs_info",
  "approved",
  "paid",
  "rejected",
];

function ClaimsPanel({ kpis }: { kpis: BusinessKpis }) {
  const { by_status: byStatus, total } = kpis.claims;
  const entries = CLAIM_STATUS_ORDER.filter((key) => byStatus[key] > 0).map(
    (key) => ({ key, count: byStatus[key] }),
  );

  return (
    <Panel title="Claims by status">
      {total === 0 ? (
        <p className="text-sm" style={{ color: INK_MUTED }}>
          No claims submitted yet.
        </p>
      ) : (
        <div className="flex flex-col gap-2.5">
          {entries.map(({ key, count }) => (
            <div key={key} className="flex items-center justify-between">
              <span className="text-sm" style={{ color: NAVY }}>
                {CLAIM_STATUS_LABELS[key] ?? key}
              </span>
              <span
                className="text-sm font-semibold tabular-nums"
                style={{ color: NAVY }}
              >
                {count}
              </span>
            </div>
          ))}
        </div>
      )}
    </Panel>
  );
}

export function BusinessKpi({ kpis }: { kpis: BusinessKpis }) {
  return (
    <div className="flex flex-col gap-4">
      <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
        <KpiTile
          label="Revenue Collected"
          value={formatPeso(kpis.revenue.total_php)}
          sub={`${kpis.revenue.paid_payments} paid`}
          icon={<Wallet size={14} />}
          accent
          href="/admin/payments"
          delay={0}
        />
        <KpiTile
          label="Active Memberships"
          value={kpis.members.active_memberships}
          sub={`${kpis.members.total} accounts`}
          icon={<BadgeCheck size={14} />}
          delay={60}
        />
        <KpiTile
          label="Claims Paid Out"
          value={formatPeso(kpis.claims.payout_total_php)}
          sub={
            kpis.claims.pending_review > 0
              ? `${kpis.claims.pending_review} to review`
              : undefined
          }
          icon={<Receipt size={14} />}
          href="/admin/reimbursements"
          alert={kpis.claims.pending_review > 0}
          delay={120}
        />
        <KpiTile
          label="Benefit Utilization"
          value={`${kpis.utilization.used_pct}%`}
          sub={`${kpis.utilization.used_sessions}/${kpis.utilization.total_sessions} sessions`}
          icon={<Activity size={14} />}
          delay={180}
        />
      </div>
      <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
        <PlanMixPanel kpis={kpis} />
        <ClaimsPanel kpis={kpis} />
      </div>
    </div>
  );
}
