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
  MapPin,
  Mail,
  Phone,
  MessageSquare,
  StickyNote,
  BookMarked,
  Trash2,
} from "lucide-react";
import { cn } from "@/lib/utils";
import {
  updateReservationStatusAction,
  deleteReservationAction,
  type ActionState,
} from "@/app/admin/(protected)/reservations/actions";
import type { Reservation } from "@/app/admin/(protected)/reservations/page";

// ── Status helpers ───────────────────────────────────────────────────────────

const STATUS_STYLES: Record<string, string> = {
  pending:
    "bg-[oklch(0.93_0.020_80)] text-[oklch(0.45_0.060_80)] border border-[oklch(0.88_0.030_80)]",
  approved:
    "bg-[oklch(0.93_0.040_155)] text-[oklch(0.35_0.090_155)] border border-[oklch(0.85_0.060_155)]",
  rejected:
    "bg-[oklch(0.93_0.030_25)] text-[oklch(0.40_0.090_25)] border border-[oklch(0.87_0.050_25)]",
};

const STATUS_ICONS: Record<string, React.ReactNode> = {
  pending: <Clock size={13} />,
  approved: <CheckCircle size={13} />,
  rejected: <XCircle size={13} />,
};

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
      {status}
    </span>
  );
}

function formatDate(iso: string) {
  return new Date(iso).toLocaleDateString("en-PH", {
    year: "numeric",
    month: "short",
    day: "numeric",
    hour: "2-digit",
    minute: "2-digit",
  });
}

function formatPhone(phone: string | null) {
  if (!phone) return null;
  const digits = phone.replace(/\D/g, "");
  if (digits.length === 10)
    return `+63 ${digits.slice(0, 3)} ${digits.slice(3, 7)} ${digits.slice(7)}`;
  return phone;
}

// ── Filter tabs ─────────────────────────────────────────────────────────────

type FilterKey = "all" | "pending" | "approved" | "rejected";

interface FilterTabProps {
  label: string;
  count: number;
  active: boolean;
  onClick: () => void;
}

function FilterTab({ label, count, active, onClick }: FilterTabProps) {
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
          "px-1.5 py-0.5 rounded-full text-xs font-semibold leading-none",
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

// ── Row expansion + status update ───────────────────────────────────────────

function ReservationRowBase({ reservation }: { reservation: Reservation }) {
  const [expanded, setExpanded] = useState(false);
  const [localStatus, setLocalStatus] = useState(reservation.status);
  const [adminNote, setAdminNote] = useState(reservation.admin_notes ?? "");
  const [confirmDelete, setConfirmDelete] = useState(false);

  // Quick approve/reject in the collapsed row
  const [isStatusPending, startStatusTransition] = useTransition();
  const [statusState, statusFormAction] = useActionState<ActionState, FormData>(
    updateReservationStatusAction,
    { error: null },
  );
  const pendingStatusRef = useRef<"approved" | "rejected" | null>(null);

  // Status override + notes save (for non-pending items in expanded panel)
  const [isSavePending, startSaveTransition] = useTransition();
  const [saveState, saveFormAction] = useActionState<ActionState, FormData>(
    updateReservationStatusAction,
    { error: null },
  );

  // Delete
  const [isDeleting, startDeleteTransition] = useTransition();
  const [deleteState, deleteFormAction] = useActionState<ActionState, FormData>(
    deleteReservationAction,
    { error: null },
  );

  const anyPending = isSavePending || isStatusPending || isDeleting;

  // Toast feedback — approve / reject (row quick + expanded panel)
  const prevStatusPendingRef = useRef(false);
  useEffect(() => {
    if (prevStatusPendingRef.current && !isStatusPending) {
      if (statusState.error) {
        toast.error(statusState.error);
      } else {
        const kind = pendingStatusRef.current;
        toast.success(
          kind === "approved" ? "Reservation approved" : "Reservation rejected",
        );
        pendingStatusRef.current = null;
      }
    }
    prevStatusPendingRef.current = isStatusPending;
  }, [isStatusPending, statusState]);

  // Toast feedback — save (status override)
  const prevSavePendingRef = useRef(false);
  useEffect(() => {
    if (prevSavePendingRef.current && !isSavePending) {
      if (saveState.error) toast.error(saveState.error);
      else toast.success("Changes saved");
    }
    prevSavePendingRef.current = isSavePending;
  }, [isSavePending, saveState]);

  // Toast feedback — delete
  const prevDeletePendingRef = useRef(false);
  useEffect(() => {
    if (prevDeletePendingRef.current && !isDeleting) {
      if (deleteState.error) toast.error(deleteState.error);
    }
    prevDeletePendingRef.current = isDeleting;
  }, [isDeleting, deleteState]);

  const fullName = `${reservation.first_name} ${reservation.last_name}`;
  const initials = (
    reservation.first_name[0] + reservation.last_name[0]
  ).toUpperCase();
  const detailId = `reservation-detail-${reservation.id}`;
  const isReservationPending = localStatus === "pending";

  return (
    <>
      {/* Main row */}
      <tr
        className={cn(
          "border-b border-[oklch(0.92_0.010_258)] transition-colors",
          expanded
            ? "bg-[oklch(0.96_0.010_80)]"
            : "hover:bg-[oklch(0.98_0.006_80)]",
        )}
      >
        {/* Applicant */}
        <td className="px-4 py-3.5">
          <div className="flex items-center gap-2.5">
            <div className="w-8 h-8 rounded-full bg-[oklch(0.32_0.050_258)] flex items-center justify-center shrink-0">
              <span className="text-[oklch(0.72_0.115_82)] text-xs font-bold">
                {initials}
              </span>
            </div>
            <div>
              <p className="text-[oklch(0.24_0.055_258)] text-sm font-semibold leading-none">
                {fullName}
              </p>
              <p className="text-[oklch(0.62_0.012_258)] text-xs mt-0.5">
                {reservation.barangay}
              </p>
            </div>
          </div>
        </td>

        {/* Contact */}
        <td className="px-4 py-3.5">
          <p className="text-[oklch(0.36_0.030_258)] text-sm font-medium">
            {reservation.email}
          </p>
          {reservation.phone && (
            <p className="text-[oklch(0.62_0.012_258)] text-xs mt-0.5">
              {formatPhone(reservation.phone)}
            </p>
          )}
        </td>

        {/* Status */}
        <td className="px-4 py-3.5">
          <StatusBadge status={localStatus} />
        </td>

        {/* Date */}
        <td className="px-4 py-3.5">
          <p className="text-[oklch(0.52_0.018_258)] text-sm tabular-nums">
            {formatDate(reservation.created_at)}
          </p>
        </td>

        {/* Actions — fixed width prevents layout shift between pending/non-pending rows */}
        <td className="px-4 py-3.5 w-70">
          <div className="flex items-center justify-end gap-2">
            {/* Quick approve/reject — pending + collapsed only */}
            {isReservationPending && !expanded && (
              <>
                <form
                  action={(fd) => {
                    setLocalStatus("approved");
                    pendingStatusRef.current = "approved";
                    startStatusTransition(() => statusFormAction(fd));
                  }}
                >
                  <input type="hidden" name="reservationId" value={reservation.id} />
                  <input type="hidden" name="status" value="approved" />
                  <button
                    type="submit"
                    disabled={anyPending}
                    className="inline-flex items-center gap-1 px-2.5 py-1.5 rounded-lg text-xs font-semibold border transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[oklch(0.72_0.115_82)] disabled:opacity-50 bg-[oklch(0.93_0.040_155)] text-[oklch(0.28_0.090_155)] border-[oklch(0.85_0.060_155)] hover:bg-[oklch(0.86_0.060_155)]"
                  >
                    <CheckCircle size={11} />
                    {isStatusPending && pendingStatusRef.current === "approved"
                      ? "…"
                      : "Approve"}
                  </button>
                </form>

                <form
                  action={(fd) => {
                    setLocalStatus("rejected");
                    pendingStatusRef.current = "rejected";
                    startStatusTransition(() => statusFormAction(fd));
                  }}
                >
                  <input type="hidden" name="reservationId" value={reservation.id} />
                  <input type="hidden" name="status" value="rejected" />
                  <button
                    type="submit"
                    disabled={anyPending}
                    className="inline-flex items-center gap-1 px-2.5 py-1.5 rounded-lg text-xs font-semibold border transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[oklch(0.72_0.115_82)] disabled:opacity-50 bg-[oklch(0.93_0.030_25)] text-[oklch(0.38_0.090_25)] border-[oklch(0.87_0.050_25)] hover:bg-[oklch(0.87_0.045_25)]"
                  >
                    <XCircle size={11} />
                    {isStatusPending && pendingStatusRef.current === "rejected"
                      ? "…"
                      : "Reject"}
                  </button>
                </form>
              </>
            )}

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
                <>Details <ChevronDown size={12} /></>
              )}
            </button>
          </div>
        </td>
      </tr>

      {/* Expanded detail panel */}
      {expanded && (
        <tr className="border-b border-[oklch(0.92_0.010_258)] bg-[oklch(0.96_0.010_80)]">
          <td
            colSpan={5}
            className="px-6 pt-5 pb-6 border-t border-[oklch(0.90_0.010_258)]"
          >
            <div id={detailId} className="space-y-5">
              <div className="grid grid-cols-1 md:grid-cols-2 gap-8">
                {/* Left: contact details */}
                <div className="space-y-4">
                  <DetailRow icon={<Mail size={12} />} label="Email" value={reservation.email} />
                  <DetailRow icon={<Phone size={12} />} label="Phone" value={formatPhone(reservation.phone) ?? "—"} />
                  <DetailRow icon={<MapPin size={12} />} label="Barangay" value={reservation.barangay} />
                  <DetailRow icon={<MessageSquare size={12} />} label="Message" value={reservation.message ?? "—"} multiline />
                </div>

                {/* Right: admin actions — single unified workflow */}
                <div className="space-y-4">
                  {/* Notes always visible */}
                  <div>
                    <label
                      htmlFor={`notes-${reservation.id}`}
                      className="flex items-center gap-1.5 text-[oklch(0.48_0.02_258)] text-xs font-semibold uppercase tracking-wider mb-1.5"
                    >
                      <StickyNote size={12} />
                      Admin Notes
                    </label>
                    <textarea
                      id={`notes-${reservation.id}`}
                      rows={3}
                      value={adminNote}
                      onChange={(e) => setAdminNote(e.target.value)}
                      placeholder="Optional internal notes..."
                      disabled={anyPending}
                      className="w-full text-sm border border-[oklch(0.88_0.010_258)] rounded-lg px-3 py-2 bg-[oklch(0.99_0.005_80)] text-[oklch(0.24_0.055_258)] placeholder:text-[oklch(0.72_0.010_258)] focus:outline-none focus:ring-2 focus:ring-[oklch(0.72_0.115_82)] resize-none disabled:opacity-50 disabled:cursor-not-allowed"
                    />
                  </div>

                  {isReservationPending ? (
                    /* Pending: approve or reject — both include current notes */
                    <div className="space-y-2">
                      <div className="flex gap-3">
                        <form
                          action={(fd) => {
                            setLocalStatus("approved");
                            pendingStatusRef.current = "approved";
                            startStatusTransition(() => statusFormAction(fd));
                          }}
                        >
                          <input type="hidden" name="reservationId" value={reservation.id} />
                          <input type="hidden" name="status" value="approved" />
                          <input type="hidden" name="admin_notes" value={adminNote} />
                          <button
                            type="submit"
                            disabled={anyPending}
                            className="flex items-center gap-2 px-4 py-2 rounded-lg bg-[oklch(0.35_0.090_155)] text-white text-sm font-semibold hover:bg-[oklch(0.30_0.090_155)] transition-colors disabled:opacity-50 disabled:cursor-not-allowed focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[oklch(0.72_0.115_82)]"
                          >
                            <CheckCircle size={14} />
                            {isStatusPending && pendingStatusRef.current === "approved"
                              ? "Approving…"
                              : "Approve"}
                          </button>
                        </form>

                        <form
                          action={(fd) => {
                            setLocalStatus("rejected");
                            pendingStatusRef.current = "rejected";
                            startStatusTransition(() => statusFormAction(fd));
                          }}
                        >
                          <input type="hidden" name="reservationId" value={reservation.id} />
                          <input type="hidden" name="status" value="rejected" />
                          <input type="hidden" name="admin_notes" value={adminNote} />
                          <button
                            type="submit"
                            disabled={anyPending}
                            className="flex items-center gap-2 px-4 py-2 rounded-lg bg-[oklch(0.45_0.090_25)] text-white text-sm font-semibold hover:bg-[oklch(0.38_0.100_25)] transition-colors disabled:opacity-50 disabled:cursor-not-allowed focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[oklch(0.72_0.115_82)]"
                          >
                            <XCircle size={14} />
                            {isStatusPending && pendingStatusRef.current === "rejected"
                              ? "Rejecting…"
                              : "Reject"}
                          </button>
                        </form>
                      </div>
                      {statusState.error && (
                        <p className="text-[oklch(0.40_0.090_25)] text-sm">{statusState.error}</p>
                      )}
                    </div>
                  ) : (
                    /* Non-pending: override status + save notes */
                    <form
                      action={(fd) => {
                        startSaveTransition(() => saveFormAction(fd));
                      }}
                      className="space-y-3"
                    >
                      <input type="hidden" name="reservationId" value={reservation.id} />
                      <input type="hidden" name="admin_notes" value={adminNote} />

                      <div className="relative">
                        <select
                          id={`status-${reservation.id}`}
                          name="status"
                          value={localStatus}
                          onChange={(e) =>
                            setLocalStatus(
                              e.target.value as "pending" | "approved" | "rejected",
                            )
                          }
                          disabled={isSavePending}
                          className="w-full appearance-none text-sm border border-[oklch(0.88_0.010_258)] rounded-lg px-3 py-2 pr-8 bg-[oklch(0.99_0.005_80)] text-[oklch(0.24_0.055_258)] focus:outline-none focus:ring-2 focus:ring-[oklch(0.72_0.115_82)] cursor-pointer disabled:opacity-50 disabled:cursor-not-allowed"
                        >
                          <option value="pending">Pending</option>
                          <option value="approved">Approved</option>
                          <option value="rejected">Rejected</option>
                        </select>
                        <ChevronDown
                          size={12}
                          className="absolute right-2.5 top-1/2 -translate-y-1/2 text-[oklch(0.72_0.010_258)] pointer-events-none"
                        />
                      </div>

                      {saveState.error && (
                        <p className="text-[oklch(0.40_0.090_25)] text-sm">{saveState.error}</p>
                      )}

                      <button
                        type="submit"
                        disabled={isSavePending}
                        className="px-4 py-2 rounded-lg bg-[oklch(0.24_0.055_258)] text-white text-sm font-semibold hover:bg-[oklch(0.30_0.052_258)] transition-colors disabled:opacity-50 disabled:cursor-not-allowed focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[oklch(0.72_0.115_82)]"
                      >
                        {isSavePending ? "Saving…" : "Save changes"}
                      </button>
                    </form>
                  )}
                </div>
              </div>

              {/* Delete zone */}
              <div className="pt-4 border-t border-[oklch(0.90_0.010_258)]">
                {!confirmDelete ? (
                  <button
                    type="button"
                    onClick={() => setConfirmDelete(true)}
                    className="flex items-center gap-1.5 text-[oklch(0.55_0.070_25)] hover:text-[oklch(0.40_0.090_25)] text-sm font-medium transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[oklch(0.72_0.115_82)] rounded"
                  >
                    <Trash2 size={13} />
                    Delete reservation
                  </button>
                ) : (
                  <form
                    action={(fd) => {
                      startDeleteTransition(() => deleteFormAction(fd));
                    }}
                    className="flex flex-col gap-2"
                  >
                    <input type="hidden" name="reservationId" value={reservation.id} />
                    <p className="text-[oklch(0.40_0.090_25)] text-sm font-medium">
                      Permanently delete this reservation?
                    </p>
                    {deleteState.error && (
                      <p className="text-[oklch(0.40_0.090_25)] text-sm">{deleteState.error}</p>
                    )}
                    <div className="flex items-center gap-2">
                      <button
                        type="submit"
                        disabled={isDeleting}
                        className="px-3 py-1.5 rounded-lg bg-[oklch(0.40_0.090_25)] text-white text-sm font-semibold hover:bg-[oklch(0.35_0.100_25)] transition-colors disabled:opacity-50 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[oklch(0.72_0.115_82)]"
                      >
                        {isDeleting ? "Deleting…" : "Yes, delete"}
                      </button>
                      <button
                        type="button"
                        onClick={() => setConfirmDelete(false)}
                        disabled={isDeleting}
                        className="px-3 py-1.5 rounded-lg border border-[oklch(0.88_0.010_258)] text-[oklch(0.48_0.02_258)] text-sm font-medium hover:bg-[oklch(0.96_0.008_80)] transition-colors disabled:opacity-50 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[oklch(0.72_0.115_82)]"
                      >
                        Cancel
                      </button>
                    </div>
                  </form>
                )}
              </div>
            </div>
          </td>
        </tr>
      )}
    </>
  );
}

const ReservationRow = memo(ReservationRowBase);

function DetailRow({
  icon,
  label,
  value,
  multiline = false,
}: {
  icon: React.ReactNode;
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

// ── Main table component ─────────────────────────────────────────────────────

export function ReservationsTable({
  reservations,
}: {
  reservations: Reservation[];
}) {
  const [filter, setFilter] = useState<FilterKey>("all");
  const [query, setQuery] = useState("");
  const deferredQuery = useDeferredValue(query);

  const counts = useMemo(
    () => ({
      all: reservations.length,
      pending: reservations.filter((r) => r.status === "pending").length,
      approved: reservations.filter((r) => r.status === "approved").length,
      rejected: reservations.filter((r) => r.status === "rejected").length,
    }),
    [reservations],
  );

  const filtered = useMemo(
    () =>
      reservations.filter((r) => {
        const matchesFilter = filter === "all" || r.status === filter;
        if (!deferredQuery.trim()) return matchesFilter;

        const q = deferredQuery.toLowerCase();
        const matchesSearch =
          r.first_name.toLowerCase().includes(q) ||
          r.last_name.toLowerCase().includes(q) ||
          r.email.toLowerCase().includes(q) ||
          r.barangay.toLowerCase().includes(q) ||
          (r.phone ?? "").includes(q);

        return matchesFilter && matchesSearch;
      }),
    [reservations, filter, deferredQuery],
  );

  return (
    <div className="space-y-4">
      {/* Toolbar */}
      <div className="flex flex-col sm:flex-row gap-3 sm:items-center sm:justify-between">
        <div className="flex gap-1 flex-wrap">
          {(["all", "pending", "approved", "rejected"] as FilterKey[]).map(
            (key) => (
              <FilterTab
                key={key}
                label={key === "all" ? "All" : key.charAt(0).toUpperCase() + key.slice(1)}
                count={counts[key]}
                active={filter === key}
                onClick={() => setFilter(key)}
              />
            ),
          )}
        </div>

        <div className="relative max-w-xs w-full sm:w-64">
          <Search
            size={13}
            className="absolute left-3 top-1/2 -translate-y-1/2 text-[oklch(0.72_0.010_258)] pointer-events-none"
          />
          <input
            type="search"
            placeholder="Search name, email, barangay..."
            value={query}
            onChange={(e) => setQuery(e.target.value)}
            className="w-full pl-8 pr-3 py-2 text-sm border border-[oklch(0.88_0.010_258)] rounded-lg bg-[oklch(0.99_0.005_80)] text-[oklch(0.24_0.055_258)] placeholder:text-[oklch(0.72_0.010_258)] focus:outline-none focus:ring-2 focus:ring-[oklch(0.72_0.115_82)]"
          />
        </div>
      </div>

      {/* Table */}
      <div className="rounded-xl border border-[oklch(0.88_0.010_258)] overflow-hidden bg-[oklch(0.99_0.005_80)]">
        {filtered.length === 0 ? (
          <div className="py-16 text-center flex flex-col items-center gap-3">
            <div className="w-10 h-10 rounded-full bg-[oklch(0.94_0.015_75)] flex items-center justify-center">
              <BookMarked size={16} className="text-[oklch(0.72_0.010_258)]" />
            </div>
            <div>
              <p className="text-[oklch(0.48_0.02_258)] text-sm font-medium">
                {reservations.length === 0 ? "No reservations yet" : "No results found"}
              </p>
              <p className="text-[oklch(0.72_0.010_258)] text-sm mt-1">
                {reservations.length === 0
                  ? "Founding 50 applications will appear here once submitted."
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
                    Applicant
                  </th>
                  <th className="px-4 py-3 text-[oklch(0.40_0.025_258)] text-xs font-semibold uppercase tracking-wider">
                    Contact
                  </th>
                  <th className="px-4 py-3 text-[oklch(0.40_0.025_258)] text-xs font-semibold uppercase tracking-wider">
                    Status
                  </th>
                  <th className="px-4 py-3 text-[oklch(0.40_0.025_258)] text-xs font-semibold uppercase tracking-wider">
                    Submitted
                  </th>
                  <th className="px-4 py-3 w-70" />
                </tr>
              </thead>
              <tbody>
                {filtered.map((reservation) => (
                  <ReservationRow key={reservation.id} reservation={reservation} />
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>

      {filtered.length > 0 && (
        <p className="text-[oklch(0.62_0.012_258)] text-xs text-right tabular-nums">
          Showing {filtered.length} of {reservations.length} reservations
        </p>
      )}
    </div>
  );
}
