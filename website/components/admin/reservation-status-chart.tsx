"use client";

import { PieChart, Pie, Cell, Tooltip, ResponsiveContainer } from "recharts";
import type { DashboardSummary } from "@/app/admin/(protected)/dashboard/actions";

interface Props {
  summary: DashboardSummary;
}

const STATUS_COLORS = {
  Approved: "oklch(0.72 0.115 82)",
  Pending: "oklch(0.60 0.030 258)",
  Rejected: "oklch(0.80 0.010 258)",
};

interface LegendItem {
  label: string;
  value: number;
  color: string;
}

function StatusLegend({ items }: { items: LegendItem[] }) {
  return (
    <div className="flex flex-col gap-2.5">
      {items.map((item) => (
        <div key={item.label} className="flex items-center justify-between gap-4">
          <div className="flex items-center gap-2">
            <span
              className="w-2 h-2 rounded-full shrink-0"
              style={{ background: item.color }}
            />
            <span
              className="text-xs font-medium"
              style={{ color: "oklch(0.48 0.020 258)" }}
            >
              {item.label}
            </span>
          </div>
          <span
            className="text-xs font-semibold tabular-nums"
            style={{ color: "oklch(0.24 0.055 258)" }}
          >
            {item.value}
          </span>
        </div>
      ))}
    </div>
  );
}

export function ReservationStatusChart({ summary }: Props) {
  const total =
    summary.foundingApproved + summary.foundingPending + summary.foundingRejected;

  const data = [
    { name: "Approved", value: summary.foundingApproved },
    { name: "Pending", value: summary.foundingPending },
    { name: "Rejected", value: summary.foundingRejected },
  ].filter((d) => d.value > 0);

  const legendItems: LegendItem[] = [
    {
      label: "Approved",
      value: summary.foundingApproved,
      color: STATUS_COLORS.Approved,
    },
    {
      label: "Pending",
      value: summary.foundingPending,
      color: STATUS_COLORS.Pending,
    },
    {
      label: "Rejected",
      value: summary.foundingRejected,
      color: STATUS_COLORS.Rejected,
    },
  ].filter((item) => item.value > 0);

  return (
    <div
      className="rounded-xl border p-6 flex flex-col gap-5"
      style={{
        background: "oklch(0.99 0.005 80)",
        borderColor: "oklch(0.88 0.010 258)",
      }}
    >
      <div>
        <p
          className="text-xs font-semibold uppercase tracking-widest mb-1"
          style={{ color: "oklch(0.72 0.115 82)" }}
        >
          Founding 50
        </p>
        <h3
          className="font-semibold tracking-tight"
          style={{ color: "oklch(0.24 0.055 258)", fontSize: "15px" }}
        >
          Reservation Status
        </h3>
      </div>

      {total === 0 ? (
        <p className="text-sm" style={{ color: "oklch(0.60 0.015 258)" }}>
          No reservations yet.
        </p>
      ) : (
        <div className="flex items-center gap-6">
          <div className="relative shrink-0" style={{ width: 120, height: 120 }}>
            <ResponsiveContainer width="100%" height="100%">
              <PieChart>
                <Pie
                  data={data}
                  cx="50%"
                  cy="50%"
                  innerRadius={34}
                  outerRadius={54}
                  paddingAngle={2}
                  dataKey="value"
                  strokeWidth={0}
                >
                  {data.map((entry) => (
                    <Cell
                      key={entry.name}
                      fill={STATUS_COLORS[entry.name as keyof typeof STATUS_COLORS]}
                    />
                  ))}
                </Pie>
                <Tooltip
                  contentStyle={{
                    background: "oklch(0.99 0.005 80)",
                    border: "1px solid oklch(0.88 0.010 258)",
                    borderRadius: "8px",
                    fontSize: "12px",
                    fontFamily: "var(--font-sans, sans-serif)",
                  }}
                  itemStyle={{ color: "oklch(0.24 0.055 258)" }}
                />
              </PieChart>
            </ResponsiveContainer>
            <div className="absolute inset-0 flex flex-col items-center justify-center pointer-events-none">
              <span
                className="font-bold tabular-nums"
                style={{
                  fontSize: "20px",
                  color: "oklch(0.24 0.055 258)",
                  lineHeight: 1,
                }}
              >
                {total}
              </span>
              <span className="text-xs mt-0.5" style={{ color: "oklch(0.60 0.015 258)" }}>
                total
              </span>
            </div>
          </div>
          <div className="flex-1">
            <StatusLegend items={legendItems} />
          </div>
        </div>
      )}
    </div>
  );
}
