"use client";

import {
  useActionState,
  useEffect,
  useId,
  useRef,
  useState,
  useTransition,
} from "react";
import { createPortal } from "react-dom";
import { useRouter } from "next/navigation";
import {
  AlertTriangle,
  ExternalLink,
  MapPin,
  Pencil,
  Plus,
  Trash2,
  X,
} from "lucide-react";
import { cn } from "@/lib/utils";
import {
  SERVICE_LABELS,
  SERVICE_SLUGS,
  serviceLine,
  type ServiceSlug,
} from "@/lib/directory-taxonomy";
import type { DirectoryProvider } from "@/types/directory";
import {
  createDirectoryProviderAction,
  deleteDirectoryProviderAction,
  toggleDirectoryPublishedAction,
  updateDirectoryProviderAction,
  type ActionState,
} from "@/app/admin/(protected)/directory/actions";

const INPUT_CLASS = cn(
  "w-full bg-[oklch(0.97_0.01_80)] border border-[oklch(0.88_0.010_258)] rounded-lg px-3 py-2",
  "text-[oklch(0.24_0.055_258)] placeholder:text-[oklch(0.72_0.01_258)]",
  "focus:outline-none focus:ring-2 focus:ring-[oklch(0.72_0.115_82)] focus:border-transparent",
  "transition-colors duration-150",
);

// ── Dialog primitives (colocated, matching providers-table.tsx) ───────────────

function Overlay({
  onClose,
  children,
}: {
  onClose: () => void;
  children: React.ReactNode;
}) {
  useEffect(() => {
    const previous = document.body.style.overflow;
    document.body.style.overflow = "hidden";
    return () => {
      document.body.style.overflow = previous;
    };
  }, []);

  return createPortal(
    <div
      className="fixed inset-0 z-50 flex items-center justify-center p-4"
      style={{ background: "rgba(18,24,38,0.55)" }}
    >
      <div className="absolute inset-0" aria-hidden="true" onClick={onClose} />
      <div className="relative z-10 w-full max-w-lg">{children}</div>
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
    const element = ref.current;
    if (!element) return;
    const trigger = document.activeElement as HTMLElement | null;

    function handleKeyDown(event: KeyboardEvent) {
      if (event.key === "Escape") {
        event.preventDefault();
        onCloseRef.current();
        return;
      }
      if (event.key !== "Tab") return;

      const dialog = ref.current;
      if (!dialog) return;
      const focusable = Array.from(
        dialog.querySelectorAll<HTMLElement>(FOCUSABLE_SELECTOR),
      );
      if (focusable.length < 2) return;
      const first = focusable[0];
      const last = focusable[focusable.length - 1];
      if (event.shiftKey && document.activeElement === first) {
        event.preventDefault();
        last.focus();
      } else if (!event.shiftKey && document.activeElement === last) {
        event.preventDefault();
        first.focus();
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
      <div className="flex items-center justify-between px-6 py-4 border-b border-[oklch(0.92_0.010_258)] sticky top-0 bg-[oklch(0.99_0.005_80)] z-10">
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
        className={INPUT_CLASS}
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

function TextArea({
  label,
  name,
  rows = 2,
  placeholder,
  hint,
  maxLength,
  defaultValue,
}: {
  label: string;
  name: string;
  rows?: number;
  placeholder?: string;
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
      </label>
      <textarea
        id={uid}
        name={name}
        rows={rows}
        placeholder={placeholder}
        maxLength={maxLength}
        defaultValue={defaultValue}
        aria-describedby={hint ? hintId : undefined}
        className={cn(INPUT_CLASS, "resize-none")}
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

function CheckboxRow({
  name,
  label,
  hint,
  defaultChecked,
}: {
  name: string;
  label: string;
  hint: string;
  defaultChecked: boolean;
}) {
  const uid = useId();
  return (
    <div className="flex gap-2.5">
      <input
        id={uid}
        name={name}
        type="checkbox"
        defaultChecked={defaultChecked}
        className="mt-0.5 h-4 w-4 shrink-0 accent-[oklch(0.24_0.055_258)] focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[oklch(0.72_0.115_82)]"
      />
      <div>
        <label
          htmlFor={uid}
          className="block text-[oklch(0.24_0.055_258)] text-xs font-medium"
        >
          {label}
        </label>
        <p className="text-[oklch(0.72_0.01_258)] text-xs mt-0.5">{hint}</p>
      </div>
    </div>
  );
}

/**
 * Services as selectable chips.
 *
 * The vocabulary is fixed (see `lib/directory-taxonomy.ts`) because each slug
 * has to belong to a filter group on the public page. A free-text box here
 * would let an operator create a service nothing can filter by.
 */
function ServicePicker({ selected }: { selected: ServiceSlug[] }) {
  return (
    <fieldset>
      <legend className="text-[oklch(0.48_0.02_258)] text-xs font-medium mb-1.5">
        Services
        <span className="text-red-500 ml-0.5" aria-hidden="true">
          *
        </span>
      </legend>
      <div className="flex flex-wrap gap-1.5">
        {SERVICE_SLUGS.map((slug) => (
          <label
            key={slug}
            className="cursor-pointer"
            style={{ fontSize: "12px" }}
          >
            <input
              type="checkbox"
              name="services"
              value={slug}
              defaultChecked={selected.includes(slug)}
              className="peer sr-only"
            />
            <span
              className={cn(
                "inline-block rounded-full border px-2.5 py-1.5 font-medium",
                "border-[oklch(0.88_0.010_258)] text-[oklch(0.48_0.02_258)]",
                "peer-checked:border-[oklch(0.24_0.055_258)] peer-checked:bg-[oklch(0.24_0.055_258)] peer-checked:text-[oklch(0.99_0.005_80)]",
                "peer-focus-visible:ring-2 peer-focus-visible:ring-[oklch(0.72_0.115_82)]",
                "transition-colors duration-150",
              )}
            >
              {SERVICE_LABELS[slug]}
            </span>
          </label>
        ))}
      </div>
      <p className="text-[oklch(0.72_0.01_258)] text-xs mt-1.5">
        Pick every service that applies. These drive the filters on the public
        page.
      </p>
    </fieldset>
  );
}

// ── Add / Edit dialog ─────────────────────────────────────────────────────────

function ListingDialog({
  provider,
  onClose,
  onSuccess,
}: {
  provider?: DirectoryProvider;
  onClose: () => void;
  onSuccess: () => void;
}) {
  const isEdit = Boolean(provider);
  const action = provider
    ? updateDirectoryProviderAction.bind(null, provider.id)
    : createDirectoryProviderAction;
  const [state, formAction, pending] = useActionState<ActionState, FormData>(
    action,
    { error: null },
  );
  const wasPending = useRef(false);

  useEffect(() => {
    if (wasPending.current && !pending && !state.error) {
      onSuccess();
    }
    wasPending.current = pending;
  }, [pending, state.error, onSuccess]);

  return (
    <Overlay onClose={onClose}>
      <DialogShell
        title={isEdit ? "Edit listing" : "Add listing"}
        onClose={onClose}
      >
        <form action={formAction} className="space-y-4">
          <Field
            label="Business name"
            name="name"
            placeholder="e.g. Furryhome Animal Clinic"
            required
            autoFocus
            maxLength={120}
            defaultValue={provider?.name}
          />

          <ServicePicker selected={provider?.services ?? []} />

          <TextArea
            label="Address"
            name="address"
            placeholder="Street, barangay, city"
            maxLength={500}
            defaultValue={provider?.address ?? ""}
          />

          <TextArea
            label="Hours"
            name="hours"
            placeholder="Mon-Sat 8:00 AM-7:00 PM; Sun 8:00 AM-3:00 PM"
            hint="Write it as the business states it. If they have not confirmed, say so here rather than guessing."
            maxLength={300}
            defaultValue={provider?.hours ?? ""}
          />

          <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
            <Field
              label="Phone"
              name="phone"
              placeholder="(02) 8806 5772"
              maxLength={80}
              defaultValue={provider?.phone ?? ""}
            />
            <Field
              label="Email"
              name="email"
              type="email"
              placeholder="hello@clinic.ph"
              maxLength={120}
              defaultValue={provider?.email ?? ""}
            />
          </div>

          <Field
            label="Website"
            name="website"
            placeholder="clinic.ph"
            hint="https:// is added if you leave it off."
            maxLength={300}
            defaultValue={provider?.website ?? ""}
          />

          <Field
            label="Google Maps link"
            name="map_url"
            placeholder="Paste a Maps place link (optional)"
            hint="Leave blank and the map button searches the name and address instead."
            maxLength={600}
            defaultValue={provider?.map_url ?? ""}
          />

          <div className="space-y-3 rounded-lg border border-[oklch(0.90_0.010_258)] p-3">
            <CheckboxRow
              name="is_published"
              label="Show on the public page"
              hint="Unpublished listings stay here and are invisible to visitors."
              defaultChecked={provider?.is_published ?? true}
            />
            <CheckboxRow
              name="is_partner"
              label="MetroPaws Partner"
              hint="Only tick this when a real agreement exists. It puts a partner badge on the public listing and pins it to the top."
              defaultChecked={provider?.is_partner ?? false}
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
              {pending
                ? isEdit
                  ? "Saving…"
                  : "Adding…"
                : isEdit
                  ? "Save changes"
                  : "Add listing"}
            </button>
          </div>
        </form>
      </DialogShell>
    </Overlay>
  );
}

function ConfirmDeleteDialog({
  provider,
  error,
  pending,
  onConfirm,
  onClose,
}: {
  provider: DirectoryProvider;
  error: string | null;
  pending: boolean;
  onConfirm: () => void;
  onClose: () => void;
}) {
  return (
    <Overlay onClose={onClose}>
      <DialogShell title="Delete listing" onClose={onClose}>
        <p className="text-[oklch(0.48_0.02_258)] mb-2" style={{ fontSize: "13px" }}>
          Remove{" "}
          <strong className="text-[oklch(0.24_0.055_258)]">{provider.name}</strong>{" "}
          from the directory permanently?
        </p>
        <p className="text-[oklch(0.72_0.01_258)] text-xs mb-5">
          If you only want it off the public page, close this and switch it to
          unpublished instead. That keeps the details on file.
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
            className="flex-1 py-3 sm:py-2 rounded-lg border border-[oklch(0.88_0.010_258)] text-[oklch(0.48_0.02_258)] text-xs font-medium hover:bg-[oklch(0.94_0.015_75)] disabled:opacity-50 transition-colors"
          >
            Cancel
          </button>
          <button
            type="button"
            onClick={onConfirm}
            disabled={pending}
            className="flex-1 py-3 sm:py-2 rounded-lg bg-red-600 text-white text-xs font-semibold hover:bg-red-700 disabled:opacity-50 transition-colors"
          >
            {pending ? "Deleting…" : "Delete listing"}
          </button>
        </div>
      </DialogShell>
    </Overlay>
  );
}

// ── Row ───────────────────────────────────────────────────────────────────────

function ListingRow({
  provider,
  onRefresh,
}: {
  provider: DirectoryProvider;
  onRefresh: () => void;
}) {
  const [editOpen, setEditOpen] = useState(false);
  const [deleteOpen, setDeleteOpen] = useState(false);
  const [deleteError, setDeleteError] = useState<string | null>(null);
  const [deleting, startDelete] = useTransition();
  const [toggling, startToggle] = useTransition();

  function handleDelete() {
    startDelete(async () => {
      const result = await deleteDirectoryProviderAction(provider.id);
      if (result.error) {
        setDeleteError(result.error);
      } else {
        setDeleteOpen(false);
        onRefresh();
      }
    });
  }

  function handleTogglePublished() {
    startToggle(async () => {
      await toggleDirectoryPublishedAction(provider.id, !provider.is_published);
      onRefresh();
    });
  }

  return (
    <>
      <tr className="border-t border-[oklch(0.92_0.010_258)] hover:bg-[oklch(0.98_0.006_80)] transition-colors group">
        <td className="px-4 py-3.5">
          <div className="min-w-0">
            <div className="flex items-center gap-2">
              <p
                className="text-[oklch(0.24_0.055_258)] font-medium truncate"
                style={{ fontSize: "13px" }}
              >
                {provider.name}
              </p>
              {provider.is_partner && (
                <span className="shrink-0 rounded-full bg-(--color-gold-deep) px-2 py-0.5 text-[0.625rem] font-semibold uppercase tracking-wide text-(--color-cream)">
                  Partner
                </span>
              )}
            </div>
            <p className="text-[oklch(0.72_0.01_258)] text-xs mt-0.5 truncate">
              {serviceLine(provider.services) || "No services set"}
            </p>
          </div>
        </td>

        <td className="px-4 py-3.5">
          <p className="text-[oklch(0.48_0.02_258)] text-xs truncate">
            {provider.phone ?? "—"}
          </p>
          {provider.website && (
            <a
              href={provider.website}
              target="_blank"
              rel="noopener noreferrer"
              className="mt-0.5 inline-flex items-center gap-1 text-[oklch(0.72_0.01_258)] text-xs hover:text-[oklch(0.24_0.055_258)] transition-colors"
            >
              Website
              <ExternalLink size={10} aria-hidden="true" />
            </a>
          )}
        </td>

        <td className="px-4 py-3.5">
          <p className="text-[oklch(0.48_0.02_258)] text-xs line-clamp-2">
            {provider.address ?? "—"}
          </p>
        </td>

        <td className="px-4 py-3.5">
          <button
            type="button"
            onClick={handleTogglePublished}
            disabled={toggling}
            role="switch"
            aria-checked={provider.is_published}
            aria-label={
              provider.is_published
                ? `${provider.name} is published. Activate to hide it from the public page.`
                : `${provider.name} is hidden. Activate to publish it.`
            }
            className={cn(
              "relative inline-flex h-6 w-10 shrink-0 items-center rounded-full",
              "transition-colors duration-200 motion-reduce:transition-none disabled:opacity-40",
              provider.is_published
                ? "bg-[oklch(0.72_0.115_82)]"
                : "bg-[oklch(0.85_0.012_258)]",
            )}
          >
            <span
              className={cn(
                "pointer-events-none block h-4 w-4 rounded-full bg-[oklch(0.99_0.005_80)] shadow-sm",
                "transition-transform duration-200 motion-reduce:transition-none",
                provider.is_published ? "translate-x-5" : "translate-x-1",
              )}
            />
          </button>
        </td>

        <td className="px-3 py-3.5">
          <div className="flex items-center justify-end gap-1">
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
        <ListingDialog
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
          pending={deleting}
          onConfirm={handleDelete}
          onClose={() => {
            setDeleteOpen(false);
            setDeleteError(null);
          }}
        />
      )}
    </>
  );
}

// ── Table ─────────────────────────────────────────────────────────────────────

export function DirectoryTable({
  providers,
  fetchError,
}: {
  providers: DirectoryProvider[];
  fetchError: boolean;
}) {
  const router = useRouter();
  const [addOpen, setAddOpen] = useState(false);
  const [isRefreshing, startRefresh] = useTransition();

  const publishedCount = providers.filter((p) => p.is_published).length;

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
            Public website
          </p>
          <div className="flex items-baseline gap-3">
            <h1 className="text-[oklch(0.24_0.055_258)] text-2xl font-semibold tracking-tight">
              Pet Care Directory
            </h1>
            {!fetchError && (
              <span className="text-[oklch(0.48_0.02_258)] text-sm font-normal">
                {publishedCount} of {providers.length} published
              </span>
            )}
          </div>
          <p className="text-[oklch(0.72_0.01_258)] text-xs mt-1.5 max-w-xl">
            The community list on{" "}
            <a
              href="/find-pet-care"
              target="_blank"
              rel="noopener noreferrer"
              className="underline underline-offset-2 hover:text-[oklch(0.24_0.055_258)] transition-colors"
            >
              /find-pet-care
            </a>
            . These are public listings only, with no payout details and no
            connection to Providers or Clinics.
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
          Add listing
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
            Failed to load the directory
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
          <MapPin
            size={24}
            className="text-[oklch(0.72_0.01_258)] mb-3"
            aria-hidden="true"
          />
          <p
            className="text-[oklch(0.48_0.02_258)] font-medium"
            style={{ fontSize: "14px" }}
          >
            No listings yet
          </p>
          <p className="text-[oklch(0.72_0.01_258)] text-xs mt-1">
            Add a clinic, groomer, store, or boarding place to start the public
            directory.
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
              <table className="w-full min-w-160 table-fixed">
                <colgroup>
                  <col className="w-[36%]" />
                  <col className="w-[17%]" />
                  <col className="w-[27%]" />
                  <col className="w-[8%]" />
                  <col className="w-[12%]" />
                </colgroup>
                <thead>
                  <tr className="bg-[oklch(0.97_0.01_80)]">
                    {["Listing", "Contact", "Address"].map((heading) => (
                      <th
                        key={heading}
                        scope="col"
                        className="px-4 py-3 text-left text-[oklch(0.48_0.02_258)] text-xs font-semibold tracking-wide"
                      >
                        {heading}
                      </th>
                    ))}
                    <th
                      scope="col"
                      className="px-4 py-3 text-left text-[oklch(0.48_0.02_258)] text-xs font-semibold tracking-wide"
                    >
                      Live
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
                    <ListingRow
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
              : `${providers.length} ${providers.length === 1 ? "listing" : "listings"}`}
          </p>
        </>
      )}

      <span className="sr-only" role="status" aria-live="polite" aria-atomic="true">
        {isRefreshing ? "Refreshing the directory…" : ""}
      </span>

      {addOpen && (
        <ListingDialog
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
