"use client";

import { useActionState, useId, useState, useTransition, useRef, useEffect } from "react";
import { createPortal } from "react-dom";
import { useRouter } from "next/navigation";
import { Plus, Trash2, Building2, X, AlertTriangle, Pencil } from "lucide-react";
import { cn } from "@/lib/utils";
import {
  createClinicAction,
  updateClinicAction,
  deleteClinicAction,
  type ActionState,
} from "@/app/admin/(protected)/clinics/actions";
import type { ClinicPartner } from "@/app/admin/(protected)/clinics/page";

// ── Helpers ───────────────────────────────────────────────────────────────────

function ClinicInitials({ name }: { name: string }) {
  const parts = name.trim().split(/\s+/);
  const initials =
    parts.length >= 2
      ? (parts[0][0] + parts[parts.length - 1][0]).toUpperCase()
      : name.slice(0, 2).toUpperCase();
  return (
    <div className="w-8 h-8 rounded-full bg-[oklch(0.32_0.050_258)] flex items-center justify-center shrink-0">
      <span className="text-[oklch(0.72_0.115_82)] text-xs font-semibold">
        {initials}
      </span>
    </div>
  );
}

function formatDate(iso: string) {
  return new Date(iso).toLocaleDateString("en-PH", {
    year: "numeric",
    month: "short",
    day: "numeric",
  });
}

// ── Dialog primitives ─────────────────────────────────────────────────────────

function Overlay({
  onClose,
  children,
}: {
  onClose: () => void;
  children: React.ReactNode;
}) {
  useEffect(() => {
    const prev = document.body.style.overflow;
    document.body.style.overflow = "hidden";
    return () => {
      document.body.style.overflow = prev;
    };
  }, []);

  return createPortal(
    <div
      className="fixed inset-0 z-50 flex items-center justify-center p-4"
      style={{ background: "rgba(18,24,38,0.55)" }}
    >
      {/* Backdrop — click closes, not a tab stop */}
      <div className="absolute inset-0" aria-hidden="true" onClick={onClose} />
      <div className="relative z-10 w-full max-w-md">{children}</div>
    </div>,
    document.body,
  );
}

const FOCUSABLE_SELECTOR =
  'button:not([disabled]), input:not([disabled]), select:not([disabled]), textarea:not([disabled]), [tabindex]:not([tabindex="-1"])';

function DialogShell({
  title,
  onClose,
  children,
}: {
  title: string;
  onClose: () => void;
  children: React.ReactNode;
}) {
  const titleId = useId();
  const ref = useRef<HTMLDivElement>(null);

  // Stabilise onClose so the effect doesn't re-run on every render.
  const onCloseRef = useRef(onClose);
  onCloseRef.current = onClose;

  useEffect(() => {
    const el = ref.current;
    if (!el) return;

    // Save the element that had focus before the dialog opened so we can
    // restore it when it closes.
    const trigger = document.activeElement as HTMLElement | null;

    function handleKeyDown(e: KeyboardEvent) {
      if (e.key === "Escape") {
        e.preventDefault();
        onCloseRef.current();
        return;
      }
      if (e.key === "Tab") {
        const dialog = ref.current;
        if (!dialog) return;
        const focusable = Array.from(
          dialog.querySelectorAll<HTMLElement>(FOCUSABLE_SELECTOR),
        );
        if (focusable.length < 2) return;
        const first = focusable[0];
        const last = focusable[focusable.length - 1];
        if (e.shiftKey) {
          if (document.activeElement === first) {
            e.preventDefault();
            last.focus();
          }
        } else {
          if (document.activeElement === last) {
            e.preventDefault();
            first.focus();
          }
        }
      }
    }

    document.addEventListener("keydown", handleKeyDown);

    return () => {
      document.removeEventListener("keydown", handleKeyDown);
      trigger?.focus();
    };
  }, []); // eslint-disable-line react-hooks/exhaustive-deps

  return (
    <div
      ref={ref}
      role="dialog"
      aria-modal="true"
      aria-labelledby={titleId}
      className="bg-[oklch(0.99_0.005_80)] rounded-xl shadow-xl border border-[oklch(0.88_0.010_258)] overflow-hidden"
    >
      <div className="flex items-center justify-between px-6 py-4 border-b border-[oklch(0.92_0.010_258)]">
        <h2
          id={titleId}
          className="text-[oklch(0.24_0.055_258)] font-semibold"
          style={{ fontSize: "14px" }}
        >
          {title}
        </h2>
        <button
          type="button"
          onClick={onClose}
          aria-label="Close dialog"
          className="p-2 -mr-1 rounded-md text-[oklch(0.72_0.01_258)] hover:text-[oklch(0.48_0.02_258)] focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[oklch(0.72_0.115_82)] transition-colors"
        >
          <X size={16} aria-hidden="true" />
        </button>
      </div>
      <div className="px-6 py-5">{children}</div>
    </div>
  );
}

function Field({
  label,
  name,
  type = "text",
  placeholder,
  required,
  autoFocus,
  hint,
  minLength,
  maxLength,
  defaultValue,
}: {
  label: string;
  name: string;
  type?: string;
  placeholder?: string;
  required?: boolean;
  autoFocus?: boolean;
  hint?: string;
  minLength?: number;
  maxLength?: number;
  defaultValue?: string;
}) {
  const uid = useId();
  const hintId = `${uid}-hint`;
  return (
    <div>
      <label
        htmlFor={uid}
        className="block text-[oklch(0.48_0.02_258)] text-xs font-medium mb-1"
      >
        {label}
        {required && (
          <span className="text-red-500 ml-0.5" aria-hidden="true">
            *
          </span>
        )}
      </label>
      <input
        id={uid}
        name={name}
        type={type}
        placeholder={placeholder}
        required={required}
        autoFocus={autoFocus}
        minLength={minLength}
        maxLength={maxLength}
        defaultValue={defaultValue}
        aria-describedby={hint ? hintId : undefined}
        className={cn(
          "w-full bg-[oklch(0.97_0.01_80)] border border-[oklch(0.88_0.010_258)] rounded-lg px-3 py-2",
          "text-[oklch(0.24_0.055_258)] placeholder:text-[oklch(0.72_0.01_258)]",
          "focus:outline-none focus:ring-2 focus:ring-[oklch(0.72_0.115_82)] focus:border-transparent",
          "transition-colors duration-150",
        )}
        style={{ fontSize: "13px" }}
      />
      {hint && (
        <p id={hintId} className="text-[oklch(0.72_0.01_258)] text-xs mt-1">
          {hint}
        </p>
      )}
    </div>
  );
}

// ── Add Clinic Dialog ─────────────────────────────────────────────────────────

function AddClinicDialog({
  onClose,
  onSuccess,
}: {
  onClose: () => void;
  onSuccess: () => void;
}) {
  const addressId = useId();
  const initialState: ActionState = { error: null };
  const [state, formAction, pending] = useActionState(createClinicAction, initialState);
  const prevPending = useRef(false);

  useEffect(() => {
    if (prevPending.current && !pending && !state.error) {
      onSuccess();
    }
    prevPending.current = pending;
  }, [pending, state.error, onSuccess]);

  return (
    <Overlay onClose={onClose}>
      <DialogShell title="Add clinic partner" onClose={onClose}>
        <form action={formAction} className="space-y-4">
          <Field
            label="Clinic name"
            name="clinic_name"
            placeholder="e.g. MetroPaws BGC"
            required
            autoFocus
            maxLength={100}
          />
          <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
            <Field
              label="Email"
              name="email"
              type="email"
              placeholder="clinic@metropaws.ph"
              required
              maxLength={100}
            />
            <Field
              label="Password"
              name="password"
              type="password"
              placeholder="Min. 8 characters"
              required
              minLength={8}
              hint="At least 8 characters"
            />
          </div>
          <Field
            label="Phone"
            name="phone"
            placeholder="+63 2 8888 0000"
            maxLength={30}
          />
          <div>
            <label
              htmlFor={addressId}
              className="block text-[oklch(0.48_0.02_258)] text-xs font-medium mb-1"
            >
              Address
            </label>
            <textarea
              id={addressId}
              name="address"
              rows={2}
              placeholder="Street, City"
              maxLength={500}
              className={cn(
                "w-full bg-[oklch(0.97_0.01_80)] border border-[oklch(0.88_0.010_258)] rounded-lg px-3 py-2 resize-none",
                "text-[oklch(0.24_0.055_258)] placeholder:text-[oklch(0.72_0.01_258)]",
                "focus:outline-none focus:ring-2 focus:ring-[oklch(0.72_0.115_82)] focus:border-transparent",
              )}
              style={{ fontSize: "13px" }}
            />
          </div>

          {state.error && (
            <p role="alert" className="text-red-600 text-xs">
              {state.error}
            </p>
          )}

          <div className="flex gap-2 pt-1">
            <button
              type="button"
              onClick={onClose}
              className="flex-1 py-3 sm:py-2 rounded-lg border border-[oklch(0.88_0.010_258)] text-[oklch(0.48_0.02_258)] text-xs font-medium hover:bg-[oklch(0.94_0.015_75)] transition-colors"
            >
              Cancel
            </button>
            <button
              type="submit"
              disabled={pending}
              className="flex-1 py-3 sm:py-2 rounded-lg bg-[oklch(0.24_0.055_258)] text-[oklch(0.72_0.115_82)] text-xs font-semibold hover:bg-[oklch(0.32_0.050_258)] disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
            >
              {pending ? "Creating…" : "Add clinic"}
            </button>
          </div>
        </form>
      </DialogShell>
    </Overlay>
  );
}

// ── Confirm Delete Dialog ─────────────────────────────────────────────────────

function ConfirmDeleteDialog({
  clinic,
  error,
  onConfirm,
  onClose,
  pending,
}: {
  clinic: ClinicPartner;
  error: string | null;
  onConfirm: () => void;
  onClose: () => void;
  pending: boolean;
}) {
  return (
    <Overlay onClose={onClose}>
      <DialogShell title="Delete clinic" onClose={onClose}>
        <p className="text-[oklch(0.48_0.02_258)] mb-2" style={{ fontSize: "13px" }}>
          Remove{" "}
          <strong className="text-[oklch(0.24_0.055_258)]">{clinic.clinic_name}</strong>{" "}
          permanently?
        </p>
        <p className="text-[oklch(0.72_0.01_258)] text-xs mb-5">
          This deletes both the clinic record and its login account (
          <span className="inline-block max-w-[18rem] truncate align-bottom">
            {clinic.email ?? "no email"}
          </span>
          ). This cannot be undone.
        </p>

        {error && (
          <p role="alert" className="text-red-600 text-xs mb-4">
            {error}
          </p>
        )}

        <div className="flex gap-2">
          <button
            type="button"
            onClick={onClose}
            disabled={pending}
            autoFocus
            className="flex-1 py-3 sm:py-2 rounded-lg border border-[oklch(0.88_0.010_258)] text-[oklch(0.48_0.02_258)] text-xs font-medium hover:bg-[oklch(0.94_0.015_75)] disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
          >
            Cancel
          </button>
          <button
            type="button"
            onClick={onConfirm}
            disabled={pending}
            className="flex-1 py-3 sm:py-2 rounded-lg bg-red-600 text-white text-xs font-semibold hover:bg-red-700 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
          >
            {pending ? "Deleting…" : "Delete clinic"}
          </button>
        </div>
      </DialogShell>
    </Overlay>
  );
}

// ── Edit Clinic Dialog ────────────────────────────────────────────────────────

function EditClinicDialog({
  clinic,
  onClose,
  onSuccess,
}: {
  clinic: ClinicPartner;
  onClose: () => void;
  onSuccess: () => void;
}) {
  const addressId = useId();
  const boundAction = updateClinicAction.bind(null, clinic.id);
  const initialState: ActionState = { error: null };
  const [state, formAction, pending] = useActionState(boundAction, initialState);
  const prevPending = useRef(false);

  useEffect(() => {
    if (prevPending.current && !pending && !state.error) {
      onSuccess();
    }
    prevPending.current = pending;
  }, [pending, state.error, onSuccess]);

  return (
    <Overlay onClose={onClose}>
      <DialogShell title="Edit clinic" onClose={onClose}>
        <form action={formAction} className="space-y-4">
          <Field
            label="Clinic name"
            name="clinic_name"
            placeholder="e.g. MetroPaws BGC"
            required
            autoFocus
            maxLength={100}
            defaultValue={clinic.clinic_name}
          />
          <Field
            label="Phone"
            name="phone"
            placeholder="+63 2 8888 0000"
            maxLength={30}
            defaultValue={clinic.phone ?? ""}
          />
          <div>
            <label
              htmlFor={addressId}
              className="block text-[oklch(0.48_0.02_258)] text-xs font-medium mb-1"
            >
              Address
            </label>
            <textarea
              id={addressId}
              name="address"
              rows={2}
              placeholder="Street, City"
              maxLength={500}
              defaultValue={clinic.address ?? ""}
              className={cn(
                "w-full bg-[oklch(0.97_0.01_80)] border border-[oklch(0.88_0.010_258)] rounded-lg px-3 py-2 resize-none",
                "text-[oklch(0.24_0.055_258)] placeholder:text-[oklch(0.72_0.01_258)]",
                "focus:outline-none focus:ring-2 focus:ring-[oklch(0.72_0.115_82)] focus:border-transparent",
              )}
              style={{ fontSize: "13px" }}
            />
          </div>

          {state.error && (
            <p role="alert" className="text-red-600 text-xs">
              {state.error}
            </p>
          )}

          <div className="flex gap-2 pt-1">
            <button
              type="button"
              onClick={onClose}
              className="flex-1 py-3 sm:py-2 rounded-lg border border-[oklch(0.88_0.010_258)] text-[oklch(0.48_0.02_258)] text-xs font-medium hover:bg-[oklch(0.94_0.015_75)] transition-colors"
            >
              Cancel
            </button>
            <button
              type="submit"
              disabled={pending}
              className="flex-1 py-3 sm:py-2 rounded-lg bg-[oklch(0.24_0.055_258)] text-[oklch(0.72_0.115_82)] text-xs font-semibold hover:bg-[oklch(0.32_0.050_258)] disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
            >
              {pending ? "Saving…" : "Save changes"}
            </button>
          </div>
        </form>
      </DialogShell>
    </Overlay>
  );
}

// ── Clinic Row ────────────────────────────────────────────────────────────────

function ClinicRow({
  clinic,
  onRefresh,
}: {
  clinic: ClinicPartner;
  onRefresh: () => void;
}) {
  const [editOpen, setEditOpen] = useState(false);
  const [deleteOpen, setDeleteOpen] = useState(false);
  const [deleting, startDelete] = useTransition();
  const [deleteError, setDeleteError] = useState<string | null>(null);

  function handleDelete() {
    startDelete(async () => {
      const result = await deleteClinicAction(clinic.id);
      if (result.error) {
        setDeleteError(result.error);
      } else {
        setDeleteOpen(false);
        onRefresh();
      }
    });
  }

  return (
    <>
      <tr className="border-t border-[oklch(0.92_0.010_258)] hover:bg-[oklch(0.98_0.006_80)] transition-colors group">
        <td className="px-4 py-3.5">
          <div className="flex items-center gap-3 overflow-hidden">
            <ClinicInitials name={clinic.clinic_name} />
            <div className="min-w-0">
              <p
                className="text-[oklch(0.24_0.055_258)] font-medium truncate"
                style={{ fontSize: "13px" }}
              >
                {clinic.clinic_name}
              </p>
              <p className="text-[oklch(0.72_0.01_258)] text-xs mt-0.5 truncate">
                {clinic.email ?? "—"}
              </p>
            </div>
          </div>
        </td>

        <td className="px-4 py-3.5">
          <span className="text-[oklch(0.48_0.02_258)] text-xs">
            {clinic.phone ?? "—"}
          </span>
        </td>

        <td className="px-4 py-3.5">
          <span
            className="text-[oklch(0.48_0.02_258)] text-xs block truncate"
            title={clinic.address ?? undefined}
          >
            {clinic.address ?? "—"}
          </span>
        </td>

        <td className="px-4 py-3.5">
          <span className="text-[oklch(0.72_0.01_258)] text-xs">
            {formatDate(clinic.created_at)}
          </span>
        </td>

        <td className="px-3 py-3.5">
          <div className="flex items-center gap-1 justify-end">
            <button
              type="button"
              onClick={() => setEditOpen(true)}
              title={`Edit ${clinic.clinic_name}`}
              className="p-2 rounded text-[oklch(0.72_0.01_258)] hover:text-[oklch(0.24_0.055_258)] hover:bg-[oklch(0.94_0.015_75)] focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[oklch(0.72_0.115_82)] transition-colors motion-reduce:transition-none md:opacity-0 md:group-hover:opacity-100"
            >
              <Pencil size={14} aria-hidden="true" />
              <span className="sr-only">Edit {clinic.clinic_name}</span>
            </button>
            <button
              type="button"
              onClick={() => {
                setDeleteError(null);
                setDeleteOpen(true);
              }}
              title={`Delete ${clinic.clinic_name}`}
              className="p-2 rounded text-[oklch(0.72_0.01_258)] hover:text-red-500 hover:bg-red-50 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[oklch(0.72_0.115_82)] transition-colors motion-reduce:transition-none md:opacity-0 md:group-hover:opacity-100"
            >
              <Trash2 size={14} aria-hidden="true" />
              <span className="sr-only">Delete {clinic.clinic_name}</span>
            </button>
          </div>
        </td>
      </tr>

      {editOpen && (
        <EditClinicDialog
          clinic={clinic}
          onClose={() => setEditOpen(false)}
          onSuccess={() => {
            setEditOpen(false);
            onRefresh();
          }}
        />
      )}

      {deleteOpen && (
        <ConfirmDeleteDialog
          clinic={clinic}
          error={deleteError}
          onConfirm={handleDelete}
          onClose={() => {
            setDeleteOpen(false);
            setDeleteError(null);
          }}
          pending={deleting}
        />
      )}
    </>
  );
}

// ── ClinicsTable ──────────────────────────────────────────────────────────────

export function ClinicsTable({
  clinics,
  fetchError,
}: {
  clinics: ClinicPartner[];
  fetchError: boolean;
}) {
  const router = useRouter();
  const [addOpen, setAddOpen] = useState(false);
  const [isRefreshing, startRefresh] = useTransition();

  function handleRefresh() {
    startRefresh(() => {
      router.refresh();
    });
  }

  return (
    <div>
      {/* Page header: eyebrow, title, count, and Add button in one row */}
      <div className="mb-6 md:mb-8 flex items-end justify-between gap-4">
        <div>
          <p className="text-[oklch(0.72_0.115_82)] text-xs font-semibold tracking-widest uppercase mb-1.5">
            Partner Network
          </p>
          <div className="flex items-baseline gap-3">
            <h1 className="text-[oklch(0.24_0.055_258)] text-2xl font-semibold tracking-tight">
              Clinics
            </h1>
            {!fetchError && (
              <span className="text-[oklch(0.48_0.02_258)] text-sm font-normal">
                {clinics.length} registered
              </span>
            )}
          </div>
        </div>
        <button
          type="button"
          onClick={() => setAddOpen(true)}
          className={cn(
            "flex items-center gap-1.5 px-4 py-2.5 rounded-lg shrink-0",
            "bg-[oklch(0.24_0.055_258)] text-[oklch(0.72_0.115_82)] text-xs font-semibold",
            "hover:bg-[oklch(0.32_0.050_258)] transition-colors",
          )}
        >
          <Plus size={13} aria-hidden="true" />
          Add clinic
        </button>
      </div>

      {/* Content area */}
      {fetchError ? (
        <div className="rounded-xl border border-[oklch(0.88_0.010_258)] bg-[oklch(0.99_0.005_80)] p-16 flex flex-col items-center justify-center text-center">
          <AlertTriangle
            size={24}
            className="text-[oklch(0.72_0.01_258)] mb-3"
            aria-hidden="true"
          />
          <p
            className="text-[oklch(0.48_0.02_258)] font-medium"
            style={{ fontSize: "14px" }}
          >
            Failed to load clinics
          </p>
          <p className="text-[oklch(0.72_0.01_258)] text-xs mt-1 mb-4">
            Could not reach the server. Check your connection and try again.
          </p>
          <button
            type="button"
            onClick={handleRefresh}
            disabled={isRefreshing}
            className="text-[oklch(0.48_0.02_258)] text-xs underline underline-offset-2 hover:text-[oklch(0.24_0.055_258)] disabled:opacity-50 transition-colors"
          >
            {isRefreshing ? "Refreshing…" : "Retry"}
          </button>
        </div>
      ) : clinics.length === 0 ? (
        <div className="rounded-xl border border-[oklch(0.88_0.010_258)] bg-[oklch(0.99_0.005_80)] p-16 flex flex-col items-center justify-center text-center">
          <Building2
            size={24}
            className="text-[oklch(0.72_0.01_258)] mb-3"
            aria-hidden="true"
          />
          <p
            className="text-[oklch(0.48_0.02_258)] font-medium"
            style={{ fontSize: "14px" }}
          >
            No clinics yet
          </p>
          <p className="text-[oklch(0.72_0.01_258)] text-xs mt-1">
            Partner clinics will appear here once added.
          </p>
        </div>
      ) : (
        <>
          {/* Edge-to-edge scroll on mobile; md resets to normal flow. */}
          <div className="-mx-6 overflow-x-auto px-6 md:mx-0 md:px-0">
            <div
              className={cn(
                "rounded-xl border border-[oklch(0.88_0.010_258)] bg-[oklch(0.99_0.005_80)] overflow-hidden",
                "transition-opacity duration-150 motion-reduce:transition-none",
                isRefreshing && "opacity-60 pointer-events-none",
              )}
              aria-busy={isRefreshing}
            >
              <table className="w-full min-w-135 table-fixed">
                <colgroup>
                  <col className="w-[30%]" />
                  <col className="w-[12%]" />
                  <col className="w-[27%]" />
                  <col className="w-[15%]" />
                  <col className="w-[16%]" />
                </colgroup>
                <thead>
                  <tr className="bg-[oklch(0.97_0.01_80)]">
                    <th
                      scope="col"
                      className="px-4 py-3 text-left text-[oklch(0.48_0.02_258)] text-xs font-semibold tracking-wide"
                    >
                      Clinic
                    </th>
                    <th
                      scope="col"
                      className="px-4 py-3 text-left text-[oklch(0.48_0.02_258)] text-xs font-semibold tracking-wide"
                    >
                      Phone
                    </th>
                    <th
                      scope="col"
                      className="px-4 py-3 text-left text-[oklch(0.48_0.02_258)] text-xs font-semibold tracking-wide"
                    >
                      Address
                    </th>
                    <th
                      scope="col"
                      className="px-4 py-3 text-left text-[oklch(0.48_0.02_258)] text-xs font-semibold tracking-wide"
                    >
                      Added
                    </th>
                    <th
                      scope="col"
                      className="px-4 py-3 text-right text-[oklch(0.48_0.02_258)] text-xs font-semibold tracking-wide"
                    >
                      <span className="sr-only">Actions</span>
                    </th>
                  </tr>
                </thead>
                <tbody>
                  {clinics.map((clinic) => (
                    <ClinicRow
                      key={clinic.id}
                      clinic={clinic}
                      onRefresh={handleRefresh}
                    />
                  ))}
                </tbody>
              </table>
            </div>
          </div>

          <p className="mt-3 text-[oklch(0.72_0.01_258)] text-xs">
            {isRefreshing
              ? "Refreshing…"
              : `${clinics.length} ${clinics.length === 1 ? "clinic" : "clinics"}`}
          </p>
        </>
      )}

      <span className="sr-only" role="status" aria-live="polite" aria-atomic="true">
        {isRefreshing ? "Refreshing clinic list…" : ""}
      </span>

      {addOpen && (
        <AddClinicDialog
          onClose={() => setAddOpen(false)}
          onSuccess={() => {
            setAddOpen(false);
            handleRefresh();
          }}
        />
      )}
    </div>
  );
}
