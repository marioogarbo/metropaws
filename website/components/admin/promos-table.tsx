"use client";

import { useActionState, useState, useTransition, useRef, useEffect, useId } from "react";
import { useRouter } from "next/navigation";
import {
  Plus,
  Pencil,
  Trash2,
  X,
  Eye,
  EyeOff,
  AlertCircle,
  Megaphone,
  CalendarDays,
  Tag,
  MapPin,
  Link as LinkIcon,
} from "lucide-react";
import { toast } from "sonner";
import { cn } from "@/lib/utils";
import {
  createPromoAction,
  updatePromoAction,
  deletePromoAction,
  togglePromoPublishedAction,
  type Promo,
} from "@/app/admin/(protected)/promos/actions";

// ── Constants ─────────────────────────────────────────────────────────────────

const SESSION_EXPIRED_MSG = "Session expired. Please log in again.";
const MAX_TITLE_LEN = 120;
const MAX_BODY_LEN = 2000;
const MAX_LOCATION_LEN = 120;

// Events are stored as instants; admins think in Manila wall-clock (PH has no
// DST, so the constant +08:00 works both ways).
function toManilaInputValue(iso: string | null): string {
  if (!iso) return "";
  const shifted = new Date(new Date(iso).getTime() + 8 * 60 * 60 * 1000);
  return shifted.toISOString().slice(0, 16);
}

function formatEventDate(iso: string): string {
  return new Intl.DateTimeFormat("en-PH", {
    weekday: "short",
    day: "numeric",
    month: "short",
    year: "numeric",
    hour: "numeric",
    minute: "2-digit",
    timeZone: "Asia/Manila",
  }).format(new Date(iso));
}

// ── Field primitive ───────────────────────────────────────────────────────────

function Field({
  label,
  name,
  value,
  onChange,
  placeholder,
  required,
  maxLength,
  multiline,
  rows = 4,
  hint,
  type = "text",
}: {
  label: string;
  name: string;
  value: string;
  onChange: (v: string) => void;
  placeholder?: string;
  required?: boolean;
  maxLength?: number;
  multiline?: boolean;
  rows?: number;
  hint?: string;
  type?: string;
}) {
  const id = useId();
  const sharedClass = cn(
    "w-full bg-[oklch(0.97_0.01_80)] border border-[oklch(0.88_0.010_258)] rounded-lg px-3 py-2",
    "text-sm text-[oklch(0.24_0.055_258)] placeholder:text-[oklch(0.72_0.01_258)]",
    "focus:outline-none focus:ring-2 focus:ring-[oklch(0.72_0.115_82)] focus:border-transparent",
    "transition-colors duration-150",
  );

  return (
    <div>
      <div className="flex items-baseline justify-between mb-1">
        <label
          htmlFor={id}
          className="block text-[oklch(0.48_0.02_258)] text-sm font-semibold"
        >
          {label}
          {required && <span className="text-[oklch(0.72_0.115_82)] ml-0.5">*</span>}
        </label>
        {maxLength && (
          <span className="text-[oklch(0.72_0.01_258)] text-sm tabular-nums">
            {value.length}/{maxLength}
          </span>
        )}
      </div>
      {multiline ? (
        <textarea
          id={id}
          name={name}
          value={value}
          onChange={(e) => onChange(e.target.value)}
          placeholder={placeholder}
          required={required}
          maxLength={maxLength}
          rows={rows}
          className={cn(sharedClass, "resize-y")}
        />
      ) : (
        <input
          id={id}
          name={name}
          type={type}
          value={value}
          onChange={(e) => onChange(e.target.value)}
          placeholder={placeholder}
          required={required}
          maxLength={maxLength}
          className={sharedClass}
        />
      )}
      {hint && <p className="text-[oklch(0.72_0.01_258)] text-sm mt-1.5">{hint}</p>}
    </div>
  );
}

// ── Toggle primitive ──────────────────────────────────────────────────────────

function Toggle({
  label,
  description,
  checked,
  onChange,
}: {
  label: string;
  description?: string;
  checked: boolean;
  onChange: (v: boolean) => void;
}) {
  return (
    <label className="flex items-start gap-2 cursor-pointer select-none group">
      <input
        type="checkbox"
        checked={checked}
        onChange={(e) => onChange(e.target.checked)}
        className="mt-0.5 w-4 h-4 rounded accent-[oklch(0.72_0.115_82)]"
      />
      <span className="text-[oklch(0.48_0.02_258)] text-sm font-semibold group-hover:text-[oklch(0.24_0.055_258)] transition-colors">
        {label}
        {description && (
          <span className="block text-[oklch(0.72_0.01_258)] text-sm font-normal mt-0.5">
            {description}
          </span>
        )}
      </span>
    </label>
  );
}

// ── Overlay + dialog shell ────────────────────────────────────────────────────

function Overlay({
  onClose,
  children,
}: {
  onClose: () => void;
  children: React.ReactNode;
}) {
  return (
    <div
      className="fixed inset-0 z-50 flex items-center justify-center p-4 animate-in fade-in duration-150"
      style={{ background: "rgba(18,24,38,0.55)" }}
    >
      <div className="absolute inset-0" onClick={onClose} aria-hidden="true" />
      <div className="relative z-10 w-full max-w-lg">{children}</div>
    </div>
  );
}

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
  const shellRef = useRef<HTMLDivElement>(null);
  const onCloseRef = useRef(onClose);
  onCloseRef.current = onClose;

  useEffect(() => {
    const el = shellRef.current;
    if (!el) return;
    const firstFocusable = el.querySelector<HTMLElement>(
      'button:not([disabled]), input:not([disabled]):not([type="hidden"]), textarea:not([disabled]), select:not([disabled]), [tabindex]:not([tabindex="-1"])',
    );
    firstFocusable?.focus();

    const trap = (e: KeyboardEvent) => {
      if (e.key === "Escape") {
        onCloseRef.current();
        return;
      }
      if (e.key !== "Tab" || !shellRef.current) return;
      const focusable = shellRef.current.querySelectorAll<HTMLElement>(
        'button:not([disabled]), input:not([disabled]):not([type="hidden"]), textarea:not([disabled]), select:not([disabled]), [tabindex]:not([tabindex="-1"])',
      );
      const first = focusable[0];
      const last = focusable[focusable.length - 1];
      if (e.shiftKey) {
        if (document.activeElement === first) {
          e.preventDefault();
          last?.focus();
        }
      } else {
        if (document.activeElement === last) {
          e.preventDefault();
          first?.focus();
        }
      }
    };
    document.addEventListener("keydown", trap);
    return () => document.removeEventListener("keydown", trap);
  }, []);

  useEffect(() => {
    const prev = document.body.style.overflow;
    document.body.style.overflow = "hidden";
    return () => {
      document.body.style.overflow = prev;
    };
  }, []);

  return (
    <div
      ref={shellRef}
      role="dialog"
      aria-modal="true"
      aria-labelledby={titleId}
      className="bg-[oklch(0.99_0.005_80)] rounded-xl shadow-xl border border-[oklch(0.88_0.010_258)] overflow-hidden max-h-[90vh] flex flex-col animate-in fade-in zoom-in-95 slide-in-from-bottom-2 duration-200"
    >
      <div className="flex items-center justify-between px-6 py-4 border-b border-[oklch(0.92_0.010_258)] shrink-0">
        <h2
          id={titleId}
          className="text-base text-[oklch(0.24_0.055_258)] font-semibold tracking-tight truncate mr-3"
        >
          {title}
        </h2>
        <button
          type="button"
          onClick={onClose}
          aria-label="Close dialog"
          className="shrink-0 p-1 -mr-1 rounded text-[oklch(0.72_0.01_258)] hover:text-[oklch(0.48_0.02_258)] transition-colors"
        >
          <X size={16} />
        </button>
      </div>
      <div className="px-6 py-5 overflow-y-auto">{children}</div>
    </div>
  );
}

// ── Type selector ─────────────────────────────────────────────────────────────

function TypeSelector({
  value,
  onChange,
}: {
  value: "event" | "promo";
  onChange: (v: "event" | "promo") => void;
}) {
  const options: { key: "event" | "promo"; label: string; icon: typeof Tag }[] = [
    { key: "event", label: "Event", icon: CalendarDays },
    { key: "promo", label: "Promo", icon: Tag },
  ];
  return (
    <div>
      <p className="text-[oklch(0.48_0.02_258)] text-sm font-semibold mb-1">Type</p>
      <div className="grid grid-cols-2 gap-2">
        {options.map(({ key, label, icon: Icon }) => (
          <button
            key={key}
            type="button"
            onClick={() => onChange(key)}
            aria-pressed={value === key}
            className={cn(
              "flex items-center justify-center gap-1.5 rounded-lg border px-3 py-2 text-sm font-semibold transition-colors",
              value === key
                ? "bg-[oklch(0.24_0.055_258)] text-[oklch(0.97_0.01_80)] border-transparent"
                : "bg-[oklch(0.97_0.01_80)] text-[oklch(0.48_0.02_258)] border-[oklch(0.88_0.010_258)] hover:border-[oklch(0.80_0.015_258)]",
            )}
          >
            <Icon size={13} />
            {label}
          </button>
        ))}
      </div>
    </div>
  );
}

// ── Promo form dialog ─────────────────────────────────────────────────────────

function PromoFormDialog({
  promo,
  onClose,
  onSuccess,
}: {
  promo: Promo | null;
  onClose: () => void;
  onSuccess: (action: "created" | "updated") => void;
}) {
  const isEdit = promo !== null;
  const action = isEdit ? updatePromoAction : createPromoAction;
  const [state, formAction, pending] = useActionState(action, { error: null });

  const [title, setTitle] = useState(promo?.title ?? "");
  const [type, setType] = useState<"event" | "promo">(promo?.type ?? "event");
  const [body, setBody] = useState(promo?.body ?? "");
  const [eventDate, setEventDate] = useState(toManilaInputValue(promo?.event_date ?? null));
  const [location, setLocation] = useState(promo?.location ?? "");
  const [linkUrl, setLinkUrl] = useState(promo?.link_url ?? "");
  const [isPublished, setIsPublished] = useState(promo?.is_published ?? true);

  const prevPending = useRef(false);

  useEffect(() => {
    if (prevPending.current && !pending && !state.error) {
      onSuccess(isEdit ? "updated" : "created");
    }
    prevPending.current = pending;
  }, [pending, state.error, onSuccess, isEdit]);

  const isSessionExpired = state.error === SESSION_EXPIRED_MSG;

  return (
    <Overlay onClose={onClose}>
      <DialogShell title={isEdit ? "Edit promo" : "New event or promo"} onClose={onClose}>
        <form action={formAction} className="space-y-5">
          {isEdit && <input type="hidden" name="id" value={promo.id} />}
          <input type="hidden" name="type" value={type} />
          <input
            type="hidden"
            name="is_published"
            value={isPublished ? "true" : "false"}
          />

          <TypeSelector value={type} onChange={setType} />

          <Field
            label="Title"
            name="title"
            value={title}
            onChange={setTitle}
            placeholder={type === "event" ? "Members' Welcome Dinner" : "15% off multi-pet enrollment"}
            required
            maxLength={MAX_TITLE_LEN}
          />

          {type === "event" && (
            <>
              <Field
                label="Date & time"
                name="event_date"
                value={eventDate}
                onChange={setEventDate}
                type="datetime-local"
                hint="Philippine time"
              />
              <Field
                label="Location"
                name="location"
                value={location}
                onChange={setLocation}
                placeholder="Apollo 3, Quezon City"
                maxLength={MAX_LOCATION_LEN}
              />
            </>
          )}

          <Field
            label="Details"
            name="body"
            value={body}
            onChange={setBody}
            placeholder="What members should know…"
            maxLength={MAX_BODY_LEN}
            multiline
            rows={4}
          />

          <Field
            label="Link (optional)"
            name="link_url"
            value={linkUrl}
            onChange={setLinkUrl}
            type="url"
            placeholder="https://facebook.com/…"
            hint="Members get a tappable link on the card — e.g. an FB post or signup form."
          />

          <div className="pt-4 border-t border-[oklch(0.92_0.010_258)]">
            <Toggle
              label="Published"
              description="Visible in the member app"
              checked={isPublished}
              onChange={setIsPublished}
            />
          </div>

          {state.error && (
            <p
              className={cn(
                "flex items-center gap-1.5 text-sm",
                isSessionExpired ? "text-amber-600" : "text-red-600",
              )}
            >
              <AlertCircle size={13} className="shrink-0" />
              {state.error}
            </p>
          )}

          <div className="flex items-center justify-end gap-2 pt-1">
            <button
              type="button"
              onClick={onClose}
              className="px-4 py-2 rounded-lg text-sm font-medium text-[oklch(0.48_0.02_258)] bg-[oklch(0.94_0.015_75)] hover:bg-[oklch(0.90_0.020_75)] transition-colors"
            >
              Cancel
            </button>
            <button
              type="submit"
              disabled={pending}
              className="px-4 py-2 rounded-lg text-sm font-semibold bg-[oklch(0.24_0.055_258)] text-[oklch(0.97_0.01_80)] hover:bg-[oklch(0.32_0.050_258)] transition-colors disabled:opacity-50"
            >
              {pending ? "Saving…" : isEdit ? "Save changes" : "Create"}
            </button>
          </div>
        </form>
      </DialogShell>
    </Overlay>
  );
}

// ── Delete confirmation dialog ────────────────────────────────────────────────

function DeleteDialog({
  promo,
  onClose,
  onSuccess,
}: {
  promo: Promo;
  onClose: () => void;
  onSuccess: () => void;
}) {
  const [pending, startTransition] = useTransition();
  const [error, setError] = useState<string | null>(null);
  const router = useRouter();

  function handleDelete() {
    setError(null);
    startTransition(async () => {
      const result = await deletePromoAction(promo.id);
      if (result.error) {
        setError(result.error);
        return;
      }
      onSuccess();
      router.refresh();
    });
  }

  return (
    <Overlay onClose={onClose}>
      <DialogShell title="Delete promo" onClose={onClose}>
        <div className="space-y-4">
          <p className="text-sm text-[oklch(0.48_0.02_258)]">
            Are you sure you want to delete this? It disappears from the member app
            immediately. This cannot be undone.
          </p>
          <p className="rounded-lg bg-[oklch(0.94_0.015_75)] px-4 py-3 text-sm text-[oklch(0.24_0.055_258)] line-clamp-3">
            {promo.title}
          </p>
          {error && (
            <p className="flex items-center gap-1.5 text-sm text-red-600">
              <AlertCircle size={13} className="shrink-0" />
              {error}
            </p>
          )}
          <div className="flex items-center justify-end gap-2 pt-1">
            <button
              type="button"
              onClick={onClose}
              className="px-4 py-2 rounded-lg text-sm font-medium text-[oklch(0.48_0.02_258)] bg-[oklch(0.94_0.015_75)] hover:bg-[oklch(0.90_0.020_75)] transition-colors"
            >
              Cancel
            </button>
            <button
              type="button"
              onClick={handleDelete}
              disabled={pending}
              className="px-4 py-2 rounded-lg text-sm font-semibold bg-red-600 text-white hover:bg-red-700 transition-colors disabled:opacity-50"
            >
              {pending ? "Deleting…" : "Delete"}
            </button>
          </div>
        </div>
      </DialogShell>
    </Overlay>
  );
}

// ── Promo row ─────────────────────────────────────────────────────────────────

function PromoRow({
  promo,
  onEdit,
  onDelete,
}: {
  promo: Promo;
  onEdit: (promo: Promo) => void;
  onDelete: (promo: Promo) => void;
}) {
  const [toggling, startToggle] = useTransition();
  const [localPublished, setLocalPublished] = useState(promo.is_published);
  const router = useRouter();

  useEffect(() => {
    setLocalPublished(promo.is_published);
  }, [promo.is_published]);

  function handleTogglePublished() {
    const next = !localPublished;
    setLocalPublished(next);
    startToggle(async () => {
      const result = await togglePromoPublishedAction(promo.id, next);
      if (result.error) {
        setLocalPublished(!next);
        toast.error(result.error);
        return;
      }
      toast.success(next ? "Published" : "Unpublished");
      router.refresh();
    });
  }

  const isEvent = promo.type === "event";
  const TypeIcon = isEvent ? CalendarDays : Tag;

  return (
    <div
      className={cn(
        "rounded-xl bg-[oklch(0.99_0.005_80)] border border-[oklch(0.88_0.010_258)]",
        "transition-[border-color] duration-150 hover:border-[oklch(0.80_0.015_258)]",
        "flex items-start gap-3 px-4 py-4",
        !localPublished && "opacity-60",
      )}
    >
      <span
        className={cn(
          "mt-0.5 shrink-0 flex items-center justify-center w-8 h-8 rounded-lg",
          isEvent
            ? "bg-[oklch(0.93_0.020_258)] text-[oklch(0.24_0.055_258)]"
            : "bg-[oklch(0.95_0.030_85)] text-[oklch(0.52_0.085_82)]",
        )}
      >
        <TypeIcon size={14} />
      </span>

      <div className="flex-1 min-w-0">
        <p className="text-sm font-semibold text-[oklch(0.24_0.055_258)] leading-snug">
          {promo.title}
        </p>
        <div className="flex flex-wrap items-center gap-x-3 gap-y-0.5 mt-1">
          {isEvent && promo.event_date && (
            <span className="text-sm text-[oklch(0.48_0.020_258)]">
              {formatEventDate(promo.event_date)}
            </span>
          )}
          {isEvent && promo.location && (
            <span className="flex items-center gap-1 text-sm text-[oklch(0.48_0.020_258)]">
              <MapPin size={11} className="shrink-0" />
              {promo.location}
            </span>
          )}
          {promo.link_url && (
            <span className="flex items-center gap-1 text-sm text-[oklch(0.48_0.020_258)]">
              <LinkIcon size={11} className="shrink-0" />
              link
            </span>
          )}
        </div>
        {promo.body && (
          <p className="text-sm text-[oklch(0.48_0.020_258)] mt-1 line-clamp-2 leading-relaxed">
            {promo.body}
          </p>
        )}
      </div>

      <div className="shrink-0 flex items-center gap-1">
        <button
          type="button"
          onClick={handleTogglePublished}
          disabled={toggling}
          aria-label={localPublished ? "Unpublish" : "Publish"}
          title={localPublished ? "Unpublish" : "Publish"}
          className={cn(
            "p-1.5 rounded-lg transition-colors disabled:opacity-40",
            localPublished
              ? "text-[oklch(0.72_0.115_82)] hover:bg-[oklch(0.94_0.015_75)]"
              : "text-[oklch(0.72_0.01_258)] hover:bg-[oklch(0.94_0.015_75)] hover:text-[oklch(0.48_0.02_258)]",
          )}
        >
          {localPublished ? <Eye size={13} /> : <EyeOff size={13} />}
        </button>

        <button
          type="button"
          onClick={() => onEdit(promo)}
          aria-label="Edit"
          className="p-1.5 rounded-lg text-[oklch(0.72_0.01_258)] hover:bg-[oklch(0.94_0.015_75)] hover:text-[oklch(0.24_0.055_258)] transition-colors"
        >
          <Pencil size={13} />
        </button>

        <button
          type="button"
          onClick={() => onDelete(promo)}
          aria-label="Delete"
          className="p-1.5 rounded-lg text-[oklch(0.72_0.01_258)] hover:bg-red-50 hover:text-red-500 transition-colors"
        >
          <Trash2 size={13} />
        </button>
      </div>
    </div>
  );
}

// ── Empty state ───────────────────────────────────────────────────────────────

function EmptyState({ onAdd }: { onAdd: () => void }) {
  return (
    <div className="rounded-xl border border-dashed border-[oklch(0.88_0.010_258)] bg-[oklch(0.99_0.005_80)] px-8 py-14 flex flex-col items-center text-center gap-4">
      <Megaphone size={28} className="text-[oklch(0.88_0.010_258)]" />
      <p className="text-sm text-[oklch(0.48_0.020_258)] max-w-xs">
        Nothing here yet. Add an event or promo — members see it on the app&apos;s
        Events tab right away.
      </p>
      <button
        type="button"
        onClick={onAdd}
        className="flex items-center gap-1.5 px-4 py-2 rounded-lg text-sm font-semibold bg-[oklch(0.24_0.055_258)] text-[oklch(0.97_0.01_80)] hover:bg-[oklch(0.32_0.050_258)] transition-colors"
      >
        <Plus size={14} />
        Add event or promo
      </button>
    </div>
  );
}

// ── Error banner ──────────────────────────────────────────────────────────────

function FetchErrorBanner() {
  return (
    <div className="rounded-xl border border-red-200 bg-red-50 px-5 py-4 flex items-center gap-2.5">
      <AlertCircle size={14} className="shrink-0 text-red-500" />
      <p className="text-sm text-red-700">
        Failed to load promos. Check your connection and refresh.
      </p>
    </div>
  );
}

// ── Main component ────────────────────────────────────────────────────────────

export function PromosTable({
  promos,
  fetchError,
}: {
  promos: Promo[];
  fetchError: boolean;
}) {
  const [dialog, setDialog] = useState<
    | { type: "create" }
    | { type: "edit"; promo: Promo }
    | { type: "delete"; promo: Promo }
    | null
  >(null);
  const router = useRouter();

  function handleSuccess(action: "created" | "updated") {
    toast.success(action === "created" ? "Created" : "Updated");
    setDialog(null);
    router.refresh();
  }

  function handleDeleteSuccess() {
    toast.success("Deleted");
    setDialog(null);
    router.refresh();
  }

  const publishedCount = promos.filter((p) => p.is_published).length;
  const eventCount = promos.filter((p) => p.type === "event").length;

  return (
    <>
      {/* Toolbar */}
      <div className="flex items-center justify-between mb-6">
        <div className="flex flex-col gap-0.5">
          {promos.length > 0 && (
            <p className="text-sm text-[oklch(0.48_0.020_258)]">
              <span className="font-semibold text-[oklch(0.24_0.055_258)]">
                {promos.length}
              </span>{" "}
              total · {eventCount} events
              {promos.length !== publishedCount && (
                <>
                  {" · "}
                  <span className="font-semibold text-[oklch(0.72_0.115_82)]">
                    {publishedCount}
                  </span>{" "}
                  published
                </>
              )}
            </p>
          )}
        </div>
        <button
          type="button"
          onClick={() => setDialog({ type: "create" })}
          className="flex items-center gap-1.5 px-4 py-2 rounded-lg text-sm font-semibold bg-[oklch(0.24_0.055_258)] text-[oklch(0.97_0.01_80)] hover:bg-[oklch(0.32_0.050_258)] transition-colors"
        >
          <Plus size={14} />
          Add event or promo
        </button>
      </div>

      {/* Content */}
      {fetchError ? (
        <FetchErrorBanner />
      ) : promos.length === 0 ? (
        <EmptyState onAdd={() => setDialog({ type: "create" })} />
      ) : (
        <div className="space-y-3">
          {promos.map((promo) => (
            <PromoRow
              key={promo.id}
              promo={promo}
              onEdit={(p) => setDialog({ type: "edit", promo: p })}
              onDelete={(p) => setDialog({ type: "delete", promo: p })}
            />
          ))}
        </div>
      )}

      {/* Dialogs */}
      {dialog?.type === "create" && (
        <PromoFormDialog
          promo={null}
          onClose={() => setDialog(null)}
          onSuccess={handleSuccess}
        />
      )}
      {dialog?.type === "edit" && (
        <PromoFormDialog
          promo={dialog.promo}
          onClose={() => setDialog(null)}
          onSuccess={handleSuccess}
        />
      )}
      {dialog?.type === "delete" && (
        <DeleteDialog
          promo={dialog.promo}
          onClose={() => setDialog(null)}
          onSuccess={handleDeleteSuccess}
        />
      )}
    </>
  );
}
