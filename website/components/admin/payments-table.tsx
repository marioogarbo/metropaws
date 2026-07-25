"use client";

import { useState, useMemo, useDeferredValue, useTransition } from "react";
import {
  Search,
  Wallet,
  CheckCircle,
  Clock,
  XCircle,
  Hourglass,
  PawPrint,
  AlertTriangle,
  Send,
  Loader2,
  FileText,
} from "lucide-react";
import { toast } from "sonner";
import { cn } from "@/lib/utils";
import type { AdminPayment } from "@/app/admin/(protected)/payments/page";
import { resendInvoiceAction } from "@/app/admin/(protected)/payments/actions";

const STATUS_STYLES: Record<AdminPayment["status"], string> = {
  paid: "bg-[oklch(0.90_0.060_155)] text-[oklch(0.30_0.100_155)] border border-[oklch(0.80_0.080_155)]",
  pending:
    "bg-[oklch(0.93_0.020_80)] text-[oklch(0.45_0.060_80)] border border-[oklch(0.88_0.030_80)]",
  failed:
    "bg-[oklch(0.93_0.030_25)] text-[oklch(0.40_0.090_25)] border border-[oklch(0.87_0.050_25)]",
  expired:
    "bg-[oklch(0.94_0.015_75)] text-[oklch(0.48_0.02_258)] border border-[oklch(0.88_0.010_258)]",
};

const STATUS_ICONS: Record<AdminPayment["status"], React.ReactNode> = {
  paid: <CheckCircle size={13} />,
  pending: <Clock size={13} />,
  failed: <XCircle size={13} />,
  expired: <Hourglass size={13} />,
};

function StatusBadge({ status }: { status: AdminPayment["status"] }) {
  return (
    <span
      className={cn(
        "inline-flex items-center gap-1 px-2.5 py-1 rounded-full text-sm font-medium capitalize",
        STATUS_STYLES[status],
      )}
    >
      {STATUS_ICONS[status]}
      {status}
    </span>
  );
}

function formatPeso(value: number): string {
  return `₱${value.toLocaleString("en-PH")}`;
}

function formatDateTime(iso: string) {
  return new Date(iso).toLocaleDateString("en-PH", {
    year: "numeric",
    month: "short",
    day: "numeric",
    hour: "2-digit",
    minute: "2-digit",
  });
}

type FilterKey = "all" | "paid" | "pending" | "unsuccessful";

function matchesFilter(status: AdminPayment["status"], filter: FilterKey) {
  if (filter === "all") return true;
  if (filter === "unsuccessful") return status === "failed" || status === "expired";
  return status === filter;
}

function FilterTab({
  label,
  count,
  active,
  onClick,
}: {
  label: string;
  count: number;
  active: boolean;
  onClick: () => void;
}) {
  return (
    <button
      type="button"
      onClick={onClick}
      className={cn(
        "flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-sm font-medium transition-colors",
        active
          ? "bg-[oklch(0.24_0.055_258)] text-white"
          : "text-[oklch(0.48_0.02_258)] hover:text-[oklch(0.24_0.055_258)] hover:bg-[oklch(0.94_0.015_75)]",
      )}
    >
      {label}
      <span
        className={cn(
          "px-1.5 py-0.5 rounded-full text-xs font-semibold leading-none tabular-nums",
          active
            ? "bg-white/20 text-white"
            : "bg-[oklch(0.90_0.010_258)] text-[oklch(0.48_0.02_258)]",
        )}
      >
        {count}
      </span>
    </button>
  );
}

function ReceiptActions({ payment }: { payment: AdminPayment }) {
  const [isEmailing, startEmailing] = useTransition();

  // Only paid payments have a receipt.
  if (payment.status !== "paid") {
    return <span className="text-[oklch(0.78_0.008_258)] text-xs">—</span>;
  }

  // Opens the PDF inline in a new tab (the browser's PDF viewer offers a
  // download too). Same-origin, so the httpOnly admin cookie rides along.
  function handleView() {
    window.open(`/api/admin/payments/${payment.id}/invoice`, "_blank", "noopener");
  }

  function handleEmail() {
    startEmailing(async () => {
      const result = await resendInvoiceAction(payment.id);
      if (result.error) {
        toast.error(result.error);
        return;
      }
      toast.success(
        result.email ? `Receipt emailed to ${result.email}` : "Receipt emailed.",
      );
    });
  }

  return (
    <div className="flex items-center gap-1.5">
      <button
        type="button"
        onClick={handleView}
        title="View / download the receipt PDF"
        className={cn(
          "inline-flex items-center gap-1.5 px-2.5 py-1.5 rounded-lg text-xs font-medium transition-colors",
          "text-[oklch(0.24_0.055_258)] border border-[oklch(0.90_0.010_258)]",
          "hover:bg-[oklch(0.94_0.015_75)]",
        )}
      >
        <FileText size={13} />
        View
      </button>
      <button
        type="button"
        onClick={handleEmail}
        disabled={isEmailing}
        title="Email this receipt to the member again"
        aria-label="Email receipt to member"
        className={cn(
          "inline-flex items-center justify-center w-8 h-8 rounded-lg transition-colors",
          "text-[oklch(0.48_0.020_258)] hover:text-[oklch(0.24_0.055_258)] hover:bg-[oklch(0.94_0.015_75)]",
          "disabled:opacity-60 disabled:cursor-not-allowed",
        )}
      >
        {isEmailing ? (
          <Loader2 size={13} className="animate-spin" />
        ) : (
          <Send size={13} />
        )}
      </button>
    </div>
  );
}

function PaymentRow({ payment }: { payment: AdminPayment }) {
  const memberName =
    `${payment.member_first_name} ${payment.member_last_name}`.trim() || "Unknown member";
  const initials =
    ((payment.member_first_name[0] ?? "") + (payment.member_last_name[0] ?? "")).toUpperCase() ||
    "?";

  return (
    <tr className="border-b border-[oklch(0.92_0.010_258)] hover:bg-[oklch(0.98_0.006_80)] transition-colors">
      {/* Member */}
      <td className="px-4 py-3.5">
        <div className="flex items-center gap-2.5">
          <div className="w-8 h-8 rounded-full bg-[oklch(0.32_0.050_258)] flex items-center justify-center shrink-0">
            <span className="text-[oklch(0.72_0.115_82)] text-xs font-bold">{initials}</span>
          </div>
          <div>
            <p className="text-[oklch(0.24_0.055_258)] text-sm font-semibold leading-none">
              {memberName}
            </p>
            <p className="text-[oklch(0.62_0.012_258)] text-xs mt-0.5">
              {payment.member_email ?? "—"}
            </p>
          </div>
        </div>
      </td>

      {/* Plan + pet */}
      <td className="px-4 py-3.5">
        <p className="text-[oklch(0.36_0.030_258)] text-sm font-medium">
          {payment.plan_name ?? "—"}
        </p>
        {payment.pet_name && (
          <p className="text-[oklch(0.62_0.012_258)] text-xs mt-0.5 flex items-center gap-1">
            <PawPrint size={11} />
            {payment.pet_name}
          </p>
        )}
      </td>

      {/* Amount */}
      <td className="px-4 py-3.5">
        <p className="text-[oklch(0.24_0.055_258)] text-sm font-semibold tabular-nums">
          {formatPeso(payment.amount_php)}
        </p>
      </td>

      {/* Status */}
      <td className="px-4 py-3.5">
        <StatusBadge status={payment.status} />
      </td>

      {/* PayMongo reference */}
      <td className="px-4 py-3.5">
        <p className="text-[oklch(0.52_0.018_258)] text-xs font-mono break-all">
          {payment.provider_payment_id ?? "—"}
        </p>
      </td>

      {/* Date */}
      <td className="px-4 py-3.5">
        <p className="text-[oklch(0.52_0.018_258)] text-sm tabular-nums whitespace-nowrap">
          {formatDateTime(payment.paid_at ?? payment.created_at)}
        </p>
        {payment.paid_at && (
          <p className="text-[oklch(0.62_0.012_258)] text-xs mt-0.5">paid</p>
        )}
      </td>

      {/* Receipt actions */}
      <td className="px-4 py-3.5">
        <ReceiptActions payment={payment} />
      </td>
    </tr>
  );
}

export function PaymentsTable({
  payments,
  fetchError,
}: {
  payments: AdminPayment[];
  fetchError: boolean;
}) {
  const [filter, setFilter] = useState<FilterKey>("all");
  const [query, setQuery] = useState("");
  const deferredQuery = useDeferredValue(query);

  const counts = useMemo(
    () => ({
      all: payments.length,
      paid: payments.filter((p) => p.status === "paid").length,
      pending: payments.filter((p) => p.status === "pending").length,
      unsuccessful: payments.filter(
        (p) => p.status === "failed" || p.status === "expired",
      ).length,
    }),
    [payments],
  );

  const paidTotal = useMemo(
    () =>
      payments
        .filter((p) => p.status === "paid")
        .reduce((sum, p) => sum + p.amount_php, 0),
    [payments],
  );

  const filtered = useMemo(
    () =>
      payments.filter((p) => {
        if (!matchesFilter(p.status, filter)) return false;
        if (!deferredQuery.trim()) return true;
        const q = deferredQuery.toLowerCase();
        return (
          p.member_first_name.toLowerCase().includes(q) ||
          p.member_last_name.toLowerCase().includes(q) ||
          (p.member_email ?? "").toLowerCase().includes(q) ||
          (p.pet_name ?? "").toLowerCase().includes(q) ||
          (p.plan_name ?? "").toLowerCase().includes(q) ||
          (p.provider_payment_id ?? "").toLowerCase().includes(q)
        );
      }),
    [payments, filter, deferredQuery],
  );

  const FILTERS: { key: FilterKey; label: string }[] = [
    { key: "all", label: "All" },
    { key: "paid", label: "Paid" },
    { key: "pending", label: "Pending" },
    { key: "unsuccessful", label: "Unsuccessful" },
  ];

  if (fetchError) {
    return (
      <div className="rounded-xl border border-[oklch(0.87_0.050_25)] bg-[oklch(0.96_0.020_25)] px-5 py-4 flex items-center gap-3">
        <AlertTriangle size={16} className="text-[oklch(0.45_0.090_25)] shrink-0" />
        <p className="text-sm text-[oklch(0.40_0.090_25)]">
          Couldn&apos;t load payments from the server. Refresh to try again.
        </p>
      </div>
    );
  }

  return (
    <div className="space-y-4">
      <div className="flex flex-col sm:flex-row gap-3 sm:items-center sm:justify-between">
        <div className="flex gap-1 flex-wrap">
          {FILTERS.map(({ key, label }) => (
            <FilterTab
              key={key}
              label={label}
              count={counts[key]}
              active={filter === key}
              onClick={() => setFilter(key)}
            />
          ))}
        </div>

        <div className="relative max-w-xs w-full sm:w-64">
          <Search
            size={13}
            className="absolute left-3 top-1/2 -translate-y-1/2 text-[oklch(0.72_0.010_258)] pointer-events-none"
          />
          <input
            type="search"
            placeholder="Search member, plan, reference..."
            value={query}
            onChange={(e) => setQuery(e.target.value)}
            className="w-full pl-8 pr-3 py-2 text-sm border border-[oklch(0.88_0.010_258)] rounded-lg bg-[oklch(0.99_0.005_80)] text-[oklch(0.24_0.055_258)] placeholder:text-[oklch(0.72_0.010_258)] focus:outline-none focus:ring-2 focus:ring-[oklch(0.72_0.115_82)]"
          />
        </div>
      </div>

      <div className="rounded-xl border border-[oklch(0.88_0.010_258)] overflow-hidden bg-[oklch(0.99_0.005_80)]">
        {filtered.length === 0 ? (
          <div className="py-16 text-center flex flex-col items-center gap-3">
            <div className="w-10 h-10 rounded-full bg-[oklch(0.94_0.015_75)] flex items-center justify-center">
              <Wallet size={16} className="text-[oklch(0.72_0.010_258)]" />
            </div>
            <div>
              <p className="text-[oklch(0.48_0.02_258)] text-sm font-medium">
                {payments.length === 0 ? "No payments yet" : "No results found"}
              </p>
              <p className="text-[oklch(0.72_0.010_258)] text-sm mt-1">
                {payments.length === 0
                  ? "Member checkouts will appear here once they pay."
                  : "Try adjusting your search or filter."}
              </p>
            </div>
          </div>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full text-left">
              <thead>
                <tr className="border-b border-[oklch(0.89_0.014_258)] bg-[oklch(0.94_0.013_258)]">
                  {["Member", "Plan", "Amount", "Status", "PayMongo Ref", "Date", "Receipt"].map(
                    (heading) => (
                      <th
                        key={heading}
                        className="px-4 py-3 text-[oklch(0.40_0.025_258)] text-xs font-semibold uppercase tracking-wider"
                      >
                        {heading}
                      </th>
                    ),
                  )}
                </tr>
              </thead>
              <tbody>
                {filtered.map((payment) => (
                  <PaymentRow key={payment.id} payment={payment} />
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>

      <div className="flex items-center justify-between">
        <p className="text-[oklch(0.62_0.012_258)] text-xs tabular-nums">
          Paid total: <span className="font-semibold">{formatPeso(paidTotal)}</span> ·{" "}
          {counts.paid} paid
        </p>
        {filtered.length > 0 && (
          <p className="text-[oklch(0.62_0.012_258)] text-xs text-right tabular-nums">
            Showing {filtered.length} of {payments.length} payments
          </p>
        )}
      </div>
    </div>
  );
}
