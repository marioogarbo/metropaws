"use client";

import { BarChart, Bar, XAxis, YAxis, CartesianGrid, Cell } from "recharts";
import {
  ChartContainer,
  ChartTooltip,
  ChartTooltipContent,
  type ChartConfig,
} from "@/components/ui/chart";
import type { BarangayCount } from "@/app/admin/(protected)/dashboard/actions";

interface Props {
  data: BarangayCount[];
}

const chartConfig = {
  approved: {
    label: "Approved",
    color: "oklch(0.72 0.115 82)",
  },
  pending: {
    label: "Pending",
    color: "oklch(0.80 0.015 258)",
  },
} satisfies ChartConfig;

function StatusPip({
  label,
  value,
  accent,
}: {
  label: string;
  value: number;
  accent?: boolean;
}) {
  return (
    <div className="flex flex-col gap-0.5">
      <span
        className="text-xs font-semibold tabular-nums"
        style={{ color: accent ? "oklch(0.72 0.115 82)" : "oklch(0.24 0.055 258)" }}
      >
        {value}
      </span>
      <span style={{ color: "oklch(0.60 0.015 258)", fontSize: "11px" }}>{label}</span>
    </div>
  );
}

export function FoundingLocationChart({ data }: Props) {
  const totalApplications = data.reduce((s, d) => s + d.total, 0);
  const totalApproved = data.reduce((s, d) => s + d.approved, 0);
  const totalPending = data.reduce((s, d) => s + d.pending, 0);

  if (data.length === 0) {
    return (
      <div
        className="rounded-xl border p-6"
        style={{
          background: "oklch(0.99 0.005 80)",
          borderColor: "oklch(0.88 0.010 258)",
        }}
      >
        <p
          className="text-xs font-semibold uppercase tracking-widest mb-1"
          style={{ color: "oklch(0.72 0.115 82)" }}
        >
          Founding 50
        </p>
        <h2
          className="font-semibold tracking-tight mb-4"
          style={{ color: "oklch(0.24 0.055 258)", fontSize: "15px" }}
        >
          Members by Barangay
        </h2>
        <p className="text-sm" style={{ color: "oklch(0.60 0.015 258)" }}>
          No founding reservations yet.
        </p>
      </div>
    );
  }

  return (
    <div
      className="rounded-xl border"
      style={{ background: "oklch(0.99 0.005 80)", borderColor: "oklch(0.88 0.010 258)" }}
    >
      {/* Header */}
      <div
        className="px-6 pt-6 pb-4 border-b"
        style={{ borderColor: "oklch(0.92 0.010 258)" }}
      >
        <p
          className="text-xs font-semibold uppercase tracking-widest mb-1"
          style={{ color: "oklch(0.72 0.115 82)" }}
        >
          Founding 50
        </p>
        <div className="flex items-end justify-between gap-4">
          <h2
            className="font-semibold tracking-tight"
            style={{ color: "oklch(0.24 0.055 258)", fontSize: "15px" }}
          >
            Members by Barangay
          </h2>
          <div className="flex items-center gap-5 pb-0.5">
            <StatusPip label="Total" value={totalApplications} />
            <StatusPip label="Approved" value={totalApproved} accent />
            <StatusPip label="Pending" value={totalPending} />
          </div>
        </div>
      </div>

      {/* Chart */}
      <div className="px-6 py-4">
        <ChartContainer
          config={chartConfig}
          className="w-full"
          style={{ height: Math.max(data.length * 36, 180) }}
        >
          <BarChart
            data={data}
            layout="vertical"
            margin={{ top: 0, right: 48, bottom: 0, left: 4 }}
            barSize={10}
            barCategoryGap="30%"
          >
            <CartesianGrid
              horizontal={false}
              strokeDasharray="3 3"
              stroke="oklch(0.90 0.010 258)"
            />
            <YAxis
              dataKey="barangay"
              type="category"
              tickLine={false}
              axisLine={false}
              width={148}
              tick={{
                fontSize: 12,
                fill: "oklch(0.24 0.055 258)",
                fontFamily: "var(--font-sans, sans-serif)",
              }}
            />
            <XAxis
              type="number"
              tickLine={false}
              axisLine={false}
              tick={{
                fontSize: 11,
                fill: "oklch(0.60 0.015 258)",
                fontFamily: "var(--font-sans, sans-serif)",
              }}
              allowDecimals={false}
            />
            <ChartTooltip
              cursor={{ fill: "oklch(0.94 0.015 75 / 0.6)" }}
              content={<ChartTooltipContent labelKey="barangay" indicator="dot" />}
            />
            <Bar dataKey="approved" name="Approved" radius={[0, 3, 3, 0]}>
              {data.map((entry, i) => (
                <Cell
                  key={entry.barangay}
                  fill={
                    i === 0
                      ? "oklch(0.72 0.115 82)"
                      : i === 1
                        ? "oklch(0.65 0.090 82)"
                        : i === 2
                          ? "oklch(0.60 0.075 82)"
                          : "oklch(0.32 0.050 258)"
                  }
                />
              ))}
            </Bar>
            <Bar
              dataKey="pending"
              name="Pending"
              radius={[0, 3, 3, 0]}
              fill="oklch(0.80 0.015 258)"
            />
          </BarChart>
        </ChartContainer>
      </div>

      {/* Footer */}
      <div
        className="px-6 py-3 border-t"
        style={{ borderColor: "oklch(0.92 0.010 258)" }}
      >
        <p style={{ color: "oklch(0.65 0.012 258)", fontSize: "11px" }}>
          Bars show approved (gold) and pending (grey) reservations per barangay.
        </p>
      </div>
    </div>
  );
}
