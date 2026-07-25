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
  ChevronDown,
  GripVertical,
  HelpCircle,
} from "lucide-react";
import {
  DndContext,
  DragOverlay,
  closestCenter,
  PointerSensor,
  KeyboardSensor,
  useSensor,
  useSensors,
  type DragEndEvent,
  type DragStartEvent,
} from "@dnd-kit/core";
import {
  SortableContext,
  sortableKeyboardCoordinates,
  useSortable,
  verticalListSortingStrategy,
  arrayMove,
} from "@dnd-kit/sortable";
import { CSS } from "@dnd-kit/utilities";
import { toast } from "sonner";
import { cn } from "@/lib/utils";
import {
  createFaqAction,
  updateFaqAction,
  deleteFaqAction,
  toggleFaqPublishedAction,
  reorderFaqsAction,
  type FAQ,
} from "@/app/admin/(protected)/faqs/actions";

// ── Constants ─────────────────────────────────────────────────────────────────

const SESSION_EXPIRED_MSG = "Session expired. Please log in again.";
const MAX_QUESTION_LEN = 300;
const MAX_ANSWER_LEN = 2000;

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
          type="text"
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
      'button:not([disabled]), input:not([disabled]):not([type="hidden"]), textarea:not([disabled]), [tabindex]:not([tabindex="-1"])',
    );
    firstFocusable?.focus();

    const trap = (e: KeyboardEvent) => {
      if (e.key === "Escape") {
        onCloseRef.current();
        return;
      }
      if (e.key !== "Tab" || !shellRef.current) return;
      const focusable = shellRef.current.querySelectorAll<HTMLElement>(
        'button:not([disabled]), input:not([disabled]):not([type="hidden"]), textarea:not([disabled]), [tabindex]:not([tabindex="-1"])',
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

// ── FAQ form dialog ───────────────────────────────────────────────────────────

function FaqFormDialog({
  faq,
  onClose,
  onSuccess,
}: {
  faq: FAQ | null;
  onClose: () => void;
  onSuccess: (action: "created" | "updated") => void;
}) {
  const isEdit = faq !== null;
  const action = isEdit ? updateFaqAction : createFaqAction;
  const [state, formAction, pending] = useActionState(action, { error: null });

  const [question, setQuestion] = useState(faq?.question ?? "");
  const [answer, setAnswer] = useState(faq?.answer ?? "");
  const [isPublished, setIsPublished] = useState(faq?.is_published ?? true);

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
      <DialogShell title={isEdit ? "Edit FAQ" : "New FAQ"} onClose={onClose}>
        <form action={formAction} className="space-y-5">
          {isEdit && <input type="hidden" name="id" value={faq.id} />}
          <input
            type="hidden"
            name="is_published"
            value={isPublished ? "true" : "false"}
          />

          <Field
            label="Question"
            name="question"
            value={question}
            onChange={setQuestion}
            placeholder="What is MetroPaws?"
            required
            maxLength={MAX_QUESTION_LEN}
          />

          <Field
            label="Answer"
            name="answer"
            value={answer}
            onChange={setAnswer}
            placeholder="MetroPaws is a pet wellness membership…"
            required
            maxLength={MAX_ANSWER_LEN}
            multiline
            rows={5}
          />

          <div className="pt-4 border-t border-[oklch(0.92_0.010_258)]">
            <Toggle
              label="Published"
              description="Visible on the public site"
              checked={isPublished}
              onChange={setIsPublished}
            />
          </div>

          {state.error && !isSessionExpired && (
            <p className="flex items-center gap-1.5 text-sm text-red-600">
              <AlertCircle size={13} className="shrink-0" />
              {state.error}
            </p>
          )}
          {isSessionExpired && (
            <p className="flex items-center gap-1.5 text-sm text-amber-600">
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
              {pending ? "Saving…" : isEdit ? "Save changes" : "Create FAQ"}
            </button>
          </div>
        </form>
      </DialogShell>
    </Overlay>
  );
}

// ── Delete confirmation dialog ────────────────────────────────────────────────

function DeleteDialog({
  faq,
  onClose,
  onSuccess,
}: {
  faq: FAQ;
  onClose: () => void;
  onSuccess: () => void;
}) {
  const [pending, startTransition] = useTransition();
  const [error, setError] = useState<string | null>(null);
  const router = useRouter();

  function handleDelete() {
    setError(null);
    startTransition(async () => {
      const result = await deleteFaqAction(faq.id);
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
      <DialogShell title="Delete FAQ" onClose={onClose}>
        <div className="space-y-4">
          <p className="text-sm text-[oklch(0.48_0.02_258)]">
            Are you sure you want to delete this FAQ? This cannot be undone.
          </p>
          <p className="rounded-lg bg-[oklch(0.94_0.015_75)] px-4 py-3 text-sm text-[oklch(0.24_0.055_258)] line-clamp-3">
            {faq.question}
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

// ── Sortable FAQ row ─────────────────────────────────────────────────────────

function FaqRow({
  faq,
  onEdit,
  onDelete,
}: {
  faq: FAQ;
  onEdit: (faq: FAQ) => void;
  onDelete: (faq: FAQ) => void;
}) {
  const [expanded, setExpanded] = useState(false);
  const [toggling, startToggle] = useTransition();
  const [localPublished, setLocalPublished] = useState(faq.is_published);
  const router = useRouter();

  const { attributes, listeners, setNodeRef, transform, transition, isDragging } =
    useSortable({ id: faq.id });

  const style = {
    transform: CSS.Transform.toString(transform),
    transition,
  };

  useEffect(() => {
    setLocalPublished(faq.is_published);
  }, [faq.is_published]);

  function handleTogglePublished() {
    const next = !localPublished;
    setLocalPublished(next);
    startToggle(async () => {
      const result = await toggleFaqPublishedAction(faq.id, next);
      if (result.error) {
        setLocalPublished(!next);
        toast.error(result.error);
        return;
      }
      toast.success(next ? "FAQ published" : "FAQ unpublished");
      router.refresh();
    });
  }

  return (
    <div
      ref={setNodeRef}
      style={{ ...style, willChange: isDragging ? "transform" : undefined }}
      className={cn(
        "rounded-xl bg-[oklch(0.99_0.005_80)] border border-[oklch(0.88_0.010_258)] overflow-hidden",
        "transition-[border-color,box-shadow] duration-150 hover:border-[oklch(0.80_0.015_258)]",
        isDragging && "opacity-40 border-[oklch(0.80_0.015_258)]",
      )}
    >
      {/* Row header */}
      <div className="flex items-start gap-2 px-4 py-4">
        {/* Drag handle */}
        <button
          type="button"
          {...attributes}
          {...listeners}
          aria-label="Drag to reorder"
          className={cn(
            "mt-0.5 shrink-0 p-1 -ml-1 rounded text-[oklch(0.72_0.01_258)] hover:text-[oklch(0.48_0.02_258)] hover:bg-[oklch(0.94_0.015_75)] transition-colors cursor-grab active:cursor-grabbing",
            "focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[oklch(0.72_0.115_82)] focus-visible:ring-offset-1",
            isDragging && "cursor-grabbing",
          )}
        >
          <GripVertical size={14} />
        </button>

        {/* Question + answer preview */}
        <button
          type="button"
          onClick={() => setExpanded((v) => !v)}
          className="flex-1 min-w-0 text-left group"
          aria-expanded={expanded}
        >
          <p className="text-sm font-semibold text-[oklch(0.24_0.055_258)] leading-snug group-hover:text-[oklch(0.32_0.050_258)] transition-colors">
            {faq.question}
          </p>
          {!expanded && (
            <p className="text-sm text-[oklch(0.48_0.020_258)] mt-1 line-clamp-1 leading-relaxed">
              {faq.answer}
            </p>
          )}
        </button>

        {/* Actions */}
        <div className="shrink-0 flex items-center gap-1">
          {/* Publish toggle */}
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

          {/* Edit */}
          <button
            type="button"
            onClick={() => onEdit(faq)}
            aria-label="Edit FAQ"
            className="p-1.5 rounded-lg text-[oklch(0.72_0.01_258)] hover:bg-[oklch(0.94_0.015_75)] hover:text-[oklch(0.24_0.055_258)] transition-colors"
          >
            <Pencil size={13} />
          </button>

          {/* Delete */}
          <button
            type="button"
            onClick={() => onDelete(faq)}
            aria-label="Delete FAQ"
            className="p-1.5 rounded-lg text-[oklch(0.72_0.01_258)] hover:bg-red-50 hover:text-red-500 transition-colors"
          >
            <Trash2 size={13} />
          </button>

          {/* Expand toggle */}
          <button
            type="button"
            onClick={() => setExpanded((v) => !v)}
            aria-label={expanded ? "Collapse answer" : "Expand answer"}
            className="p-1.5 rounded-lg text-[oklch(0.72_0.01_258)] hover:bg-[oklch(0.94_0.015_75)] transition-colors ml-0.5"
          >
            <ChevronDown
              size={13}
              className={cn(
                "transition-transform duration-200",
                expanded && "rotate-180",
              )}
            />
          </button>
        </div>
      </div>

      {/* Expandable answer — CSS grid trick for smooth height animation */}
      <div
        className={cn(
          "grid transition-[grid-template-rows] duration-300 ease-[cubic-bezier(0.25,1,0.5,1)]",
          expanded ? "grid-rows-[1fr]" : "grid-rows-[0fr]",
        )}
      >
        <div className="overflow-hidden">
          <div className="pl-9 pr-5 pb-5">
            <div className="border-t border-[oklch(0.92_0.010_258)] pt-4">
              <p className="text-sm text-[oklch(0.48_0.020_258)] leading-relaxed whitespace-pre-wrap">
                {faq.answer}
              </p>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}

// ── Empty state ───────────────────────────────────────────────────────────────

function EmptyState({ onAdd }: { onAdd: () => void }) {
  return (
    <div className="rounded-xl border border-dashed border-[oklch(0.88_0.010_258)] bg-[oklch(0.99_0.005_80)] px-8 py-14 flex flex-col items-center text-center gap-4">
      <HelpCircle size={28} className="text-[oklch(0.88_0.010_258)]" />
      <p className="text-sm text-[oklch(0.48_0.020_258)] max-w-xs">
        No FAQs yet. Add your first question to populate the public FAQ section.
      </p>
      <button
        type="button"
        onClick={onAdd}
        className="flex items-center gap-1.5 px-4 py-2 rounded-lg text-sm font-semibold bg-[oklch(0.24_0.055_258)] text-[oklch(0.97_0.01_80)] hover:bg-[oklch(0.32_0.050_258)] transition-colors"
      >
        <Plus size={14} />
        Add FAQ
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
        Failed to load FAQs. Check your connection and refresh.
      </p>
    </div>
  );
}

// ── Main component ────────────────────────────────────────────────────────────

export function FaqsTable({ faqs, fetchError }: { faqs: FAQ[]; fetchError: boolean }) {
  const [dialog, setDialog] = useState<
    { type: "create" } | { type: "edit"; faq: FAQ } | { type: "delete"; faq: FAQ } | null
  >(null);
  const router = useRouter();
  const [, startReorder] = useTransition();
  const [activeId, setActiveId] = useState<string | null>(null);

  const initialOrder = [...faqs].sort((a, b) => a.sort_order - b.sort_order);
  const [orderedFaqs, setOrderedFaqs] = useState<FAQ[]>(initialOrder);

  // Sync when server data changes (after refresh)
  useEffect(() => {
    setOrderedFaqs([...faqs].sort((a, b) => a.sort_order - b.sort_order));
  }, [faqs]);

  const sensors = useSensors(
    useSensor(PointerSensor, { activationConstraint: { distance: 5 } }),
    useSensor(KeyboardSensor, { coordinateGetter: sortableKeyboardCoordinates }),
  );

  function handleDragStart(event: DragStartEvent) {
    setActiveId(event.active.id as string);
  }

  function handleDragEnd(event: DragEndEvent) {
    setActiveId(null);
    const { active, over } = event;
    if (!over || active.id === over.id) return;

    const oldIndex = orderedFaqs.findIndex((f) => f.id === active.id);
    const newIndex = orderedFaqs.findIndex((f) => f.id === over.id);
    const reordered = arrayMove(orderedFaqs, oldIndex, newIndex);

    setOrderedFaqs(reordered);

    startReorder(async () => {
      const result = await reorderFaqsAction(reordered.map((f) => f.id));
      if (result.error) {
        toast.error(result.error);
        setOrderedFaqs(orderedFaqs);
        return;
      }
      router.refresh();
    });
  }

  function handleSuccess(action: "created" | "updated") {
    toast.success(action === "created" ? "FAQ created" : "FAQ updated");
    setDialog(null);
    router.refresh();
  }

  function handleDeleteSuccess() {
    toast.success("FAQ deleted");
    setDialog(null);
    router.refresh();
  }

  const publishedCount = orderedFaqs.filter((f) => f.is_published).length;

  return (
    <>
      {/* Toolbar */}
      <div className="flex items-center justify-between mb-6">
        <div className="flex flex-col gap-0.5">
          {orderedFaqs.length > 0 && (
            <p className="text-sm text-[oklch(0.48_0.020_258)]">
              <span className="font-semibold text-[oklch(0.24_0.055_258)]">
                {orderedFaqs.length}
              </span>{" "}
              total
              {orderedFaqs.length !== publishedCount && (
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
          {orderedFaqs.length > 1 && (
            <p className="text-sm text-[oklch(0.72_0.01_258)]">Drag rows to reorder</p>
          )}
        </div>
        <button
          type="button"
          onClick={() => setDialog({ type: "create" })}
          className="flex items-center gap-1.5 px-4 py-2 rounded-lg text-sm font-semibold bg-[oklch(0.24_0.055_258)] text-[oklch(0.97_0.01_80)] hover:bg-[oklch(0.32_0.050_258)] transition-colors"
        >
          <Plus size={14} />
          Add FAQ
        </button>
      </div>

      {/* Content */}
      {fetchError ? (
        <FetchErrorBanner />
      ) : orderedFaqs.length === 0 ? (
        <EmptyState onAdd={() => setDialog({ type: "create" })} />
      ) : (
        <DndContext
          sensors={sensors}
          collisionDetection={closestCenter}
          onDragStart={handleDragStart}
          onDragEnd={handleDragEnd}
        >
          <SortableContext
            items={orderedFaqs.map((f) => f.id)}
            strategy={verticalListSortingStrategy}
          >
            <div className="space-y-3">
              {orderedFaqs.map((faq) => (
                <FaqRow
                  key={faq.id}
                  faq={faq}
                  onEdit={(f) => setDialog({ type: "edit", faq: f })}
                  onDelete={(f) => setDialog({ type: "delete", faq: f })}
                />
              ))}
            </div>
          </SortableContext>
          <DragOverlay
            dropAnimation={{ duration: 150, easing: "cubic-bezier(0.25, 1, 0.5, 1)" }}
          >
            {activeId && (() => {
              const activeFaq = orderedFaqs.find((f) => f.id === activeId);
              if (!activeFaq) return null;
              return (
                <div className="rounded-xl bg-[oklch(0.99_0.005_80)] border border-[oklch(0.72_0.115_82)] shadow-2xl overflow-hidden scale-[1.02] cursor-grabbing">
                  <div className="flex items-start gap-2 px-4 py-4">
                    <span className="mt-0.5 shrink-0 p-1 text-[oklch(0.48_0.02_258)]">
                      <GripVertical size={14} />
                    </span>
                    <div className="flex-1 min-w-0">
                      <p className="text-sm font-semibold text-[oklch(0.24_0.055_258)] leading-snug">
                        {activeFaq.question}
                      </p>
                      <p className="text-sm text-[oklch(0.48_0.020_258)] mt-1 line-clamp-1 leading-relaxed">
                        {activeFaq.answer}
                      </p>
                    </div>
                  </div>
                </div>
              );
            })()}
          </DragOverlay>
        </DndContext>
      )}

      {/* Dialogs */}
      {dialog?.type === "create" && (
        <FaqFormDialog
          faq={null}
          onClose={() => setDialog(null)}
          onSuccess={handleSuccess}
        />
      )}
      {dialog?.type === "edit" && (
        <FaqFormDialog
          faq={dialog.faq}
          onClose={() => setDialog(null)}
          onSuccess={handleSuccess}
        />
      )}
      {dialog?.type === "delete" && (
        <DeleteDialog
          faq={dialog.faq}
          onClose={() => setDialog(null)}
          onSuccess={handleDeleteSuccess}
        />
      )}
    </>
  );
}
