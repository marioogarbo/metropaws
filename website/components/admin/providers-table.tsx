"use client";

import { useActionState, useId, useState, useTransition, useRef, useEffect } from "react";
import { createPortal } from "react-dom";
import { useRouter } from "next/navigation";
import { Plus, Trash2, Banknote, X, AlertTriangle, Pencil } from "lucide-react";
import { cn } from "@/lib/utils";
import {
  createProviderAction,
  updateProviderAction,
  deleteProviderAction,
  toggleProviderActiveAction,
  type ActionState,
} from "@/app/admin/(protected)/providers/actions";
import type { ReimbursementProvider } from "@/app/admin/(protected)/providers/page";

// ── Helpers ───────────────────────────────────────────────────────────────────

function ProviderInitials({ name }: { name: string }) {
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

function payoutText(provider: ReimbursementProvider): string {
  if (!provider.payout_method) return "Not on file";
  const method = provider.payout_method.toLowerCase();
  if (method === "cash") return "Cash";
  const label = method === "gcash" ? "GCash" : provider.payout_bank_name || "Bank";
  return provider.payout_account_number
    ? `${label} · ${provider.payout_account_number}`
    : label;
}

// ── Dialog primitives (colocated, matches clinics-table.tsx's convention) ──────

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
  const onCloseRef = useRef(onClose);
  onCloseRef.current = onClose;

  useEffect(() => {
    const el = ref.current;
    if (!el) return;
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
  }, []);

  return (
    <div
      ref={ref}
      role="dialog"
      aria-modal="true"
      aria-labelledby={titleId}
      className="bg-[oklch(0.99_0.005_80)] rounded-xl shadow-xl border border-[oklch(0.88_0.010_258)] overflow-hidden max-h-[90vh] overflow-y-auto"
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

// Payout method select + conditional account fields, shared by Add/Edit dialogs.
function PayoutFields({ provider }: { provider?: ReimbursementProvider }) {
  const [method, setMethod] = useState(provider?.payout_method ?? "");
  const methodId = useId();

  return (
    <div className="space-y-3 rounded-lg border border-[oklch(0.90_0.010_258)] p-3">
      <p className="text-[oklch(0.48_0.02_258)] text-xs font-medium">
        Payout details (where MetroPaws sends money for approved claims)
      </p>
      <div>
        <label
          htmlFor={methodId}
          className="block text-[oklch(0.48_0.02_258)] text-xs font-medium mb-1"
        >
          Payout method
        </label>
        <select
          id={methodId}
          name="payout_method"
          value={method}
          onChange={(e) => setMethod(e.target.value)}
          className={cn(
            "w-full bg-[oklch(0.97_0.01_80)] border border-[oklch(0.88_0.010_258)] rounded-lg px-3 py-2",
            "text-[oklch(0.24_0.055_258)]",
            "focus:outline-none focus:ring-2 focus:ring-[oklch(0.72_0.115_82)] focus:border-transparent",
          )}
          style={{ fontSize: "13px" }}
        >
          <option value="">Not set</option>
          <option value="gcash">GCash</option>
          <option value="bank">Bank transfer</option>
          <option value="cash">Cash</option>
        </select>
      </div>

      {method === "bank" && (
        <Field
          label="Bank name"
          name="payout_bank_name"
          placeholder="e.g. BDO"
          maxLength={60}
          defaultValue={provider?.payout_bank_name ?? ""}
        />
      )}

      {(method === "gcash" || method === "bank") && (
        <>
          <Field
            label="Account name"
            name="payout_account_name"
            placeholder="Name on the account"
            maxLength={100}
            defaultValue={provider?.payout_account_name ?? ""}
          />
          <Field
            label={method === "gcash" ? "GCash number" : "Account number"}
            name="payout_account_number"
            placeholder={method === "gcash" ? "09xxxxxxxxx" : "Account number"}
            maxLength={40}
            defaultValue={provider?.payout_account_number ?? ""}
          />
        </>
      )}
    </div>
  );
}

// ── Add Provider Dialog ──────────────────────────────────────────────────────

function AddProviderDialog({
  onClose,
  onSuccess,
}: {
  onClose: () => void;
  onSuccess: () => void;
}) {
  const addressId = useId();
  const initialState: ActionState = { error: null };
  const [state, formAction, pending] = useActionState(createProviderAction, initialState);
  const prevPending = useRef(false);

  useEffect(() => {
    if (prevPending.current && !pending && !state.error) {
      onSuccess();
    }
    prevPending.current = pending;
  }, [pending, state.error, onSuccess]);

  return (
    <Overlay onClose={onClose}>
      <DialogShell title="Add provider" onClose={onClose}>
        <form action={formAction} className="space-y-4">
          <Field
            label="Provider name"
            name="name"
            placeholder="e.g. Happy Paws Grooming"
            required
            autoFocus
            maxLength={100}
          />
          <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
            <Field
              label="Category"
              name="category"
              placeholder="e.g. Grooming Salon"
              maxLength={60}
            />
            <Field
              label="Phone"
              name="phone"
              placeholder="+63 2 8888 0000"
              maxLength={30}
            />
          </div>
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

          <PayoutFields />

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
              {pending ? "Creating…" : "Add provider"}
            </button>
          </div>
        </form>
      </DialogShell>
    </Overlay>
  );
}

// ── Edit Provider Dialog ─────────────────────────────────────────────────────

function EditProviderDialog({
  provider,
  onClose,
  onSuccess,
}: {
  provider: ReimbursementProvider;
  onClose: () => void;
  onSuccess: () => void;
}) {
  const addressId = useId();
  const boundAction = updateProviderAction.bind(null, provider.id);
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
      <DialogShell title="Edit provider" onClose={onClose}>
        <form action={formAction} className="space-y-4">
          <Field
            label="Provider name"
            name="name"
            required
            autoFocus
            maxLength={100}
            defaultValue={provider.name}
          />
          <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
            <Field
              label="Category"
              name="category"
              placeholder="e.g. Grooming Salon"
              maxLength={60}
              defaultValue={provider.category ?? ""}
            />
            <Field
              label="Phone"
              name="phone"
              placeholder="+63 2 8888 0000"
              maxLength={30}
              defaultValue={provider.phone ?? ""}
            />
          </div>
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
              maxLength={500}
              defaultValue={provider.address ?? ""}
              className={cn(
                "w-full bg-[oklch(0.97_0.01_80)] border border-[oklch(0.88_0.010_258)] rounded-lg px-3 py-2 resize-none",
                "text-[oklch(0.24_0.055_258)] placeholder:text-[oklch(0.72_0.01_258)]",
                "focus:outline-none focus:ring-2 focus:ring-[oklch(0.72_0.115_82)] focus:border-transparent",
              )}
              style={{ fontSize: "13px" }}
            />
          </div>

          <PayoutFields provider={provider} />

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

// ── Confirm Delete Dialog ─────────────────────────────────────────────────────

function ConfirmDeleteDialog({
  provider,
  error,
  onConfirm,
  onClose,
  pending,
}: {
  provider: ReimbursementProvider;
  error: string | null;
  onConfirm: () => void;
  onClose: () => void;
  pending: boolean;
}) {
  return (
    <Overlay onClose={onClose}>
      <DialogShell title="Delete provider" onClose={onClose}>
        <p className="text-[oklch(0.48_0.02_258)] mb-2" style={{ fontSize: "13px" }}>
          Remove{" "}
          <strong className="text-[oklch(0.24_0.055_258)]">{provider.name}</strong>{" "}
          permanently?
        </p>
        <p className="text-[oklch(0.72_0.01_258)] text-xs mb-5">
          Only possible if this provider has no claims on file yet. If they&apos;ve
          already been paid for a claim, deactivate them instead so they drop off
          the member picker without breaking history.
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
            {pending ? "Deleting…" : "Delete provider"}
          </button>
        </div>
      </DialogShell>
    </Overlay>
  );
}

// ── Provider Row ──────────────────────────────────────────────────────────────

function ProviderRow({
  provider,
  onRefresh,
}: {
  provider: ReimbursementProvider;
  onRefresh: () => void;
}) {
  const [editOpen, setEditOpen] = useState(false);
  const [deleteOpen, setDeleteOpen] = useState(false);
  const [deleting, startDelete] = useTransition();
  const [deleteError, setDeleteError] = useState<string | null>(null);
  const [toggling, startToggle] = useTransition();

  function handleDelete() {
    startDelete(async () => {
      const result = await deleteProviderAction(provider.id);
      if (result.error) {
        setDeleteError(result.error);
      } else {
        setDeleteOpen(false);
        onRefresh();
      }
    });
  }

  function handleToggleActive() {
    startToggle(async () => {
      await toggleProviderActiveAction(provider.id, !provider.is_active);
      onRefresh();
    });
  }

  return (
    <>
      <tr className="border-t border-[oklch(0.92_0.010_258)] hover:bg-[oklch(0.98_0.006_80)] transition-colors group">
        <td className="px-4 py-3.5">
          <div className="flex items-center gap-3 overflow-hidden">
            <ProviderInitials name={provider.name} />
            <div className="min-w-0">
              <p
                className="text-[oklch(0.24_0.055_258)] font-medium truncate"
                style={{ fontSize: "13px" }}
              >
                {provider.name}
              </p>
              <p className="text-[oklch(0.72_0.01_258)] text-xs mt-0.5 truncate">
                {provider.category ?? "—"}
              </p>
            </div>
          </div>
        </td>

        <td className="px-4 py-3.5">
          <span className="text-[oklch(0.48_0.02_258)] text-xs">
            {provider.phone ?? "—"}
          </span>
        </td>

        <td className="px-4 py-3.5">
          <span className="text-[oklch(0.48_0.02_258)] text-xs block truncate">
            {payoutText(provider)}
          </span>
        </td>

        <td className="px-4 py-3.5">
          <button
            type="button"
            onClick={handleToggleActive}
            disabled={toggling}
            role="switch"
            aria-checked={provider.is_active}
            aria-label={provider.is_active ? "Active — tap to deactivate" : "Inactive — tap to activate"}
            className={cn(
              "relative inline-flex h-6 w-10 shrink-0 items-center rounded-full",
              "transition-colors duration-200 motion-reduce:transition-none disabled:opacity-40",
              provider.is_active ? "bg-[oklch(0.72_0.115_82)]" : "bg-[oklch(0.85_0.012_258)]",
            )}
          >
            <span
              className={cn(
                "pointer-events-none block h-4 w-4 rounded-full bg-[oklch(0.99_0.005_80)] shadow-sm",
                "transition-transform duration-200 motion-reduce:transition-none",
                provider.is_active ? "translate-x-5" : "translate-x-1",
              )}
            />
          </button>
        </td>

        <td className="px-3 py-3.5">
          <div className="flex items-center gap-1 justify-end">
            <button
              type="button"
              onClick={() => setEditOpen(true)}
              title={`Edit ${provider.name}`}
              className="p-2 rounded text-[oklch(0.72_0.01_258)] hover:text-[oklch(0.24_0.055_258)] hover:bg-[oklch(0.94_0.015_75)] focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[oklch(0.72_0.115_82)] transition-colors motion-reduce:transition-none md:opacity-0 md:group-hover:opacity-100"
            >
              <Pencil size={14} aria-hidden="true" />
              <span className="sr-only">Edit {provider.name}</span>
            </button>
            <button
              type="button"
              onClick={() => {
                setDeleteError(null);
                setDeleteOpen(true);
              }}
              title={`Delete ${provider.name}`}
              className="p-2 rounded text-[oklch(0.72_0.01_258)] hover:text-red-500 hover:bg-red-50 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[oklch(0.72_0.115_82)] transition-colors motion-reduce:transition-none md:opacity-0 md:group-hover:opacity-100"
            >
              <Trash2 size={14} aria-hidden="true" />
              <span className="sr-only">Delete {provider.name}</span>
            </button>
          </div>
        </td>
      </tr>

      {editOpen && (
        <EditProviderDialog
          provider={provider}
          onClose={() => setEditOpen(false)}
          onSuccess={() => {
            setEditOpen(false);
            onRefresh();
          }}
        />
      )}

      {deleteOpen && (
        <ConfirmDeleteDialog
          provider={provider}
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

// ── ProvidersTable ────────────────────────────────────────────────────────────

export function ProvidersTable({
  providers,
  fetchError,
}: {
  providers: ReimbursementProvider[];
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
      <div className="mb-6 md:mb-8 flex items-end justify-between gap-4">
        <div>
          <p className="text-[oklch(0.72_0.115_82)] text-xs font-semibold tracking-widest uppercase mb-1.5">
            Direct-to-Provider Payments
          </p>
          <div className="flex items-baseline gap-3">
            <h1 className="text-[oklch(0.24_0.055_258)] text-2xl font-semibold tracking-tight">
              Providers
            </h1>
            {!fetchError && (
              <span className="text-[oklch(0.48_0.02_258)] text-sm font-normal">
                {providers.length} on file
              </span>
            )}
          </div>
          <p className="text-[oklch(0.72_0.01_258)] text-xs mt-1.5 max-w-lg">
            Verified clinics/groomers members can ask MetroPaws to pay directly for
            scheduled, non-emergency claims — separate from the Clinics partner
            network above.
          </p>
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
          Add provider
        </button>
      </div>

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
            Failed to load providers
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
      ) : providers.length === 0 ? (
        <div className="rounded-xl border border-[oklch(0.88_0.010_258)] bg-[oklch(0.99_0.005_80)] p-16 flex flex-col items-center justify-center text-center">
          <Banknote
            size={24}
            className="text-[oklch(0.72_0.01_258)] mb-3"
            aria-hidden="true"
          />
          <p
            className="text-[oklch(0.48_0.02_258)] font-medium"
            style={{ fontSize: "14px" }}
          >
            No providers yet
          </p>
          <p className="text-[oklch(0.72_0.01_258)] text-xs mt-1">
            Add a clinic or groomer&apos;s payout details to let members pick them.
          </p>
        </div>
      ) : (
        <>
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
                  <col className="w-[34%]" />
                  <col className="w-[16%]" />
                  <col className="w-[26%]" />
                  <col className="w-[8%]" />
                  <col className="w-[16%]" />
                </colgroup>
                <thead>
                  <tr className="bg-[oklch(0.97_0.01_80)]">
                    <th
                      scope="col"
                      className="px-4 py-3 text-left text-[oklch(0.48_0.02_258)] text-xs font-semibold tracking-wide"
                    >
                      Provider
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
                      Payout
                    </th>
                    <th
                      scope="col"
                      className="px-4 py-3 text-left text-[oklch(0.48_0.02_258)] text-xs font-semibold tracking-wide"
                    >
                      Active
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
                  {providers.map((provider) => (
                    <ProviderRow
                      key={provider.id}
                      provider={provider}
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
              : `${providers.length} ${providers.length === 1 ? "provider" : "providers"}`}
          </p>
        </>
      )}

      <span className="sr-only" role="status" aria-live="polite" aria-atomic="true">
        {isRefreshing ? "Refreshing provider list…" : ""}
      </span>

      {addOpen && (
        <AddProviderDialog
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
