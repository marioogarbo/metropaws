"use client";

import { useMemo, useState } from "react";
import { ArrowDown, ArrowUp, Search, Stethoscope } from "lucide-react";
import { cn } from "@/lib/utils";
import type { ClinicVisitSummary } from "@/app/admin/(protected)/dashboard/actions";

type SortKey = "claims" | "members" | "claimed_php" | "approved_php" | "last_visit";
type SortDirection = "asc" | "desc";

interface SortState {
  key: SortKey;
  direction: SortDirection;
}

const COLUMNS: { key: SortKey; label: string }[] = [
  { key: "claims", label: "Claims" },
  { key: "members", label: "Members" },
  { key: "claimed_php", label: "Claimed" },
  { key: "approved_php", label: "Approved" },
  { key: "last_visit", label: "Last visit" },
];

function formatPeso(php: number) {
  return `₱${php.toLocaleString("en-PH")}`;
}

function formatVisitDate(iso: string | null) {
  if (!iso) return "—";
  return new Date(iso).toLocaleDateString("en-PH", {
    year: "numeric",
    month: "short",
    day: "numeric",
  });
}

function compareClinics(a: ClinicVisitSummary, b: ClinicVisitSummary, sort: SortState) {
  const sign = sort.direction === "asc" ? 1 : -1;
  if (sort.key === "last_visit") {
    const aTime = a.last_visit ? new Date(a.last_visit).getTime() : 0;
    const bTime = b.last_visit ? new Date(b.last_visit).getTime() : 0;
    return (aTime - bTime) * sign;
  }
  return (a[sort.key] - b[sort.key]) * sign;
}

function SortableHeader({
  column,
  sort,
  onSort,
}: {
  column: { key: SortKey; label: string };
  sort: SortState;
  onSort: (key: SortKey) => void;
}) {
  const isActive = sort.key === column.key;
  const ariaSort = isActive
    ? sort.direction === "asc"
      ? "ascending"
      : "descending"
    : undefined;

  return (
    <th scope="col" aria-sort={ariaSort} className="px-4 py-3 text-right">
      <button
        type="button"
        onClick={() => onSort(column.key)}
        className={cn(
          "inline-flex items-center gap-1 text-xs font-semibold tracking-wide rounded",
          "focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[oklch(0.72_0.115_82)]",
          "transition-colors motion-reduce:transition-none",
          isActive
            ? "text-[oklch(0.24_0.055_258)]"
            : "text-[oklch(0.48_0.02_258)] hover:text-[oklch(0.24_0.055_258)]",
        )}
      >
        {column.label}
        {isActive &&
          (sort.direction === "asc" ? (
            <ArrowUp size={12} aria-hidden="true" />
          ) : (
            <ArrowDown size={12} aria-hidden="true" />
          ))}
      </button>
    </th>
  );
}

export function ClinicDirectory({ clinics }: { clinics: ClinicVisitSummary[] }) {
  const [query, setQuery] = useState("");
  const [sort, setSort] = useState<SortState>({ key: "claims", direction: "desc" });

  const visibleClinics = useMemo(() => {
    const needle = query.trim().toLowerCase();
    const matched = needle
      ? clinics.filter((c) => c.provider.toLowerCase().includes(needle))
      : clinics;
    return [...matched].sort((a, b) => compareClinics(a, b, sort));
  }, [clinics, query, sort]);

  function handleSort(key: SortKey) {
    setSort((prev) =>
      prev.key === key
        ? { key, direction: prev.direction === "desc" ? "asc" : "desc" }
        : { key, direction: "desc" },
    );
  }

  if (clinics.length === 0) {
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
          Partnership Prospects
        </p>
        <h2
          className="font-semibold tracking-tight mb-4"
          style={{ color: "oklch(0.24 0.055 258)", fontSize: "15px" }}
        >
          Clinic Directory
        </h2>
        <div className="flex flex-col items-center py-10 text-center">
          <Stethoscope
            size={24}
            className="text-[oklch(0.72_0.01_258)] mb-3"
            aria-hidden="true"
          />
          <p
            className="text-[oklch(0.48_0.02_258)] font-medium"
            style={{ fontSize: "14px" }}
          >
            No clinic visits yet
          </p>
          <p className="text-[oklch(0.72_0.01_258)] text-xs mt-1 max-w-xs">
            Clinics appear here as members submit reimbursement claims, ready for
            partnership outreach.
          </p>
        </div>
      </div>
    );
  }

  return (
    <div
      className="rounded-xl border overflow-hidden"
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
          Partnership Prospects
        </p>
        <div className="flex flex-wrap items-end justify-between gap-3">
          <div className="flex items-baseline gap-3">
            <h2
              className="font-semibold tracking-tight"
              style={{ color: "oklch(0.24 0.055 258)", fontSize: "15px" }}
            >
              Clinic Directory
            </h2>
            <span className="text-[oklch(0.48_0.02_258)] text-xs">
              {clinics.length} {clinics.length === 1 ? "clinic" : "clinics"} visited by
              members
            </span>
          </div>
          <div className="relative">
            <Search
              size={13}
              aria-hidden="true"
              className="absolute left-3 top-1/2 -translate-y-1/2 text-[oklch(0.60_0.015_258)]"
            />
            <input
              type="search"
              value={query}
              onChange={(e) => setQuery(e.target.value)}
              placeholder="Search clinics"
              aria-label="Search clinics by name"
              className={cn(
                "w-52 max-w-full bg-[oklch(0.97_0.01_80)] border border-[oklch(0.88_0.010_258)] rounded-lg pl-8 pr-3 py-2",
                "text-[oklch(0.24_0.055_258)] placeholder:text-[oklch(0.48_0.02_258)]",
                "focus:outline-none focus:ring-2 focus:ring-[oklch(0.72_0.115_82)] focus:border-transparent",
                "transition-colors duration-150 motion-reduce:transition-none",
              )}
              style={{ fontSize: "13px" }}
            />
          </div>
        </div>
      </div>

      {/* Table */}
      {visibleClinics.length === 0 ? (
        <p className="px-6 py-10 text-center text-[oklch(0.48_0.02_258)] text-sm">
          No clinics match &ldquo;{query.trim()}&rdquo;.
        </p>
      ) : (
        <div className="overflow-x-auto">
          <table className="w-full min-w-150">
            <thead>
              <tr className="bg-[oklch(0.97_0.01_80)]">
                <th
                  scope="col"
                  className="px-4 py-3 text-left text-[oklch(0.48_0.02_258)] text-xs font-semibold tracking-wide"
                >
                  Clinic
                </th>
                {COLUMNS.map((column) => (
                  <SortableHeader
                    key={column.key}
                    column={column}
                    sort={sort}
                    onSort={handleSort}
                  />
                ))}
              </tr>
            </thead>
            <tbody>
              {visibleClinics.map((clinic) => (
                <tr
                  key={clinic.provider}
                  className="border-t border-[oklch(0.92_0.010_258)] hover:bg-[oklch(0.98_0.006_80)] transition-colors motion-reduce:transition-none"
                >
                  <td className="px-4 py-3">
                    <span
                      className="text-[oklch(0.24_0.055_258)] font-medium"
                      style={{ fontSize: "13px" }}
                    >
                      {clinic.provider}
                    </span>
                  </td>
                  <td className="px-4 py-3 text-right text-[oklch(0.24_0.055_258)] text-xs tabular-nums">
                    {clinic.claims}
                  </td>
                  <td className="px-4 py-3 text-right text-[oklch(0.24_0.055_258)] text-xs tabular-nums">
                    {clinic.members}
                  </td>
                  <td className="px-4 py-3 text-right text-[oklch(0.48_0.02_258)] text-xs tabular-nums">
                    {formatPeso(clinic.claimed_php)}
                  </td>
                  <td className="px-4 py-3 text-right text-xs tabular-nums font-medium text-[oklch(0.24_0.055_258)]">
                    {formatPeso(clinic.approved_php)}
                  </td>
                  <td className="px-4 py-3 text-right text-[oklch(0.48_0.02_258)] text-xs whitespace-nowrap">
                    {formatVisitDate(clinic.last_visit)}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}

      {/* Footer */}
      <div
        className="px-6 py-3 border-t"
        style={{ borderColor: "oklch(0.92 0.010 258)" }}
      >
        <p style={{ color: "oklch(0.65 0.012 258)", fontSize: "11px" }}>
          Every clinic named on a reimbursement claim. The same clinic typed differently
          may appear as separate rows.
        </p>
      </div>
    </div>
  );
}
