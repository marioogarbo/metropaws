"use client";

import {
  BarChart,
  Bar,
  XAxis,
  YAxis,
  CartesianGrid,
  ResponsiveContainer,
  Tooltip,
  Cell,
} from "recharts";
import type { DashboardSummary } from "@/app/admin/(protected)/dashboard/actions";

interface Props {
  summary: DashboardSummary;
}

export function PetSpeciesChart({ summary }: Props) {
  const total = summary.petDogs + summary.petCats + summary.petOther;

  const data = [
    { species: "Dogs", count: summary.petDogs, color: "oklch(0.72 0.115 82)" },
    { species: "Cats", count: summary.petCats, color: "oklch(0.32 0.050 258)" },
    ...(summary.petOther > 0
      ? [{ species: "Other", count: summary.petOther, color: "oklch(0.75 0.010 258)" }]
      : []),
  ];

  return (
    <div
      className="rounded-xl border p-6 flex flex-col gap-5"
      style={{
        background: "oklch(0.99 0.005 80)",
        borderColor: "oklch(0.88 0.010 258)",
      }}
    >
      <div className="flex items-start justify-between gap-4">
        <div>
          <p
            className="text-xs font-semibold uppercase tracking-widest mb-1"
            style={{ color: "oklch(0.72 0.115 82)" }}
          >
            Members
          </p>
          <h3
            className="font-semibold tracking-tight"
            style={{ color: "oklch(0.24 0.055 258)", fontSize: "15px" }}
          >
            Pet Species
          </h3>
        </div>
        <span
          className="text-xs font-medium tabular-nums mt-1"
          style={{ color: "oklch(0.60 0.015 258)" }}
        >
          {total} registered pet{total !== 1 ? "s" : ""}
        </span>
      </div>

      {total === 0 ? (
        <p className="text-sm" style={{ color: "oklch(0.60 0.015 258)" }}>
          No pets registered yet.
        </p>
      ) : (
        <>
          <div style={{ height: 120 }}>
            <ResponsiveContainer width="100%" height="100%">
              <BarChart
                data={data}
                margin={{ top: 0, right: 0, bottom: 0, left: -20 }}
                barSize={28}
              >
                <CartesianGrid
                  vertical={false}
                  strokeDasharray="3 3"
                  stroke="oklch(0.90 0.010 258)"
                />
                <XAxis
                  dataKey="species"
                  tickLine={false}
                  axisLine={false}
                  tick={{
                    fontSize: 12,
                    fill: "oklch(0.48 0.020 258)",
                    fontFamily: "var(--font-sans, sans-serif)",
                  }}
                />
                <YAxis
                  tickLine={false}
                  axisLine={false}
                  allowDecimals={false}
                  tick={{
                    fontSize: 11,
                    fill: "oklch(0.65 0.012 258)",
                    fontFamily: "var(--font-sans, sans-serif)",
                  }}
                />
                <Tooltip
                  cursor={{ fill: "oklch(0.94 0.015 75 / 0.6)" }}
                  contentStyle={{
                    background: "oklch(0.99 0.005 80)",
                    border: "1px solid oklch(0.88 0.010 258)",
                    borderRadius: "8px",
                    fontSize: "12px",
                    fontFamily: "var(--font-sans, sans-serif)",
                  }}
                  itemStyle={{ color: "oklch(0.24 0.055 258)" }}
                  formatter={(value) => [value, "Pets"]}
                />
                <Bar dataKey="count" radius={[4, 4, 0, 0]}>
                  {data.map((entry) => (
                    <Cell key={entry.species} fill={entry.color} />
                  ))}
                </Bar>
              </BarChart>
            </ResponsiveContainer>
          </div>
        </>
      )}
    </div>
  );
}
