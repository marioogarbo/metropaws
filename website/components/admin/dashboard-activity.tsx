"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import type { RecentReservation } from "@/app/admin/(protected)/dashboard/actions";

const FOUNDING_SLOTS = 50;

interface FoundingProgressProps {
  approved: number;
}

export function FoundingProgressCard({ approved }: FoundingProgressProps) {
  const pct = Math.min(100, (approved / FOUNDING_SLOTS) * 100);
  const remaining = Math.max(0, FOUNDING_SLOTS - approved);
  const isComplete = approved >= FOUNDING_SLOTS;
  const [barWidth, setBarWidth] = useState(0);

  useEffect(() => {
    const t = setTimeout(() => setBarWidth(pct), 80);
    return () => clearTimeout(t);
  }, [pct]);

  return (
    <div
      className="rounded-xl border p-6 flex flex-col gap-5 transition-colors duration-500"
      style={{
        background: isComplete ? "oklch(0.97 0.018 82)" : "oklch(0.99 0.005 80)",
        borderColor: isComplete ? "oklch(0.88 0.040 82)" : "oklch(0.88 0.010 258)",
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
          Approval Progress
        </h3>
      </div>

      <div className="flex flex-col gap-4">
        <div className="flex items-end gap-2">
          <span
            className="font-bold tabular-nums"
            style={{ fontSize: "40px", lineHeight: 1, color: "oklch(0.72 0.115 82)" }}
          >
            {approved}
          </span>
          <span
            className="font-medium pb-1"
            style={{ fontSize: "18px", color: "oklch(0.60 0.015 258)" }}
          >
            / {FOUNDING_SLOTS}
          </span>
        </div>

        {/* Progress bar */}
        <div className="flex flex-col gap-1.5">
          <div
            className="w-full rounded-full overflow-hidden"
            style={{ height: "6px", background: "oklch(0.92 0.010 258)" }}
          >
            <div
              className="h-full rounded-full transition-[width] duration-700 ease-out"
              style={{
                width: `${barWidth}%`,
                background: pct >= 80 ? "oklch(0.65 0.090 82)" : "oklch(0.72 0.115 82)",
              }}
            />
          </div>
          {remaining > 0 ? (
            <p className="text-xs" style={{ color: "oklch(0.60 0.015 258)" }}>
              {remaining} slot{remaining === 1 ? "" : "s"} remaining
            </p>
          ) : (
            <p
              className="text-xs font-semibold"
              style={{ color: "oklch(0.50 0.085 82)" }}
            >
              ✓ All founding slots filled
            </p>
          )}
        </div>
      </div>
    </div>
  );
}

interface RecentActivityProps {
  reservations: RecentReservation[];
}

const STATUS_STYLES: Record<
  RecentReservation["status"],
  { label: string; bg: string; color: string }
> = {
  approved: {
    label: "Approved",
    bg: "oklch(0.94 0.030 82)",
    color: "oklch(0.45 0.080 82)",
  },
  pending: {
    label: "Pending",
    bg: "oklch(0.92 0.010 258)",
    color: "oklch(0.40 0.030 258)",
  },
  rejected: {
    label: "Rejected",
    bg: "oklch(0.94 0.008 258)",
    color: "oklch(0.55 0.015 258)",
  },
};

function timeAgo(dateStr: string): string {
  const diff = Date.now() - new Date(dateStr).getTime();
  const minutes = Math.floor(diff / 60000);
  if (minutes < 60) return `${minutes}m ago`;
  const hours = Math.floor(minutes / 60);
  if (hours < 24) return `${hours}h ago`;
  const days = Math.floor(hours / 24);
  return `${days}d ago`;
}

export function RecentReservationsCard({ reservations }: RecentActivityProps) {
  return (
    <div
      className="rounded-xl border flex flex-col"
      style={{
        background: "oklch(0.99 0.005 80)",
        borderColor: "oklch(0.88 0.010 258)",
      }}
    >
      <div
        className="px-6 pt-6 pb-4 border-b flex items-center justify-between"
        style={{ borderColor: "oklch(0.92 0.010 258)" }}
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
            Recent Reservations
          </h3>
        </div>
        <Link
          href="/admin/reservations"
          className="text-xs font-semibold transition-colors hover:text-(--color-navy)"
          style={{ color: "oklch(0.48 0.020 258)" }}
        >
          View all
        </Link>
      </div>

      {reservations.length === 0 ? (
        <p className="px-6 py-5 text-sm" style={{ color: "oklch(0.60 0.015 258)" }}>
          No reservations yet.
        </p>
      ) : (
        <div className="divide-y" style={{ borderColor: "oklch(0.93 0.008 258)" }}>
          {reservations.map((r) => {
            const style = STATUS_STYLES[r.status];
            return (
              <div
                key={r.id}
                className="px-6 py-3.5 flex items-center justify-between gap-4 transition-colors hover:bg-[oklch(0.97_0.006_258)]"
              >
                <div className="min-w-0">
                  <p
                    className="text-sm font-medium truncate"
                    style={{ color: "oklch(0.24 0.055 258)" }}
                  >
                    {r.first_name} {r.last_name}
                  </p>
                  <p
                    className="text-xs mt-0.5 truncate"
                    style={{ color: "oklch(0.60 0.015 258)" }}
                  >
                    {r.barangay}
                  </p>
                </div>
                <div className="flex items-center gap-3 shrink-0">
                  <span
                    className="text-xs font-medium px-2 py-0.5 rounded-full"
                    style={{ background: style.bg, color: style.color }}
                  >
                    {style.label}
                  </span>
                  <span
                    className="text-xs tabular-nums"
                    style={{ color: "oklch(0.65 0.012 258)" }}
                  >
                    {timeAgo(r.created_at)}
                  </span>
                </div>
              </div>
            );
          })}
        </div>
      )}
    </div>
  );
}
