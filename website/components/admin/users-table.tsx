"use client";

import { useActionState, useState, useTransition, useRef, useEffect } from "react";
import { useRouter } from "next/navigation";
import Link from "next/link";
import {
  ChevronDown,
  Pencil,
  Trash2,
  X,
  Search,
  Dog,
  Cat,
  Download,
  Eye,
} from "lucide-react";
import { cn } from "@/lib/utils";
import {
  updateMemberAction,
  deleteMemberAction,
  updatePetAction,
  deletePetAction,
  type ActionState,
} from "@/app/admin/(protected)/users/actions";
import type { Member, Pet } from "@/app/admin/(protected)/users/page";

const PLAN_COLORS: Record<string, string> = {
  Standard: "bg-[oklch(0.94_0.015_75)] text-[oklch(0.40_0.040_258)]",
  Deluxe: "bg-[oklch(0.93_0.025_80)] text-[oklch(0.40_0.060_82)]",
  Premium: "bg-[oklch(0.24_0.055_258)] text-[oklch(0.72_0.115_82)]",
};

function PlanBadge({ plan }: { plan: string | null }) {
  if (!plan) return <span className="text-[oklch(0.72_0.01_258)] text-xs">—</span>;
  const classes =
    PLAN_COLORS[plan] ?? "bg-[oklch(0.94_0.015_75)] text-[oklch(0.48_0.02_258)]";
  return (
    <span className={cn("inline-block px-2 py-0.5 rounded text-xs font-medium", classes)}>
      {plan}
    </span>
  );
}

function Initials({ name }: { name: string }) {
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

// ── Dialogs ─────────────────────────────────────────────────────────────────

function Overlay({
  onClose,
  children,
}: {
  onClose: () => void;
  children: React.ReactNode;
}) {
  return (
    <div
      className="fixed inset-0 z-50 flex items-center justify-center p-4"
      style={{ background: "rgba(18,24,38,0.55)" }}
    >
      <div className="absolute inset-0" onClick={onClose} aria-label="Close dialog" />
      <div className="relative z-10 w-full max-w-md">{children}</div>
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
  return (
    <div className="bg-[oklch(0.99_0.005_80)] rounded-xl shadow-xl border border-[oklch(0.88_0.010_258)] overflow-hidden">
      <div className="flex items-center justify-between px-6 py-4 border-b border-[oklch(0.92_0.010_258)]">
        <h2
          className="text-[oklch(0.24_0.055_258)] font-semibold"
          style={{ fontSize: "14px" }}
        >
          {title}
        </h2>
        <button
          type="button"
          onClick={onClose}
          className="text-[oklch(0.72_0.01_258)] hover:text-[oklch(0.48_0.02_258)] transition-colors"
        >
          <X size={16} />
        </button>
      </div>
      <div className="px-6 py-5">{children}</div>
    </div>
  );
}

function Field({
  label,
  name,
  defaultValue,
  type = "text",
  placeholder,
}: {
  label: string;
  name: string;
  defaultValue?: string | number | null;
  type?: string;
  placeholder?: string;
}) {
  return (
    <div>
      <label
        htmlFor={name}
        className="block text-[oklch(0.48_0.02_258)] text-xs font-medium mb-1"
      >
        {label}
      </label>
      <input
        id={name}
        name={name}
        type={type}
        defaultValue={defaultValue ?? ""}
        placeholder={placeholder}
        className={cn(
          "w-full bg-[oklch(0.97_0.01_80)] border border-[oklch(0.88_0.010_258)] rounded-lg px-3 py-2",
          "text-[oklch(0.24_0.055_258)] placeholder:text-[oklch(0.72_0.01_258)]",
          "focus:outline-none focus:ring-2 focus:ring-[oklch(0.72_0.115_82)] focus:border-transparent",
          "transition-colors duration-150",
        )}
        style={{ fontSize: "13px" }}
      />
    </div>
  );
}

function SelectField({
  label,
  name,
  defaultValue,
  options,
  nullable,
}: {
  label: string;
  name: string;
  defaultValue?: string | null;
  options: string[];
  nullable?: boolean;
}) {
  return (
    <div>
      <label
        htmlFor={name}
        className="block text-[oklch(0.48_0.02_258)] text-xs font-medium mb-1"
      >
        {label}
      </label>
      <select
        id={name}
        name={name}
        defaultValue={defaultValue ?? ""}
        className={cn(
          "w-full bg-[oklch(0.97_0.01_80)] border border-[oklch(0.88_0.010_258)] rounded-lg px-3 py-2",
          "text-[oklch(0.24_0.055_258)]",
          "focus:outline-none focus:ring-2 focus:ring-[oklch(0.72_0.115_82)] focus:border-transparent",
          "transition-colors duration-150",
        )}
        style={{ fontSize: "13px" }}
      >
        {nullable && <option value="">— none —</option>}
        {options.map((o) => (
          <option key={o} value={o}>
            {o}
          </option>
        ))}
      </select>
    </div>
  );
}

// ── Edit Member Dialog ───────────────────────────────────────────────────────

function EditMemberDialog({
  member,
  onClose,
  onSuccess,
}: {
  member: Member;
  onClose: () => void;
  onSuccess: () => void;
}) {
  const initialState: ActionState = { error: null };
  const [state, formAction, pending] = useActionState(updateMemberAction, initialState);
  const prevPending = useRef(false);

  useEffect(() => {
    if (prevPending.current && !pending && !state.error) {
      onSuccess();
    }
    prevPending.current = pending;
  }, [pending, state.error, onSuccess]);

  return (
    <Overlay onClose={onClose}>
      <DialogShell title="Edit member" onClose={onClose}>
        <form action={formAction} className="space-y-4">
          <input type="hidden" name="memberId" value={member.id} />

          <div className="grid grid-cols-2 gap-3">
            <Field
              label="First name"
              name="first_name"
              defaultValue={member.first_name}
            />
            <Field label="Last name" name="last_name" defaultValue={member.last_name} />
          </div>
          <Field
            label="Phone"
            name="phone"
            defaultValue={member.phone}
            placeholder="9XXXXXXXXX"
          />
          <Field
            label="Address"
            name="address"
            defaultValue={member.address}
            placeholder="Metro Manila"
          />
          <div className="flex items-center gap-3">
            <input
              type="hidden"
              name="is_founding"
              value={member.is_founding ? "true" : "false"}
              id="is_founding_hidden"
            />
            <label className="flex items-center gap-2 cursor-pointer select-none group">
              <input
                type="checkbox"
                defaultChecked={member.is_founding}
                onChange={(e) => {
                  const hidden = document.getElementById(
                    "is_founding_hidden",
                  ) as HTMLInputElement | null;
                  if (hidden) hidden.value = e.target.checked ? "true" : "false";
                }}
                className="w-4 h-4 rounded accent-[oklch(0.72_0.115_82)]"
              />
              <span className="text-[oklch(0.48_0.02_258)] text-xs font-medium group-hover:text-[oklch(0.24_0.055_258)] transition-colors">
                Founding member
              </span>
            </label>
          </div>

          {state.error && <p className="text-red-600 text-xs">{state.error}</p>}

          <div className="flex gap-2 pt-1">
            <button
              type="button"
              onClick={onClose}
              className="flex-1 py-2 rounded-lg border border-[oklch(0.88_0.010_258)] text-[oklch(0.48_0.02_258)] text-xs font-medium hover:bg-[oklch(0.94_0.015_75)] transition-colors"
            >
              Cancel
            </button>
            <button
              type="submit"
              disabled={pending}
              className="flex-1 py-2 rounded-lg bg-[oklch(0.24_0.055_258)] text-[oklch(0.72_0.115_82)] text-xs font-semibold hover:bg-[oklch(0.32_0.050_258)] disabled:opacity-50 transition-colors"
            >
              {pending ? "Saving…" : "Save changes"}
            </button>
          </div>
        </form>
      </DialogShell>
    </Overlay>
  );
}

// ── Edit Pet Dialog ──────────────────────────────────────────────────────────

function EditPetDialog({
  memberId,
  pet,
  onClose,
  onSuccess,
}: {
  memberId: string;
  pet: Pet;
  onClose: () => void;
  onSuccess: () => void;
}) {
  const initialState: ActionState = { error: null };
  const [state, formAction, pending] = useActionState(updatePetAction, initialState);
  const prevPending = useRef(false);

  useEffect(() => {
    if (prevPending.current && !pending && !state.error) {
      onSuccess();
    }
    prevPending.current = pending;
  }, [pending, state.error, onSuccess]);

  return (
    <Overlay onClose={onClose}>
      <DialogShell title={`Edit pet · ${pet.name}`} onClose={onClose}>
        <form action={formAction} className="space-y-4">
          <input type="hidden" name="memberId" value={memberId} />
          <input type="hidden" name="petId" value={pet.id} />

          <div className="grid grid-cols-2 gap-3">
            <Field label="Name" name="name" defaultValue={pet.name} />
            <SelectField
              label="Species"
              name="species"
              defaultValue={pet.species}
              options={["dog", "cat"]}
            />
          </div>
          <div className="grid grid-cols-2 gap-3">
            <Field label="Breed" name="breed" defaultValue={pet.breed} />
            <SelectField
              label="Sex"
              name="sex"
              defaultValue={pet.sex}
              options={["male", "female"]}
            />
          </div>
          <div className="grid grid-cols-3 gap-3">
            <Field
              label="Birth month"
              name="birth_month"
              type="number"
              defaultValue={pet.birth_month}
              placeholder="1–12"
            />
            <Field
              label="Birth year"
              name="birth_year"
              type="number"
              defaultValue={pet.birth_year}
              placeholder="e.g. 2020"
            />
            <Field
              label="Birth day"
              name="birth_day"
              type="number"
              defaultValue={pet.birth_day}
              placeholder="optional"
            />
          </div>
          <Field
            label="Weight (kg)"
            name="weight_kg"
            type="number"
            defaultValue={pet.weight_kg}
            placeholder="e.g. 5.2"
          />
          <div>
            <label className="block text-[oklch(0.48_0.02_258)] text-xs font-medium mb-1">
              Notes
            </label>
            <textarea
              name="notes"
              defaultValue={pet.notes ?? ""}
              rows={2}
              className={cn(
                "w-full bg-[oklch(0.97_0.01_80)] border border-[oklch(0.88_0.010_258)] rounded-lg px-3 py-2 resize-none",
                "text-[oklch(0.24_0.055_258)] placeholder:text-[oklch(0.72_0.01_258)]",
                "focus:outline-none focus:ring-2 focus:ring-[oklch(0.72_0.115_82)] focus:border-transparent",
              )}
              style={{ fontSize: "13px" }}
            />
          </div>

          {state.error && <p className="text-red-600 text-xs">{state.error}</p>}

          <div className="flex gap-2 pt-1">
            <button
              type="button"
              onClick={onClose}
              className="flex-1 py-2 rounded-lg border border-[oklch(0.88_0.010_258)] text-[oklch(0.48_0.02_258)] text-xs font-medium hover:bg-[oklch(0.94_0.015_75)] transition-colors"
            >
              Cancel
            </button>
            <button
              type="submit"
              disabled={pending}
              className="flex-1 py-2 rounded-lg bg-[oklch(0.24_0.055_258)] text-[oklch(0.72_0.115_82)] text-xs font-semibold hover:bg-[oklch(0.32_0.050_258)] disabled:opacity-50 transition-colors"
            >
              {pending ? "Saving…" : "Save changes"}
            </button>
          </div>
        </form>
      </DialogShell>
    </Overlay>
  );
}

// ── Confirm Delete ───────────────────────────────────────────────────────────

function ConfirmDeleteDialog({
  title,
  description,
  onConfirm,
  onClose,
  pending,
}: {
  title: string;
  description: string;
  onConfirm: () => void;
  onClose: () => void;
  pending: boolean;
}) {
  return (
    <Overlay onClose={onClose}>
      <DialogShell title={title} onClose={onClose}>
        <p className="text-[oklch(0.48_0.02_258)] mb-5" style={{ fontSize: "13px" }}>
          {description}
        </p>
        <div className="flex gap-2">
          <button
            type="button"
            onClick={onClose}
            disabled={pending}
            className="flex-1 py-2 rounded-lg border border-[oklch(0.88_0.010_258)] text-[oklch(0.48_0.02_258)] text-xs font-medium hover:bg-[oklch(0.94_0.015_75)] transition-colors disabled:opacity-50"
          >
            Cancel
          </button>
          <button
            type="button"
            onClick={onConfirm}
            disabled={pending}
            className="flex-1 py-2 rounded-lg bg-red-600 text-white text-xs font-semibold hover:bg-red-700 disabled:opacity-50 transition-colors"
          >
            {pending ? "Deleting…" : "Delete"}
          </button>
        </div>
      </DialogShell>
    </Overlay>
  );
}

// ── Pet Row ──────────────────────────────────────────────────────────────────

function PetRow({
  memberId,
  pet,
  onRefresh,
}: {
  memberId: string;
  pet: Pet;
  onRefresh: () => void;
}) {
  const [editOpen, setEditOpen] = useState(false);
  const [deleteOpen, setDeleteOpen] = useState(false);
  const [deleting, startDelete] = useTransition();
  const [deleteError, setDeleteError] = useState<string | null>(null);

  function handleDelete() {
    startDelete(async () => {
      const result = await deletePetAction(memberId, pet.id);
      if (result.error) {
        setDeleteError(result.error);
      } else {
        setDeleteOpen(false);
        onRefresh();
      }
    });
  }

  const PetIcon = pet.species === "cat" ? Cat : Dog;

  return (
    <>
      <tr className="bg-[oklch(0.96_0.008_80)] border-t border-[oklch(0.92_0.010_258)]">
        <td className="pl-16 pr-4 py-3" colSpan={2}>
          <div className="flex items-center gap-2.5">
            <div className="w-7 h-7 rounded-full bg-[oklch(0.94_0.015_75)] flex items-center justify-center shrink-0">
              <PetIcon size={13} className="text-[oklch(0.48_0.02_258)]" />
            </div>
            <div>
              <p
                className="text-[oklch(0.24_0.055_258)] font-medium"
                style={{ fontSize: "13px" }}
              >
                {pet.name}
              </p>
              <p className="text-[oklch(0.72_0.01_258)] text-xs capitalize">
                {[pet.species, pet.breed].filter(Boolean).join(" · ")}
              </p>
            </div>
          </div>
        </td>
        <td className="px-4 py-3">
          <PlanBadge plan={pet.plan_type} />
        </td>
        <td className="px-4 py-3">
          <span className="text-[oklch(0.48_0.02_258)] text-xs capitalize">
            {pet.sex ?? "—"}
          </span>
        </td>
        <td className="px-4 py-3">
          <span className="text-[oklch(0.48_0.02_258)] text-xs">
            {pet.weight_kg != null ? `${pet.weight_kg} kg` : "—"}
          </span>
        </td>
        <td className="px-4 py-3">
          <div className="flex items-center gap-1 justify-end">
            <button
              type="button"
              onClick={() => setEditOpen(true)}
              title="Edit pet"
              className="p-1.5 rounded text-[oklch(0.72_0.01_258)] hover:text-[oklch(0.24_0.055_258)] hover:bg-[oklch(0.94_0.015_75)] transition-colors"
            >
              <Pencil size={13} />
            </button>
            <button
              type="button"
              onClick={() => setDeleteOpen(true)}
              title="Delete pet"
              className="p-1.5 rounded text-[oklch(0.72_0.01_258)] hover:text-red-500 hover:bg-red-50 transition-colors"
            >
              <Trash2 size={13} />
            </button>
          </div>
        </td>
      </tr>

      {editOpen && (
        <EditPetDialog
          memberId={memberId}
          pet={pet}
          onClose={() => setEditOpen(false)}
          onSuccess={() => {
            setEditOpen(false);
            onRefresh();
          }}
        />
      )}

      {deleteOpen && (
        <ConfirmDeleteDialog
          title="Delete pet"
          description={`Remove ${pet.name} permanently? This cannot be undone.`}
          onConfirm={handleDelete}
          onClose={() => {
            setDeleteOpen(false);
            setDeleteError(null);
          }}
          pending={deleting}
        />
      )}
      {deleteError && (
        <tr>
          <td colSpan={6} className="px-16 py-2 text-red-600 text-xs">
            {deleteError}
          </td>
        </tr>
      )}
    </>
  );
}

// ── Member Row ───────────────────────────────────────────────────────────────

function MemberRow({ member, onRefresh }: { member: Member; onRefresh: () => void }) {
  const [expanded, setExpanded] = useState(false);
  const [editOpen, setEditOpen] = useState(false);
  const [deleteOpen, setDeleteOpen] = useState(false);
  const [deleting, startDelete] = useTransition();
  const [deleteError, setDeleteError] = useState<string | null>(null);

  function handleDelete() {
    startDelete(async () => {
      const result = await deleteMemberAction(member.id);
      if (result.error) {
        setDeleteError(result.error);
      } else {
        setDeleteOpen(false);
        onRefresh();
      }
    });
  }

  const fullName = `${member.first_name} ${member.last_name}`;

  return (
    <>
      <tr className="border-t border-[oklch(0.92_0.010_258)] hover:bg-[oklch(0.98_0.006_80)] transition-colors group">
        {/* Member */}
        <td className="px-4 py-3.5">
          <div className="flex items-center gap-3">
            <Initials name={fullName} />
            <div>
              <p
                className="text-[oklch(0.24_0.055_258)] font-medium"
                style={{ fontSize: "13px" }}
              >
                {fullName}
                {member.is_founding && (
                  <span className="ml-2 inline-block px-1.5 py-0.5 rounded text-[10px] font-semibold bg-[oklch(0.72_0.115_82)/15] text-[oklch(0.55_0.100_82)] tracking-wide">
                    FOUNDING
                  </span>
                )}
              </p>
              <p className="text-[oklch(0.72_0.01_258)] text-xs mt-0.5">
                {member.email ?? "—"}
              </p>
            </div>
          </div>
        </td>

        {/* Phone */}
        <td className="px-4 py-3.5">
          <span className="text-[oklch(0.48_0.02_258)] text-xs">
            {member.phone ? `+63${member.phone}` : "—"}
          </span>
        </td>

        {/* Pets */}
        <td className="px-4 py-3.5">
          <button
            type="button"
            onClick={() => setExpanded((v) => !v)}
            disabled={member.pets.length === 0}
            className={cn(
              "flex items-center gap-1.5 rounded px-2 py-1 text-xs font-medium transition-colors",
              member.pets.length > 0
                ? "text-[oklch(0.48_0.02_258)] hover:bg-[oklch(0.94_0.015_75)] hover:text-[oklch(0.24_0.055_258)] cursor-pointer"
                : "text-[oklch(0.72_0.01_258)] cursor-default",
            )}
          >
            <span>{member.pets.length}</span>
            {member.pets.length > 0 && (
              <ChevronDown
                size={12}
                className={cn(
                  "transition-transform duration-200",
                  expanded && "rotate-180",
                )}
              />
            )}
          </button>
        </td>

        {/* Joined */}
        <td className="px-4 py-3.5">
          <span className="text-[oklch(0.72_0.01_258)] text-xs">
            {formatDate(member.joined_at)}
          </span>
        </td>

        {/* Actions */}
        <td className="px-4 py-3.5">
          <div className="flex items-center gap-1 justify-end">
            <Link
              href={`/admin/users/${member.id}`}
              title="View member details"
              className="p-1.5 rounded text-[oklch(0.72_0.01_258)] hover:text-[oklch(0.24_0.055_258)] hover:bg-[oklch(0.94_0.015_75)] transition-colors opacity-0 group-hover:opacity-100"
            >
              <Eye size={14} />
            </Link>
            <button
              type="button"
              onClick={() => setEditOpen(true)}
              title="Edit member"
              className="p-1.5 rounded text-[oklch(0.72_0.01_258)] hover:text-[oklch(0.24_0.055_258)] hover:bg-[oklch(0.94_0.015_75)] transition-colors opacity-0 group-hover:opacity-100"
            >
              <Pencil size={14} />
            </button>
            <button
              type="button"
              onClick={() => setDeleteOpen(true)}
              title="Delete member"
              className="p-1.5 rounded text-[oklch(0.72_0.01_258)] hover:text-red-500 hover:bg-red-50 transition-colors opacity-0 group-hover:opacity-100"
            >
              <Trash2 size={14} />
            </button>
          </div>
        </td>
      </tr>

      {deleteError && (
        <tr>
          <td colSpan={6} className="px-4 py-2 bg-red-50 text-red-600 text-xs">
            {deleteError}
          </td>
        </tr>
      )}

      {expanded &&
        member.pets.map((pet) => (
          <PetRow key={pet.id} memberId={member.id} pet={pet} onRefresh={onRefresh} />
        ))}

      {editOpen && (
        <EditMemberDialog
          member={member}
          onClose={() => setEditOpen(false)}
          onSuccess={() => {
            setEditOpen(false);
            onRefresh();
          }}
        />
      )}

      {deleteOpen && (
        <ConfirmDeleteDialog
          title="Delete member"
          description={`Remove ${fullName} and all their data permanently? This cannot be undone.`}
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

// ── UsersTable ───────────────────────────────────────────────────────────────

function exportToCsv(members: Member[]) {
  const rows: string[][] = [
    [
      "First Name",
      "Last Name",
      "Email",
      "Phone",
      "Address",
      "Founding Member",
      "Joined",
      "Pets",
    ],
  ];

  for (const m of members) {
    const pets = m.pets.map((p) => `${p.name} (${p.species ?? "unknown"})`).join(" | ");
    rows.push([
      m.first_name,
      m.last_name,
      m.email ?? "",
      m.phone ?? "",
      m.address ?? "",
      m.is_founding ? "Yes" : "No",
      new Date(m.joined_at).toLocaleDateString("en-PH"),
      pets,
    ]);
  }

  const csv = rows
    .map((row) => row.map((cell) => `"${cell.replace(/"/g, '""')}"`).join(","))
    .join("\n");

  const blob = new Blob([csv], { type: "text/csv;charset=utf-8;" });
  const url = URL.createObjectURL(blob);
  const link = document.createElement("a");
  link.href = url;
  link.download = `metropaws-members-${new Date().toISOString().slice(0, 10)}.csv`;
  link.click();
  URL.revokeObjectURL(url);
}

export function UsersTable({ members }: { members: Member[] }) {
  const router = useRouter();
  const [query, setQuery] = useState("");

  const filtered = members.filter((m) => {
    const q = query.toLowerCase();
    return (
      m.first_name.toLowerCase().includes(q) ||
      m.last_name.toLowerCase().includes(q) ||
      (m.email ?? "").toLowerCase().includes(q) ||
      (m.phone ?? "").includes(q)
    );
  });

  function handleRefresh() {
    router.refresh();
  }

  if (members.length === 0) {
    return (
      <div className="rounded-xl border border-[oklch(0.88_0.010_258)] bg-[oklch(0.99_0.005_80)] p-16 flex flex-col items-center justify-center text-center">
        <p
          className="text-[oklch(0.48_0.02_258)] font-medium"
          style={{ fontSize: "14px" }}
        >
          No members yet
        </p>
        <p className="text-[oklch(0.72_0.01_258)] text-xs mt-1">
          Members will appear here once they register.
        </p>
      </div>
    );
  }

  return (
    <div>
      {/* Toolbar */}
      <div className="mb-4 flex items-center gap-3">
        <div className="relative max-w-sm flex-1">
          <Search
            size={14}
            className="absolute left-3 top-1/2 -translate-y-1/2 text-[oklch(0.72_0.01_258)] pointer-events-none"
          />
          <input
            type="search"
            placeholder="Search by name, email, phone…"
            value={query}
            onChange={(e) => setQuery(e.target.value)}
            className={cn(
              "w-full bg-[oklch(0.99_0.005_80)] border border-[oklch(0.88_0.010_258)] rounded-lg pl-9 pr-4 py-2",
              "text-[oklch(0.24_0.055_258)] placeholder:text-[oklch(0.72_0.01_258)]",
              "focus:outline-none focus:ring-2 focus:ring-[oklch(0.72_0.115_82)] focus:border-transparent",
              "transition-colors",
            )}
            style={{ fontSize: "13px" }}
          />
        </div>
        <button
          onClick={() => exportToCsv(filtered)}
          className={cn(
            "flex items-center gap-1.5 px-3 py-2 rounded-lg border border-[oklch(0.88_0.010_258)]",
            "bg-[oklch(0.99_0.005_80)] text-[oklch(0.48_0.02_258)] hover:bg-[oklch(0.97_0.01_80)]",
            "transition-colors shrink-0",
          )}
          style={{ fontSize: "12px" }}
          title="Export visible rows to CSV"
        >
          <Download size={13} />
          Export CSV
        </button>
      </div>

      {/* Table */}
      <div className="rounded-xl border border-[oklch(0.88_0.010_258)] bg-[oklch(0.99_0.005_80)] overflow-hidden">
        <table className="w-full table-fixed">
          <colgroup>
            <col className="w-[35%]" />
            <col className="w-[20%]" />
            <col className="w-[10%]" />
            <col className="w-[16%]" />
            <col className="w-[10%]" />
          </colgroup>
          <thead>
            <tr className="bg-[oklch(0.97_0.01_80)]">
              <th className="px-4 py-3 text-left text-[oklch(0.48_0.02_258)] text-xs font-semibold tracking-wide">
                Member
              </th>
              <th className="px-4 py-3 text-left text-[oklch(0.48_0.02_258)] text-xs font-semibold tracking-wide">
                Phone
              </th>
              <th className="px-4 py-3 text-left text-[oklch(0.48_0.02_258)] text-xs font-semibold tracking-wide">
                Pets
              </th>
              <th className="px-4 py-3 text-left text-[oklch(0.48_0.02_258)] text-xs font-semibold tracking-wide">
                Joined
              </th>
              <th className="px-4 py-3 text-right text-[oklch(0.48_0.02_258)] text-xs font-semibold tracking-wide">
                Actions
              </th>
            </tr>
          </thead>
          <tbody>
            {filtered.length === 0 ? (
              <tr>
                <td
                  colSpan={6}
                  className="px-4 py-12 text-center text-[oklch(0.72_0.01_258)] text-xs"
                >
                  No members match &ldquo;{query}&rdquo;
                </td>
              </tr>
            ) : (
              filtered.map((member) => (
                <MemberRow key={member.id} member={member} onRefresh={handleRefresh} />
              ))
            )}
          </tbody>
        </table>
      </div>

      {filtered.length > 0 && (
        <p className="mt-3 text-[oklch(0.72_0.01_258)] text-xs">
          {filtered.length === members.length
            ? `${members.length} members`
            : `${filtered.length} of ${members.length} members`}
        </p>
      )}
    </div>
  );
}
