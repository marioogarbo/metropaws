"use client";

import {
  useActionState,
  useState,
  useTransition,
  useRef,
  useEffect,
  useMemo,
  useDeferredValue,
  memo,
} from "react";
import { toast } from "sonner";
import {
  ChevronDown,
  ChevronUp,
  CheckCircle,
  XCircle,
  Clock,
  Search,
  Mail,
  StickyNote,
  Receipt,
  FileText,
  HelpCircle,
  Banknote,
  PawPrint,
} from "lucide-react";
import { cn } from "@/lib/utils";
import {
  reviewReimbursementAction,
  markReimbursementPaidAction,
  type ActionState,
} from "@/app/admin/(protected)/reimbursements/actions";
import type { AdminReimbursement } from "@/app/admin/(protected)/reimbursements/page";

// ── Helpers ───────────────────────────────────────────────────────────────────

const STATUS_STYLES: Record<string, string> = {
  pending:
    "bg-[oklch(0.93_0.020_80)] text-[oklch(0.45_0.060_80)] border border-[oklch(0.88_0.030_80)]",
  under_review:
    "bg-[oklch(0.93_0.020_258)] text-[oklch(0.40_0.050_258)] border border-[oklch(0.86_0.030_258)]",
  needs_info:
    "bg-[oklch(0.93_0.040_80)] text-[oklch(0.42_0.080_80)] border border-[oklch(0.86_0.055_80)]",
  approved:
    "bg-[oklch(0.93_0.040_155)] text-[oklch(0.35_0.090_155)] border border-[oklch(0.85_0.060_155)]",
  rejected:
    "bg-[oklch(0.93_0.030_25)] text-[oklch(0.40_0.090_25)] border border-[oklch(0.87_0.050_25)]",
  paid:
    "bg-[oklch(0.90_0.060_155)] text-[oklch(0.30_0.100_155)] border border-[oklch(0.80_0.080_155)]",
};

const STATUS_ICONS: Record<string, React.ReactNode> = {
  pending: <Clock size={13} />,
  under_review: <Clock size={13} />,
  needs_info: <HelpCircle size={13} />,
  approved: <CheckCircle size={13} />,
  rejected: <XCircle size={13} />,
  paid: <Banknote size={13} />,
};

function statusLabel(status: string) {
  return status.replace(/_/g, " ");
}

function StatusBadge({ status }: { status: string }) {
  return (
    <span
      className={cn(
        "inline-flex items-center gap-1 px-2.5 py-1 rounded-full text-sm font-medium capitalize",
        STATUS_STYLES[status] ??
          "bg-[oklch(0.94_0.015_75)] text-[oklch(0.48_0.02_258)]",
      )}
    >
      {STATUS_ICONS[status]}
      {statusLabel(status)}
    </span>
  );
}

function peso(centavos: number) {
  return new Intl.NumberFormat("en-PH", {
    style: "currency",
    currency: "PHP",
  }).format(centavos / 100);
}

interface PayoutShaped {
  payout_method: string | null;
  payout_bank_name?: string | null;
  payout_account_name?: string | null;
  payout_account_number?: string | null;
}

function formatPayout(target: PayoutShaped, cashLabel = "Cash"): string | null {
  if (!target.payout_method) return null;
  if (target.payout_method === "cash") {
    return [cashLabel, target.payout_account_name].filter(Boolean).join(" · ");
  }
  if (!target.payout_account_number) return null;
  const label =
    target.payout_method === "gcash"
      ? "GCash"
      : target.payout_method === "bank"
        ? "Bank"
        : target.payout_method;
  return [label, target.payout_bank_name, target.payout_account_name, target.payout_account_number]
    .filter(Boolean)
    .join(" · ");
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

function formatDate(iso: string) {
  return new Date(iso).toLocaleDateString("en-PH", {
    year: "numeric",
    month: "short",
    day: "numeric",
  });
}

// ── Filter tabs ─────────────────────────────────────────────────────────────

type FilterKey = "all" | "to_review" | "approved" | "paid" | "rejected";

const OPEN_STATUSES = ["pending", "under_review", "needs_info"];

function matchesFilter(status: string, filter: FilterKey) {
  if (filter === "all") return true;
  if (filter === "to_review") return OPEN_STATUSES.includes(status);
  return status === filter;
}

function FilterTab({
  label,
  count,
  active,
  attention = false,
  onClick,
}: {
  label: string;
  count: number;
  active: boolean;
  attention?: boolean;
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
            : attention
              ? "bg-[oklch(0.90_0.055_82)] text-[oklch(0.40_0.070_82)]"
              : "bg-[oklch(0.90_0.010_258)] text-[oklch(0.48_0.02_258)]",
        )}
      >
        {count}
      </span>
    </button>
  );
}

// ── Receipt preview ───────────────────────────────────────────────────────────

function ReceiptPreview({ url }: { url: string }) {
  const isPdf = url.toLowerCase().split("?")[0].endsWith(".pdf");
  return (
    <div>
      <p className="flex items-center gap-1.5 text-[oklch(0.55_0.018_258)] text-xs font-medium uppercase tracking-wider mb-1.5">
        <Receipt size={12} />
        Receipt
      </p>
      {isPdf ? (
        <a
          href={url}
          target="_blank"
          rel="noopener noreferrer"
          className="inline-flex items-center gap-2 px-3 py-2 rounded-lg border border-[oklch(0.88_0.010_258)] text-sm font-medium text-[oklch(0.24_0.055_258)] hover:bg-[oklch(0.96_0.008_80)] transition-colors"
        >
          <FileText size={14} />
          Open receipt (PDF)
        </a>
      ) : (
        <a href={url} target="_blank" rel="noopener noreferrer" className="block">
          {/* eslint-disable-next-line @next/next/no-img-element */}
          <img
            src={url}
            alt="Receipt"
            className="max-h-72 w-auto rounded-lg border border-[oklch(0.88_0.010_258)] object-contain bg-white"
          />
        </a>
      )}
    </div>
  );
}

// ── Row ───────────────────────────────────────────────────────────────────────

function ClaimRowBase({ claim }: { claim: AdminReimbursement }) {
  const [expanded, setExpanded] = useState(false);
  const [localStatus, setLocalStatus] = useState(claim.status);
  const [adminNote, setAdminNote] = useState(claim.admin_notes ?? "");
  const [amountPeso, setAmountPeso] = useState(
    ((claim.approved_amount_centavos ?? claim.claimed_amount_centavos) / 100).toFixed(2),
  );
  const [paymentRef, setPaymentRef] = useState("");

  const [isReviewPending, startReviewTransition] = useTransition();
  const [reviewState, reviewFormAction] = useActionState<ActionState, FormData>(
    reviewReimbursementAction,
    { error: null },
  );
  const reviewKindRef = useRef<string | null>(null);

  const [isPaidPending, startPaidTransition] = useTransition();
  const [paidState, paidFormAction] = useActionState<ActionState, FormData>(
    markReimbursementPaidAction,
    { error: null },
  );

  const anyPending = isReviewPending || isPaidPending;

  // Toast — review actions
  const prevReviewRef = useRef(false);
  useEffect(() => {
    if (prevReviewRef.current && !isReviewPending) {
      if (reviewState.error) toast.error(reviewState.error);
      else {
        const k = reviewKindRef.current;
        toast.success(
          k === "approved"
            ? "Claim approved"
            : k === "rejected"
              ? "Claim rejected"
              : "Info requested from member",
        );
        reviewKindRef.current = null;
      }
    }
    prevReviewRef.current = isReviewPending;
  }, [isReviewPending, reviewState]);

  // Toast — mark paid
  const prevPaidRef = useRef(false);
  useEffect(() => {
    if (prevPaidRef.current && !isPaidPending) {
      if (paidState.error) toast.error(paidState.error);
      else toast.success("Marked as paid");
    }
    prevPaidRef.current = isPaidPending;
  }, [isPaidPending, paidState]);

  const centavos = Math.round((parseFloat(amountPeso) || 0) * 100);
  const memberName = `${claim.member.first_name} ${claim.member.last_name}`;
  const initials = (
    claim.member.first_name[0] + claim.member.last_name[0]
  ).toUpperCase();
  const detailId = `claim-detail-${claim.id}`;
  const isPaid = localStatus === "paid";
  const isApproved = localStatus === "approved";

  return (
    <>
      <tr
        className={cn(
          "border-b border-[oklch(0.92_0.010_258)] transition-colors",
          expanded ? "bg-[oklch(0.96_0.010_80)]" : "hover:bg-[oklch(0.98_0.006_80)]",
        )}
      >
        {/* Member + pet */}
        <td className="px-4 py-3.5">
          <div className="flex items-center gap-2.5">
            <div className="w-8 h-8 rounded-full bg-[oklch(0.32_0.050_258)] flex items-center justify-center shrink-0">
              <span className="text-[oklch(0.72_0.115_82)] text-xs font-bold">
                {initials}
              </span>
            </div>
            <div>
              <p className="text-[oklch(0.24_0.055_258)] text-sm font-semibold leading-none">
                {memberName}
              </p>
              <p className="text-[oklch(0.62_0.012_258)] text-xs mt-0.5 flex items-center gap-1">
                <PawPrint size={11} />
                {claim.pet.name}
              </p>
            </div>
          </div>
        </td>

        {/* Service + provider */}
        <td className="px-4 py-3.5">
          <p className="text-[oklch(0.36_0.030_258)] text-sm font-medium">
            {claim.service_type.name}
          </p>
          <p className="text-[oklch(0.62_0.012_258)] text-xs mt-0.5">
            {claim.provider_name}
          </p>
          {claim.payout_target === "provider" && (
            <span className="inline-flex items-center gap-1 mt-1 px-1.5 py-0.5 rounded text-[10px] font-semibold uppercase tracking-wide bg-[oklch(0.93_0.040_155)] text-[oklch(0.35_0.090_155)]">
              <Banknote size={9} /> Pay provider directly
            </span>
          )}
        </td>

        {/* Amount */}
        <td className="px-4 py-3.5">
          <p className="text-[oklch(0.24_0.055_258)] text-sm font-semibold tabular-nums">
            {peso(claim.claimed_amount_centavos)}
          </p>
          {claim.approved_amount_centavos != null && (
            <p className="text-[oklch(0.35_0.090_155)] text-xs mt-0.5 tabular-nums">
              {peso(claim.approved_amount_centavos)} approved
            </p>
          )}
        </td>

        {/* Status */}
        <td className="px-4 py-3.5">
          <StatusBadge status={localStatus} />
        </td>

        {/* Submitted */}
        <td className="px-4 py-3.5">
          <p className="text-[oklch(0.52_0.018_258)] text-sm tabular-nums">
            {formatDateTime(claim.created_at)}
          </p>
        </td>

        {/* Expand */}
        <td className="px-4 py-3.5 w-32">
          <div className="flex items-center justify-end">
            <button
              type="button"
              onClick={() => setExpanded((v) => !v)}
              className="inline-flex items-center gap-1 px-2.5 py-1.5 rounded-lg text-xs font-medium text-[oklch(0.48_0.02_258)] hover:text-[oklch(0.24_0.055_258)] hover:bg-[oklch(0.94_0.012_258)] transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[oklch(0.72_0.115_82)]"
              aria-expanded={expanded}
              aria-controls={detailId}
            >
              {expanded ? (
                <>Collapse <ChevronUp size={12} /></>
              ) : (
                <>Review <ChevronDown size={12} /></>
              )}
            </button>
          </div>
        </td>
      </tr>

      {expanded && (
        <tr className="border-b border-[oklch(0.92_0.010_258)] bg-[oklch(0.96_0.010_80)]">
          <td colSpan={6} className="px-6 pt-5 pb-6 border-t border-[oklch(0.90_0.010_258)]">
            <div id={detailId} className="grid grid-cols-1 md:grid-cols-2 gap-8">
              {/* Left: receipt + claim details */}
              <div className="space-y-4">
                <ReceiptPreview url={claim.receipt_url} />
                <DetailRow label="Member email" icon={<Mail size={12} />} value={claim.member.email ?? "—"} />
                {claim.payout_target === "provider" ? (
                  claim.provider && formatPayout(claim.provider, "Cash") ? (
                    <div className="rounded-lg border border-[oklch(0.85_0.060_155)] bg-[oklch(0.96_0.030_155)] px-3 py-2.5">
                      <p className="flex items-center gap-1.5 text-[oklch(0.35_0.070_155)] text-xs font-semibold uppercase tracking-wider mb-1">
                        <Banknote size={12} /> Pay provider directly
                      </p>
                      <p className="text-[oklch(0.24_0.055_258)] text-sm font-medium">
                        {claim.provider.name} — {formatPayout(claim.provider, "Cash")}
                      </p>
                    </div>
                  ) : (
                    <div className="rounded-lg border border-[oklch(0.87_0.050_25)] bg-[oklch(0.96_0.020_25)] px-3 py-2.5">
                      <p className="flex items-center gap-1.5 text-[oklch(0.45_0.090_25)] text-xs font-medium">
                        <Banknote size={12} /> No payout details on file for{" "}
                        {claim.provider?.name ?? "this provider"} — add them on the Providers
                        page before marking paid.
                      </p>
                    </div>
                  )
                ) : formatPayout(claim.member, "Cash pickup at clinic") ? (
                  <div className="rounded-lg border border-[oklch(0.85_0.060_155)] bg-[oklch(0.96_0.030_155)] px-3 py-2.5">
                    <p className="flex items-center gap-1.5 text-[oklch(0.35_0.070_155)] text-xs font-semibold uppercase tracking-wider mb-1">
                      <Banknote size={12} /> Send payout to
                    </p>
                    <p className="text-[oklch(0.24_0.055_258)] text-sm font-medium">
                      {formatPayout(claim.member, "Cash pickup at clinic")}
                    </p>
                  </div>
                ) : (
                  <div className="rounded-lg border border-[oklch(0.87_0.050_25)] bg-[oklch(0.96_0.020_25)] px-3 py-2.5">
                    <p className="flex items-center gap-1.5 text-[oklch(0.45_0.090_25)] text-xs font-medium">
                      <Banknote size={12} /> No payout method on file — ask the member to add one.
                    </p>
                  </div>
                )}
                <DetailRow
                  label="Plan"
                  value={claim.pet.plan_type ?? claim.member.plan_type ?? "—"}
                />
                <DetailRow label="Service date" value={formatDate(claim.service_date)} />
                <DetailRow label="Reference no." value={claim.receipt_reference ?? "—"} />
                <DetailRow label="Member notes" value={claim.member_notes ?? "—"} multiline />
              </div>

              {/* Right: admin actions */}
              <div className="space-y-4">
                {isPaid ? (
                  <div className="rounded-lg border border-[oklch(0.80_0.080_155)] bg-[oklch(0.95_0.040_155)] px-4 py-3">
                    <p className="text-[oklch(0.30_0.100_155)] text-sm font-semibold flex items-center gap-1.5">
                      <Banknote size={14} />
                      Reimbursement released
                    </p>
                    {claim.paid_at && (
                      <p className="text-[oklch(0.35_0.060_155)] text-xs mt-1">
                        Paid {formatDateTime(claim.paid_at)} ·{" "}
                        {peso(claim.approved_amount_centavos ?? 0)}
                      </p>
                    )}
                    {claim.paid_reference && (
                      <p className="text-[oklch(0.35_0.060_155)] text-xs mt-0.5">
                        Ref: {claim.paid_reference}
                      </p>
                    )}
                  </div>
                ) : (
                  <>
                    {/* Admin note */}
                    <div>
                      <label
                        htmlFor={`notes-${claim.id}`}
                        className="flex items-center gap-1.5 text-[oklch(0.48_0.02_258)] text-xs font-semibold uppercase tracking-wider mb-1.5"
                      >
                        <StickyNote size={12} />
                        Note to member (shown on reject / request info)
                      </label>
                      <textarea
                        id={`notes-${claim.id}`}
                        rows={2}
                        value={adminNote}
                        onChange={(e) => setAdminNote(e.target.value)}
                        placeholder="e.g. Receipt is blurry — please re-upload a clearer photo."
                        disabled={anyPending}
                        className="w-full text-sm border border-[oklch(0.88_0.010_258)] rounded-lg px-3 py-2 bg-[oklch(0.99_0.005_80)] text-[oklch(0.24_0.055_258)] placeholder:text-[oklch(0.72_0.010_258)] focus:outline-none focus:ring-2 focus:ring-[oklch(0.72_0.115_82)] resize-none disabled:opacity-50"
                      />
                    </div>

                    {/* Approved amount */}
                    <div>
                      <label
                        htmlFor={`amount-${claim.id}`}
                        className="block text-[oklch(0.48_0.02_258)] text-xs font-semibold uppercase tracking-wider mb-1.5"
                      >
                        Amount to approve (₱)
                      </label>
                      <input
                        id={`amount-${claim.id}`}
                        type="number"
                        min="0"
                        step="0.01"
                        value={amountPeso}
                        onChange={(e) => setAmountPeso(e.target.value)}
                        disabled={anyPending}
                        className="w-40 text-sm border border-[oklch(0.88_0.010_258)] rounded-lg px-3 py-2 bg-[oklch(0.99_0.005_80)] text-[oklch(0.24_0.055_258)] focus:outline-none focus:ring-2 focus:ring-[oklch(0.72_0.115_82)] disabled:opacity-50"
                      />
                      <p className="text-[oklch(0.62_0.012_258)] text-xs mt-1">
                        Claimed: {peso(claim.claimed_amount_centavos)}
                      </p>
                    </div>

                    {(reviewState.error || paidState.error) && (
                      <p className="text-[oklch(0.40_0.090_25)] text-sm">
                        {reviewState.error ?? paidState.error}
                      </p>
                    )}

                    {/* Mark paid (approved only) — requires a payment reference */}
                    {isApproved && (
                      <form
                        action={(fd) => {
                          startPaidTransition(() => paidFormAction(fd));
                        }}
                        className="space-y-2 rounded-lg border border-[oklch(0.85_0.060_155)] bg-[oklch(0.97_0.020_155)] p-3"
                      >
                        <input type="hidden" name="reimbursementId" value={claim.id} />
                        <input type="hidden" name="admin_notes" value={adminNote} />
                        <label
                          htmlFor={`payref-${claim.id}`}
                          className="block text-[oklch(0.35_0.070_155)] text-xs font-semibold uppercase tracking-wider"
                        >
                          Payment reference (GCash / bank txn no.)
                        </label>
                        <input
                          id={`payref-${claim.id}`}
                          name="payment_reference"
                          value={paymentRef}
                          onChange={(e) => setPaymentRef(e.target.value)}
                          placeholder="e.g. GCash ref 1234567890"
                          disabled={anyPending}
                          className="w-full text-sm border border-[oklch(0.85_0.040_155)] rounded-lg px-3 py-2 bg-white text-[oklch(0.24_0.055_258)] placeholder:text-[oklch(0.72_0.010_258)] focus:outline-none focus:ring-2 focus:ring-[oklch(0.72_0.115_82)] disabled:opacity-50"
                        />
                        <button
                          type="submit"
                          disabled={anyPending || !paymentRef.trim()}
                          className="flex items-center gap-2 px-4 py-2 rounded-lg bg-[oklch(0.30_0.100_155)] text-white text-sm font-semibold hover:bg-[oklch(0.26_0.100_155)] transition-colors disabled:opacity-50 disabled:cursor-not-allowed focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[oklch(0.72_0.115_82)]"
                        >
                          <Banknote size={14} />
                          {isPaidPending ? "Marking…" : "Mark as paid"}
                        </button>
                      </form>
                    )}

                    {/* Approve / Request info / Reject */}
                    <div className="flex flex-wrap gap-2 pt-1">
                      <form
                        action={(fd) => {
                          reviewKindRef.current = "approved";
                          setLocalStatus("approved");
                          startReviewTransition(() => reviewFormAction(fd));
                        }}
                      >
                        <input type="hidden" name="reimbursementId" value={claim.id} />
                        <input type="hidden" name="status" value="approved" />
                        <input type="hidden" name="approved_amount_centavos" value={centavos} />
                        <input type="hidden" name="admin_notes" value={adminNote} />
                        <button
                          type="submit"
                          disabled={anyPending || centavos <= 0}
                          className="flex items-center gap-2 px-4 py-2 rounded-lg bg-[oklch(0.35_0.090_155)] text-white text-sm font-semibold hover:bg-[oklch(0.30_0.090_155)] transition-colors disabled:opacity-50 disabled:cursor-not-allowed focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[oklch(0.72_0.115_82)]"
                        >
                          <CheckCircle size={14} />
                          {isReviewPending && reviewKindRef.current === "approved"
                            ? "Approving…"
                            : "Approve"}
                        </button>
                      </form>

                      <form
                        action={(fd) => {
                          reviewKindRef.current = "needs_info";
                          setLocalStatus("needs_info");
                          startReviewTransition(() => reviewFormAction(fd));
                        }}
                      >
                        <input type="hidden" name="reimbursementId" value={claim.id} />
                        <input type="hidden" name="status" value="needs_info" />
                        <input type="hidden" name="admin_notes" value={adminNote} />
                        <button
                          type="submit"
                          disabled={anyPending}
                          className="flex items-center gap-2 px-4 py-2 rounded-lg border border-[oklch(0.86_0.055_80)] bg-[oklch(0.95_0.040_80)] text-[oklch(0.40_0.080_80)] text-sm font-semibold hover:bg-[oklch(0.90_0.055_80)] transition-colors disabled:opacity-50 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[oklch(0.72_0.115_82)]"
                        >
                          <HelpCircle size={14} />
                          {isReviewPending && reviewKindRef.current === "needs_info"
                            ? "Requesting…"
                            : "Request info"}
                        </button>
                      </form>

                      <form
                        action={(fd) => {
                          reviewKindRef.current = "rejected";
                          setLocalStatus("rejected");
                          startReviewTransition(() => reviewFormAction(fd));
                        }}
                      >
                        <input type="hidden" name="reimbursementId" value={claim.id} />
                        <input type="hidden" name="status" value="rejected" />
                        <input type="hidden" name="admin_notes" value={adminNote} />
                        <button
                          type="submit"
                          disabled={anyPending}
                          className="flex items-center gap-2 px-4 py-2 rounded-lg bg-[oklch(0.45_0.090_25)] text-white text-sm font-semibold hover:bg-[oklch(0.38_0.100_25)] transition-colors disabled:opacity-50 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[oklch(0.72_0.115_82)]"
                        >
                          <XCircle size={14} />
                          {isReviewPending && reviewKindRef.current === "rejected"
                            ? "Rejecting…"
                            : "Reject"}
                        </button>
                      </form>
                    </div>
                    <p className="text-[oklch(0.62_0.012_258)] text-xs">
                      Approving notifies the member by email. A note is required to reject or request info.
                    </p>
                  </>
                )}
              </div>
            </div>
          </td>
        </tr>
      )}
    </>
  );
}

const ClaimRow = memo(ClaimRowBase);

function DetailRow({
  icon,
  label,
  value,
  multiline = false,
}: {
  icon?: React.ReactNode;
  label: string;
  value: string;
  multiline?: boolean;
}) {
  return (
    <div>
      <p className="flex items-center gap-1.5 text-[oklch(0.55_0.018_258)] text-xs font-medium uppercase tracking-wider mb-1">
        {icon}
        {label}
      </p>
      <p
        className={cn(
          "text-[oklch(0.24_0.055_258)] text-sm",
          multiline && "whitespace-pre-wrap",
        )}
      >
        {value}
      </p>
    </div>
  );
}

// ── Main table ────────────────────────────────────────────────────────────────

export function ReimbursementsTable({ claims }: { claims: AdminReimbursement[] }) {
  const [filter, setFilter] = useState<FilterKey>("all");
  const [query, setQuery] = useState("");
  const deferredQuery = useDeferredValue(query);

  const counts = useMemo(
    () => ({
      all: claims.length,
      to_review: claims.filter((c) => OPEN_STATUSES.includes(c.status)).length,
      approved: claims.filter((c) => c.status === "approved").length,
      paid: claims.filter((c) => c.status === "paid").length,
      rejected: claims.filter((c) => c.status === "rejected").length,
    }),
    [claims],
  );

  const filtered = useMemo(
    () =>
      claims.filter((c) => {
        if (!matchesFilter(c.status, filter)) return false;
        if (!deferredQuery.trim()) return true;
        const q = deferredQuery.toLowerCase();
        return (
          c.member.first_name.toLowerCase().includes(q) ||
          c.member.last_name.toLowerCase().includes(q) ||
          (c.member.email ?? "").toLowerCase().includes(q) ||
          c.pet.name.toLowerCase().includes(q) ||
          c.provider_name.toLowerCase().includes(q) ||
          c.service_type.name.toLowerCase().includes(q)
        );
      }),
    [claims, filter, deferredQuery],
  );

  const FILTERS: { key: FilterKey; label: string }[] = [
    { key: "all", label: "All" },
    { key: "to_review", label: "To review" },
    { key: "approved", label: "Approved" },
    { key: "paid", label: "Paid" },
    { key: "rejected", label: "Rejected" },
  ];

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
              attention={key === "to_review" && counts[key] > 0}
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
            placeholder="Search member, pet, provider..."
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
              <Receipt size={16} className="text-[oklch(0.72_0.010_258)]" />
            </div>
            <div>
              <p className="text-[oklch(0.48_0.02_258)] text-sm font-medium">
                {claims.length === 0 ? "No reimbursement claims yet" : "No results found"}
              </p>
              <p className="text-[oklch(0.72_0.010_258)] text-sm mt-1">
                {claims.length === 0
                  ? "Member receipt claims will appear here once submitted."
                  : "Try adjusting your search or filter."}
              </p>
            </div>
          </div>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full text-left">
              <thead>
                <tr className="border-b border-[oklch(0.89_0.014_258)] bg-[oklch(0.94_0.013_258)]">
                  <th className="px-4 py-3 text-[oklch(0.40_0.025_258)] text-xs font-semibold uppercase tracking-wider">
                    Member
                  </th>
                  <th className="px-4 py-3 text-[oklch(0.40_0.025_258)] text-xs font-semibold uppercase tracking-wider">
                    Service
                  </th>
                  <th className="px-4 py-3 text-[oklch(0.40_0.025_258)] text-xs font-semibold uppercase tracking-wider">
                    Amount
                  </th>
                  <th className="px-4 py-3 text-[oklch(0.40_0.025_258)] text-xs font-semibold uppercase tracking-wider">
                    Status
                  </th>
                  <th className="px-4 py-3 text-[oklch(0.40_0.025_258)] text-xs font-semibold uppercase tracking-wider">
                    Submitted
                  </th>
                  <th className="px-4 py-3 w-32" />
                </tr>
              </thead>
              <tbody>
                {filtered.map((claim) => (
                  <ClaimRow key={claim.id} claim={claim} />
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>

      {filtered.length > 0 && (
        <p className="text-[oklch(0.62_0.012_258)] text-xs text-right tabular-nums">
          Showing {filtered.length} of {claims.length} claims
        </p>
      )}
    </div>
  );
}
